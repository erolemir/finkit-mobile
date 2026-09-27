import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key, required this.api});
  final FinkitApi api;

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  static String _scheduledInput(Map<String, dynamic> status) {
    final tr = '${status['scheduled_at_tr'] ?? ''}';
    final match = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4}) (\d{2}:\d{2})$')
        .firstMatch(tr);
    if (match != null) return '${match[3]}-${match[2]}-${match[1]}T${match[4]}';
    return '';
  }

  final _fee = TextEditingController();
  final _maintenanceAt = TextEditingController();
  final _message = TextEditingController();
  bool _registration = true;
  bool _email = true;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic> _maintenance = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fee.dispose();
    _maintenanceAt.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rawSettings = await widget.api.adminGet('/admin/settings');
      final maintenance = await widget.api.adminGet('/admin/maintenance');
      if (!mounted) return;
      final rows = rawSettings['items'];
      final settings = <String, String>{};
      if (rows is List) {
        for (final row in rows.whereType<Map>()) {
          settings['${row['key']}'] = '${row['value']}';
        }
      }
      setState(() {
        _fee.text = settings['subscription_fee'] ?? '200';
        _registration = settings['registration_enabled'] != 'false';
        _email = settings['email_enabled'] != 'false';
        _maintenance = maintenance;
        _maintenanceAt.text = _scheduledInput(maintenance);
        _message.text = '${maintenance['message'] ?? ''}';
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Onayla'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _save(String key, String value) async {
    if (_busy) return;
    if (key == 'subscription_fee' &&
        (double.tryParse(value) == null || double.parse(value) < 0)) {
      setState(() => _error = 'Geçerli bir abonelik ücreti girin.');
      return;
    }
    if (!await _confirm(
          'Ayarı Değiştir',
          '$key değeri $value olarak kaydedilsin mi?',
        ) ||
        !mounted)
      return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.adminPut('/admin/settings', {
        'key': key,
        'value': value,
      });
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _maintenanceAction(String action) async {
    if (_busy) return;
    final time = _maintenanceAt.text.trim();
    if (action == 'schedule' &&
        !RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$').hasMatch(time)) {
      setState(
        () => _error = 'Bakım zamanı YYYY-AA-GG T SS:DD biçiminde olmalı.',
      );
      return;
    }
    final message = switch (action) {
      'schedule' =>
        'Bakım $time için planlanacak ve kullanıcılara bildirim gönderilecek.',
      'start' => 'Bakım modu hemen açılacak; kullanıcı oturumları etkilenecek.',
      'stop' => 'Bakım modu kapatılacak.',
      _ => 'Planlanan bakım iptal edilecek.',
    };
    if (!await _confirm('Sistem Bakımı', message) || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.adminPost(
        '/admin/maintenance/$action',
        action == 'schedule'
            ? {
                'scheduled_at': time,
                'message': _message.text.trim().isEmpty
                    ? null
                    : _message.text.trim(),
                'notify_users': true,
              }
            : const {},
      );
      if (mounted) setState(() => _maintenance = result);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PageTitle(
          title: 'Sistem Ayarları',
          subtitle: 'Platform ve bakım yönetimi',
        ),
        if (_loading)
          const LoadingState()
        else ...[
          const SectionHeader(title: 'Genel'),
          TextField(
            controller: _fee,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Abonelik ücreti (TL)',
            ),
          ),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => _save('subscription_fee', _fee.text.trim()),
            child: const Text('Abonelik Ücretini Kaydet'),
          ),
          SwitchListTile(
            title: const Text('Kayıt açık'),
            value: _registration,
            onChanged: _busy
                ? null
                : (value) => setState(() => _registration = value),
          ),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => _save('registration_enabled', '$_registration'),
            child: const Text('Kayıt Ayarını Kaydet'),
          ),
          SwitchListTile(
            title: const Text('E-posta açık'),
            value: _email,
            onChanged: _busy ? null : (value) => setState(() => _email = value),
          ),
          OutlinedButton(
            onPressed: _busy ? null : () => _save('email_enabled', '$_email'),
            child: const Text('E-posta Ayarını Kaydet'),
          ),
          const SectionHeader(title: 'Bakım Planlama'),
          Text(
            'Durum: ${_maintenance['maintenance_mode'] == true ? 'Bakımda' : 'Açık'}',
          ),
          if (_maintenance['scheduled_at'] != null)
            Text(
              'Planlanan saat: ${_maintenance['scheduled_at_tr'] ?? _maintenance['scheduled_at']}',
            ),
          TextField(
            controller: _maintenanceAt,
            decoration: const InputDecoration(
              labelText: 'Tarih ve saat (YYYY-AA-GGTSS:DD)',
            ),
          ),
          TextField(
            controller: _message,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Bakım mesajı'),
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: _busy ? null : () => _maintenanceAction('schedule'),
                child: const Text('Bakımı Planla'),
              ),
              if (_maintenance['scheduled_at'] != null)
                OutlinedButton(
                  onPressed: _busy ? null : () => _maintenanceAction('cancel'),
                  child: const Text('Planı İptal Et'),
                ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _maintenanceAction(
                        _maintenance['maintenance_mode'] == true
                            ? 'stop'
                            : 'start',
                      ),
                child: Text(
                  _maintenance['maintenance_mode'] == true
                      ? 'Bakımı Bitir'
                      : 'Bakımı Şimdi Başlat',
                ),
              ),
            ],
          ),
        ],
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );
}
