import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets.dart';

/// Menüde gösterilecek tek bir özellik.
class MenuEntry {
  const MenuEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
    this.badge,
    this.viewId,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;
  final int? badge;
  final String? viewId;

  MenuEntry renamed(String title, String viewId) => MenuEntry(
    title: title,
    subtitle: subtitle,
    icon: icon,
    builder: builder,
    badge: badge,
    viewId: viewId,
  );
}

/// Menü bölümü (Finans, İletişim, Araçlar gibi).
class MenuSection {
  const MenuSection({
    required this.title,
    required this.entries,
    this.parentTitle,
  });

  final String title;
  final List<MenuEntry> entries;
  final String? parentTitle;
}

/// Tüm özelliklere erişim sağlayan menü ekranı.
class FeatureMenuPage extends StatefulWidget {
  const FeatureMenuPage({
    super.key,
    required this.sections,
    required this.onLogout,
    required this.roleLabel,
  });

  final List<MenuSection> sections;
  final VoidCallback onLogout;
  final String roleLabel;

  @override
  State<FeatureMenuPage> createState() => _FeatureMenuPageState();
}

class _FeatureMenuPageState extends State<FeatureMenuPage> {
  final _search = TextEditingController();
  String? _category;
  final Set<String> _expanded = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _normalize(String text) => text
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');

  @override
  Widget build(BuildContext context) {
    final query = _normalize(_search.text.trim());
    final sections = widget.sections
        .where((s) => _category == null || s.title == _category)
        .map(
          (s) => MenuSection(
            title: s.title,
            parentTitle: s.parentTitle,
            entries: s.entries
                .where(
                  (e) =>
                      _normalize('${e.title} ${e.subtitle} ${s.title}')
                          .contains(query),
                )
                .toList(),
          ),
        )
        .where((s) => s.entries.isNotEmpty)
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageTitle(
                title: 'Menü',
                subtitle: '${widget.roleLabel} çalışma alanınız',
              ),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Menüde ara',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Aramayı temizle',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(_search.clear),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final title in [
                      null,
                      ...widget.sections.map((s) => s.title),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(title ?? 'Tümü'),
                          selected: _category == title,
                          onSelected: (_) => setState(() => _category = title),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              if (query.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${sections.fold<int>(0, (n, s) => n + s.entries.length)} sonuç',
                    style: const TextStyle(color: FinkitColors.muted),
                  ),
                ),
              if (sections.isEmpty)
                const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Sonuç bulunamadı',
                  description:
                      'Başka bir kelime deneyin veya Tümü kategorisini seçin.',
                ),
              for (var index = 0; index < sections.length; index++) ...[
                if (sections[index].parentTitle != null &&
                    (index == 0 ||
                        sections[index - 1].parentTitle !=
                            sections[index].parentTitle))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                    child: Text(
                      sections[index].parentTitle!,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SurfaceCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            sections[index].entries.first.icon,
                            color: FinkitColors.primary,
                          ),
                          title: Text(
                            sections[index].title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${sections[index].entries.length} özellik',
                          ),
                          trailing: Icon(
                            query.isNotEmpty ||
                                    _category != null ||
                                    _expanded.contains(sections[index].title)
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                          ),
                          onTap: () => setState(() {
                            if (!_expanded.remove(sections[index].title)) {
                              _expanded.add(sections[index].title);
                            }
                          }),
                        ),
                        if (query.isNotEmpty ||
                            _category != null ||
                            _expanded.contains(sections[index].title))
                          for (final entry in sections[index].entries) ...[
                            const Divider(height: 1, color: FinkitColors.line),
                            _MenuTile(entry: entry),
                          ],
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Çıkış Yap'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.entry});

  final MenuEntry entry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: entry.builder)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(entry.icon, size: 20, color: FinkitColors.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FinkitColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            if (entry.badge != null && entry.badge! > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: FinkitColors.danger,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${entry.badge}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const Icon(
              Icons.chevron_right_rounded,
              color: FinkitColors.mutedLight,
            ),
          ],
        ),
      ),
    );
  }
}
