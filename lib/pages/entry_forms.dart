import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets.dart';

const _vatRates = <double>[0, 1, 8, 10, 18, 20];

/// Müşteri veya tedarikçi kaydı oluşturur. Kayıt başarılıysa `true` döner.
Future<bool> showPartnerForm(
  BuildContext context,
  FinkitApi api, {
  String defaultType = 'CUSTOMER',
}) async {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final code = TextEditingController(text: _suggestCode(defaultType));
  final taxNumber = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final city = TextEditingController();
  final termDays = TextEditingController(text: '30');
  var type = defaultType;
  var saving = false;
  String? error;

  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: FinkitColors.canvas,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yeni Cari Kartı',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Müşteri ve tedarikçi kayıtları aynı cari havuzunda tutulur.',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: name,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Ünvan / Ad Soyad',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) => (value ?? '').trim().length < 2
                      ? 'En az 2 karakter girin'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: 'Cari Tipi',
                    prefixIcon: Icon(Icons.swap_horiz_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'CUSTOMER', child: Text('Müşteri')),
                    DropdownMenuItem(
                      value: 'SUPPLIER',
                      child: Text('Tedarikçi'),
                    ),
                    DropdownMenuItem(value: 'BOTH', child: Text('Her ikisi')),
                  ],
                  onChanged: (value) => setSheetState(() {
                    type = value ?? type;
                    if (code.text == _suggestCode('CUSTOMER') ||
                        code.text == _suggestCode('SUPPLIER')) {
                      code.text = _suggestCode(type);
                    }
                  }),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: code,
                  decoration: const InputDecoration(
                    labelText: 'Cari Kodu',
                    prefixIcon: Icon(Icons.tag_rounded),
                  ),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Kod gerekli' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: taxNumber,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'VKN / TCKN (opsiyonel)',
                    prefixIcon: Icon(Icons.numbers_rounded),
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return null;
                    if (!RegExp(r'^\d{10,11}$').hasMatch(text)) {
                      return 'VKN 10, TCKN 11 hane olmalı';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefon (opsiyonel)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-posta (opsiyonel)',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: city,
                  decoration: const InputDecoration(
                    labelText: 'Şehir (opsiyonel)',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: termDays,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ödeme Vadesi (gün)',
                    prefixIcon: Icon(Icons.event_available_outlined),
                  ),
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());
                    if (parsed == null || parsed < 0 || parsed > 3650) {
                      return '0-3650 arası bir gün girin';
                    }
                    return null;
                  },
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  _FormError(message: error!),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setSheetState(() {
                              saving = true;
                              error = null;
                            });
                            try {
                              await api.createPartner(
                                code: code.text.trim(),
                                name: name.text.trim(),
                                type: type,
                                taxNumber: _nullIfEmpty(taxNumber.text),
                                phone: _nullIfEmpty(phone.text),
                                email: _nullIfEmpty(email.text),
                                city: _nullIfEmpty(city.text),
                                paymentTermDays:
                                    int.tryParse(termDays.text.trim()) ?? 0,
                              );
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext, true);
                              }
                            } catch (exception) {
                              setSheetState(() {
                                saving = false;
                                error = exception.toString();
                              });
                            }
                          },
                    child: saving
                        ? const _ButtonSpinner(label: 'Kaydediliyor')
                        : const Text('Cari Kartını Kaydet'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return created ?? false;
}

/// Çok satırlı satış faturası formu. Kayıt oluşturulduysa `true` döner.
Future<bool> showSalesInvoiceForm(BuildContext context, FinkitApi api) async {
  final partners = await api.partners();
  final products = await api.products();
  if (!context.mounted) return false;

  final customers = partners
      .where((partner) => partner['partner_type']?.toString() != 'SUPPLIER')
      .toList();
  if (customers.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fatura kesmek için önce bir müşteri kartı ekleyin.'),
      ),
    );
    return false;
  }

  final formKey = GlobalKey<FormState>();
  final description = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final unitPrice = TextEditingController();
  final notes = TextEditingController();
  var partnerId = customers.first['id'] as int?;
  var productId = products.isNotEmpty ? products.first['id'] as int? : null;
  var vatRate = 20.0;
  var issueDate = DateTime.now();
  var dueDate = DateTime.now().add(const Duration(days: 30));
  var saving = false;
  String? error;

  double net() =>
      (double.tryParse(quantity.text.replaceAll(',', '.')) ?? 0) *
      (double.tryParse(unitPrice.text.replaceAll(',', '.')) ?? 0);
  double vat() => net() * vatRate / 100;

  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: FinkitColors.canvas,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yeni Satış Faturası',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Kesinleştirilen fatura cari borç, stok çıkışı ve KDV hareketini birlikte oluşturur.',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: partnerId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Müşteri',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  items: customers
                      .map(
                        (partner) => DropdownMenuItem<int>(
                          value: partner['id'] as int?,
                          child: Text(
                            partner['name']?.toString() ?? 'Müşteri',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setSheetState(() => partnerId = value),
                ),
                if (products.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: productId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Ürün / Hizmet (opsiyonel)',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Serbest satır'),
                      ),
                      ...products.map(
                        (product) => DropdownMenuItem<int?>(
                          value: product['id'] as int?,
                          child: Text(
                            product['name']?.toString() ?? 'Ürün',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setSheetState(() {
                      productId = value;
                      final match = products
                          .where((product) => product['id'] == value)
                          .toList();
                      if (match.isEmpty) return;
                      final product = match.first;
                      description.text =
                          product['name']?.toString() ?? description.text;
                      final price =
                          product['sales_price'] ?? product['unit_price'];
                      if (price != null) {
                        unitPrice.text = '${double.tryParse('$price') ?? ''}';
                      }
                      final rate = double.tryParse('${product['vat_rate']}');
                      if (rate != null) vatRate = rate;
                    }),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: description,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Açıklama gerekli' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: quantity,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setSheetState(() {}),
                        decoration: const InputDecoration(labelText: 'Miktar'),
                        validator: (value) {
                          final parsed = double.tryParse(
                            (value ?? '').replaceAll(',', '.'),
                          );
                          if (parsed == null || parsed <= 0) {
                            return 'Miktar > 0 olmalı';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: unitPrice,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setSheetState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Birim Fiyat',
                        ),
                        validator: (value) {
                          final parsed = double.tryParse(
                            (value ?? '').replaceAll(',', '.'),
                          );
                          if (parsed == null || parsed < 0) {
                            return 'Fiyat girin';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<double>(
                  initialValue: vatRate,
                  decoration: const InputDecoration(
                    labelText: 'KDV Oranı',
                    prefixIcon: Icon(Icons.percent_rounded),
                  ),
                  items: _vatRates
                      .map(
                        (rate) => DropdownMenuItem<double>(
                          value: rate,
                          child: Text('%${rate.toStringAsFixed(0)}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setSheetState(() => vatRate = value ?? vatRate),
                ),
                const SizedBox(height: 12),
                _DateField(
                  label: 'Fatura Tarihi',
                  value: issueDate,
                  onPick: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: issueDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setSheetState(() {
                        issueDate = picked;
                        if (dueDate.isBefore(issueDate)) {
                          dueDate = issueDate.add(const Duration(days: 30));
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                _DateField(
                  label: 'Vade Tarihi',
                  value: dueDate,
                  onPick: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: dueDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setSheetState(() => dueDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Not (opsiyonel)',
                    prefixIcon: Icon(Icons.sticky_note_2_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                _TotalsPreview(net: net(), vat: vat()),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  _FormError(message: error!),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: saving
                            ? null
                            : () => _submitSalesInvoice(
                                sheetContext: sheetContext,
                                formKey: formKey,
                                api: api,
                                partnerId: partnerId,
                                productId: productId,
                                description: description.text.trim(),
                                quantity: quantity.text,
                                unitPrice: unitPrice.text,
                                vatRate: vatRate,
                                issueDate: issueDate,
                                dueDate: dueDate,
                                notes: notes.text.trim(),
                                finalize: false,
                                onState: (value, message) => setSheetState(() {
                                  saving = value;
                                  error = message;
                                }),
                              ),
                        child: const Text('Taslak Kaydet'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () => _submitSalesInvoice(
                                sheetContext: sheetContext,
                                formKey: formKey,
                                api: api,
                                partnerId: partnerId,
                                productId: productId,
                                description: description.text.trim(),
                                quantity: quantity.text,
                                unitPrice: unitPrice.text,
                                vatRate: vatRate,
                                issueDate: issueDate,
                                dueDate: dueDate,
                                notes: notes.text.trim(),
                                finalize: true,
                                onState: (value, message) => setSheetState(() {
                                  saving = value;
                                  error = message;
                                }),
                              ),
                        child: saving
                            ? const _ButtonSpinner(label: 'Kaydediliyor')
                            : const Text('Kesinleştir'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return created ?? false;
}

Future<void> _submitSalesInvoice({
  required BuildContext sheetContext,
  required GlobalKey<FormState> formKey,
  required FinkitApi api,
  required int? partnerId,
  required int? productId,
  required String description,
  required String quantity,
  required String unitPrice,
  required double vatRate,
  required DateTime issueDate,
  required DateTime dueDate,
  required String notes,
  required bool finalize,
  required void Function(bool saving, String? error) onState,
}) async {
  if (!formKey.currentState!.validate() || partnerId == null) return;
  onState(true, null);
  try {
    final invoice = await api.createSalesInvoice(
      partnerId: partnerId,
      issueDate: issueDate,
      dueDate: dueDate,
      notes: notes.isEmpty ? null : notes,
      lines: [
        {
          'product_id': ?productId,
          'description': description,
          'quantity': double.parse(quantity.replaceAll(',', '.')),
          'unit': 'ADET',
          'unit_price': double.parse(unitPrice.replaceAll(',', '.')),
          'discount_rate': 0,
          'vat_rate': vatRate,
          'withholding_rate': 0,
        },
      ],
    );
    final invoiceId = invoice['id'] as int?;
    if (finalize && invoiceId != null) {
      await api.finalizeSalesInvoice(invoiceId);
    }
    if (sheetContext.mounted) Navigator.pop(sheetContext, true);
  } catch (exception) {
    onState(false, exception.toString());
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime value;
  final Future<void> Function() onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_month_outlined),
        ),
        child: Text(dateText(value)),
      ),
    );
  }
}

class _TotalsPreview extends StatelessWidget {
  const _TotalsPreview({required this.net, required this.vat});

  final double net;
  final double vat;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FinkitColors.ink,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Ara Toplam', moneyText(net)),
          const SizedBox(height: 6),
          _row('KDV', moneyText(vat)),
          const Divider(color: Colors.white24, height: 20),
          _row('Genel Toplam', moneyText(net + vat), emphasize: true),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool emphasize = false}) {
    final style = TextStyle(
      color: emphasize ? Colors.white : Colors.white70,
      fontSize: emphasize ? 17 : 13,
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            style: style,
            maxLines: 1,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _FormError extends StatelessWidget {
  const _FormError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FinkitColors.dangerSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: FinkitColors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: FinkitColors.danger, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}

String _suggestCode(String type) {
  final prefix = switch (type) {
    'SUPPLIER' => 'T',
    'BOTH' => 'C',
    _ => 'M',
  };
  final stamp = DateTime.now().millisecondsSinceEpoch % 100000;
  return '$prefix$stamp';
}

String? _nullIfEmpty(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
