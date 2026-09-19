import 'package:flutter/material.dart';

import '../theme.dart';

/// Validate once, then take the user to the first field that needs attention.
bool validateAndReveal(GlobalKey<FormState> key) {
  final invalid = key.currentState?.validateGranularly();
  if (invalid == null) return false;
  if (invalid.isEmpty) return true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final field = invalid.first;
    if (field.mounted) {
      Scrollable.ensureVisible(
        field.context,
        alignment: .15,
        duration: const Duration(milliseconds: 250),
      );
    }
  });
  return false;
}

class FormSectionLabel extends StatelessWidget {
  const FormSectionLabel(
    this.title, {
    super.key,
    this.icon = Icons.edit_note_rounded,
  });
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 14),
    child: Row(
      children: [
        Icon(icon, size: 20, color: FinkitColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: FinkitColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Keeps actions above the keyboard while only the form fields scroll.
class EntryFormLayout extends StatelessWidget {
  const EntryFormLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.footer,
    this.saving = false,
  });
  final String title, subtitle;
  final List<Widget> fields;
  final Widget footer;
  final bool saving;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: AbsorbPointer(
                  absorbing: saving,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: FinkitColors.primarySoft,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: FinkitColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ...fields,
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: FinkitColors.line)),
              ),
              child: footer,
            ),
          ],
        ),
      ),
    ),
  );
}
