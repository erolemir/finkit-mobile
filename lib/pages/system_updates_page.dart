import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets.dart';

/// Müşavir ve mükellefin gördüğü salt-okunur "Sistem Güncellemeleri" ekranı.
class SystemUpdatesPage extends StatefulWidget {
  const SystemUpdatesPage({super.key, required this.api, this.refreshKey = 0});

  final FinkitApi api;
  final int refreshKey;

  @override
  State<SystemUpdatesPage> createState() => _SystemUpdatesPageState();
}

class _SystemUpdatesPageState extends State<SystemUpdatesPage> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.api.systemUpdates();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('Sistem Güncellemeleri')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            const PageTitle(
              title: 'Sistem Güncellemeleri',
              subtitle: 'Finkit tarafından yapılan güncellemeler ve sistem durumu.',
            ),
            if (_loading) const LoadingState(),
            if (!_loading && _error != null)
              EmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Güncellemeler alınamadı',
                description: _error!,
              ),
            if (!_loading && _error == null && _items.isEmpty)
              const EmptyState(
                icon: Icons.system_update_alt_rounded,
                title: 'Henüz güncelleme yok',
                description:
                    'Yeni sürümler yayınlandığında bu ekranda ve bildirimle bilgilendirileceksiniz.',
              ),
            for (final item in _items) _UpdateCard(update: item),
          ],
        ),
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.update});

  final Map<String, dynamic> update;

  String _text(String key, [String fallback = '—']) {
    final value = update[key]?.toString().trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  bool _flag(String key, {bool fallback = true}) {
    final value = update[key];
    if (value is bool) return value;
    if (value == null) return fallback;
    return value.toString().toLowerCase() == 'true';
  }

  @override
  Widget build(BuildContext context) {
    final healthy = _text('health_status', 'OK').toUpperCase() != 'WARNING';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: FinkitColors.ink,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.system_update_alt_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _text('software_name', 'Finkit'),
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Revizyon ${_text('revision_number')} · '
                        '${dateText(update['revision_date'])}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: FinkitColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'YAPILAN GÜNCELLEMELER',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w800,
                color: FinkitColors.mutedLight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _text('summary'),
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: FinkitColors.line),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: healthy
                          ? FinkitColors.successSoft
                          : FinkitColors.warningSoft,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(13),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          healthy
                              ? Icons.verified_user_outlined
                              : Icons.error_outline_rounded,
                          size: 16,
                          color: healthy
                              ? FinkitColors.success
                              : FinkitColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            healthy
                                ? 'Sistem sağlık durumu: tüm kontroller tamam'
                                : 'Sistem sağlık durumu: bir kalemde takip sürüyor',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: healthy
                                  ? FinkitColors.success
                                  : FinkitColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _HealthRow(
                    label: 'Kullanılan donanım',
                    ok: true,
                    detail: _text('hardware', ''),
                  ),
                  _HealthRow(
                    label: 'Donanım bakımları yapıldı mı?',
                    ok: _flag('maintenance_done'),
                  ),
                  _HealthRow(
                    label: 'Anti-virüs koruması var mı?',
                    ok: _flag('antivirus'),
                  ),
                  _HealthRow(
                    label: 'Minimum konfigürasyon yeterli mi?',
                    ok: _flag('min_config_ok'),
                  ),
                  _HealthRow(
                    label: 'Yazılım sürümü güncel mi?',
                    ok: _flag('version_current'),
                    last: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.label,
    required this.ok,
    this.detail = '',
    this.last = false,
  });

  final String label;
  final bool ok;
  final String detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(
                bottom: BorderSide(color: FinkitColors.line),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12.5)),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 11,
                      color: FinkitColors.mutedLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle_outline : Icons.cancel_outlined,
                size: 15,
                color: ok ? FinkitColors.success : FinkitColors.warning,
              ),
              const SizedBox(width: 4),
              Text(
                ok ? 'Tamam' : 'Takip',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: ok ? FinkitColors.success : FinkitColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
