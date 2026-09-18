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
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;
  final int? badge;
}

/// Menü bölümü (Finans, İletişim, Araçlar gibi).
class MenuSection {
  const MenuSection({required this.title, required this.entries});

  final String title;
  final List<MenuEntry> entries;
}

/// Tüm özelliklere erişim sağlayan menü ekranı.
class FeatureMenuPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        PageTitle(title: 'Menü', subtitle: '$roleLabel için tüm özellikler.'),
        for (final section in sections) ...[
          SectionHeader(title: section.title),
          SurfaceCard(
            child: Column(
              children: [
                for (var i = 0; i < section.entries.length; i++) ...[
                  _MenuTile(entry: section.entries[i]),
                  if (i != section.entries.length - 1)
                    const Divider(height: 1, color: FinkitColors.line),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Çıkış Yap'),
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
                    maxLines: 1,
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
