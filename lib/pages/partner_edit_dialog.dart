import 'package:flutter/material.dart';

Future<Map<String, dynamic>?> showPartnerEditDialog(
  BuildContext context,
  Map<String, dynamic> partner,
) => showDialog<Map<String, dynamic>>(
  context: context,
  builder: (_) => _PartnerEditDialog(partner: partner),
);

class _PartnerEditDialog extends StatefulWidget {
  const _PartnerEditDialog({required this.partner});
  final Map<String, dynamic> partner;

  @override
  State<_PartnerEditDialog> createState() => _PartnerEditDialogState();
}

class _PartnerEditDialogState extends State<_PartnerEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  String _type = 'CUSTOMER';
  bool _active = true;

  @override
  void initState() {
    super.initState();
    for (final key in const [
      'code',
      'name',
      'surname',
      'tax_number',
      'tax_office',
      'phone',
      'email',
      'city',
      'district',
      'notes',
      'payment_term_days',
    ]) {
      _fields[key] = TextEditingController(
        text:
            '${widget.partner[key] ?? (key == 'payment_term_days' ? '0' : '')}',
      );
    }
    _type = '${widget.partner['partner_type'] ?? 'CUSTOMER'}';
    _active = widget.partner['is_active'] != false;
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Widget _field(
    String key,
    String label, {
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextFormField(
      controller: _fields[key],
      decoration: InputDecoration(labelText: label),
      validator: validator,
    ),
  );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final days = int.tryParse(_fields['payment_term_days']!.text.trim());
    if (days == null || days < 0 || days > 3650) return;
    Navigator.pop(context, {
      for (final entry in _fields.entries)
        if (entry.key != 'payment_term_days')
          entry.key: entry.value.text.trim().isEmpty
              ? null
              : entry.value.text.trim(),
      'payment_term_days': days,
      'partner_type': _type,
      'is_active': _active,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Cari Kartı Düzenle'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            _field(
              'code',
              'Cari kodu',
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? 'Cari kodu gerekli' : null,
            ),
            _field(
              'name',
              'Ad / ünvan',
              validator: (value) => (value?.trim().length ?? 0) < 2
                  ? 'En az iki karakter girin'
                  : null,
            ),
            _field('surname', 'Soyad'),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Cari türü'),
              items: const [
                DropdownMenuItem(value: 'CUSTOMER', child: Text('Müşteri')),
                DropdownMenuItem(value: 'SUPPLIER', child: Text('Tedarikçi')),
                DropdownMenuItem(value: 'BOTH', child: Text('Her ikisi')),
              ],
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            _field(
              'tax_number',
              'VKN / TCKN',
              validator: (value) {
                final text = value?.trim() ?? '';
                return text.isNotEmpty &&
                        !RegExp(r'^(\d{10}|\d{11})$').hasMatch(text)
                    ? 'VKN 10, TCKN 11 haneli olmalı'
                    : null;
              },
            ),
            _field('tax_office', 'Vergi dairesi'),
            _field('phone', 'Telefon'),
            _field('email', 'E-posta'),
            _field('city', 'İl'),
            _field('district', 'İlçe'),
            _field(
              'payment_term_days',
              'Vade (gün)',
              validator: (value) {
                final days = int.tryParse(value?.trim() ?? '');
                return days == null || days < 0 || days > 3650
                    ? '0–3650 gün girin'
                    : null;
              },
            ),
            _field('notes', 'Notlar'),
            SwitchListTile(
              title: const Text('Aktif'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Vazgeç'),
      ),
      FilledButton(onPressed: _save, child: const Text('Kaydet')),
    ],
  );
}
