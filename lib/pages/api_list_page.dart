import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets.dart';

/// Sunucudan liste çeken ekranlar için ortak iskelet: yükleniyor, hata,
/// boş durum, aşağı çekip yenileme ve isteğe bağlı özet kartları.
class ApiListPage extends StatefulWidget {
  const ApiListPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.loader,
    required this.itemBuilder,
    this.refreshKey = 0,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'Kayıt bulunamadı',
    this.emptyDescription = 'Bu bölümde gösterilecek kayıt yok.',
    this.summaryBuilder,
    this.trailing,
    this.searchHint,
    this.searchText,
  });

  final String title;
  final String subtitle;
  final Future<List<Map<String, dynamic>>> Function() loader;
  final Widget Function(BuildContext context, Map<String, dynamic> item)
  itemBuilder;
  final int refreshKey;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyDescription;
  final Widget Function(List<Map<String, dynamic>> items)? summaryBuilder;
  final Widget? trailing;
  final String? searchHint;
  final String Function(Map<String, dynamic> item)? searchText;

  @override
  State<ApiListPage> createState() => _ApiListPageState();
}

class _ApiListPageState extends State<ApiListPage> {
  Future<List<Map<String, dynamic>>>? _future;
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ApiListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _future = widget.loader();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingState();
        }
        if (snapshot.hasError) {
          return _PageError(message: snapshot.error.toString(), onRetry: _load);
        }
        final all = snapshot.data ?? const <Map<String, dynamic>>[];
        final query = _search.text.trim().toLowerCase();
        final items = query.isEmpty || widget.searchText == null
            ? all
            : all
                  .where(
                    (item) =>
                        widget.searchText!(item).toLowerCase().contains(query),
                  )
                  .toList();
        return RefreshIndicator(
          color: FinkitColors.ink,
          onRefresh: () async => _load(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              PageTitle(
                title: widget.title,
                subtitle: widget.subtitle,
                trailing: widget.trailing,
              ),
              if (widget.summaryBuilder != null) ...[
                widget.summaryBuilder!(all),
                const SizedBox(height: 14),
              ],
              if (widget.searchHint != null) ...[
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: widget.searchHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (items.isEmpty)
                EmptyState(
                  icon: widget.emptyIcon,
                  title: widget.emptyTitle,
                  description: widget.emptyDescription,
                )
              else
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: widget.itemBuilder(context, item),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PageError extends StatelessWidget {
  const _PageError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: FinkitColors.muted,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: FinkitColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}
