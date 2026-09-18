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
Future<bool> showSalesInvoiceForm(
  BuildContext context,
  FinkitApi api, {
  String type = 'SATIS',
}) async {
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
                  type == 'IADE' ? 'Yeni İade Faturası' : 'Yeni Satış Faturası',
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
                                invoiceType: type,
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
                                invoiceType: type,
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
  String invoiceType = 'SATIS',
  required void Function(bool saving, String? error) onState,
}) async {
  if (!formKey.currentState!.validate() || partnerId == null) return;
  onState(true, null);
  try {
    final invoice = await api.createSalesInvoice(
      partnerId: partnerId,
      invoiceType: invoiceType,
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

/// Tüm hızlı kayıt formlarında kullanılan ortak alt sayfa iskeleti.
class _EntrySheet extends StatefulWidget {
  const _EntrySheet({
    required this.title,
    required this.subtitle,
    required this.buildFields,
    required this.onSave,
    this.saveLabel = 'Kaydet',
  });

  final String title;
  final String subtitle;
  final List<Widget> Function(void Function(VoidCallback) refresh) buildFields;
  final Future<void> Function() onSave;
  final String saveLabel;

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave();
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = exception.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ...widget.buildFields((update) => setState(update)),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _FormError(message: _error!),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const _ButtonSpinner(label: 'Kaydediliyor')
                      : Text(widget.saveLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _number(String value) => double.tryParse(value.replaceAll(',', '.')) ?? 0;

String? _requiredText(String? value, String message) =>
    (value ?? '').trim().isEmpty ? message : null;

/// Ürün veya hizmet kartı oluşturur.
Future<bool> showProductForm(BuildContext context, FinkitApi api) async {
  final code = TextEditingController(
    text: 'U${DateTime.now().millisecondsSinceEpoch % 100000}',
  );
  final name = TextEditingController();
  final salesPrice = TextEditingController(text: '0');
  final purchasePrice = TextEditingController(text: '0');
  final manualCost = TextEditingController(text: '0');
  final unit = TextEditingController(text: 'ADET');
  final barcode = TextEditingController();
  var type = 'PRODUCT';
  var vatRate = 20.0;
  var trackInventory = true;

  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: FinkitColors.canvas,
    builder: (_) => _EntrySheet(
      title: 'Yeni Ürün / Hizmet',
      subtitle: 'Satış faturasında bu kartı seçerek fiyat ve KDV otomatik gelir.',
      saveLabel: 'Ürünü Kaydet',
      onSave: () async {
        await api.createProduct(
          code: code.text.trim(),
          name: name.text.trim(),
          type: type,
          unit: unit.text.trim().isEmpty ? 'ADET' : unit.text.trim(),
          vatRate: vatRate,
          salesPrice: _number(salesPrice.text),
          purchasePrice: _number(purchasePrice.text),
          manualCost: _number(manualCost.text),
          trackInventory: trackInventory,
          barcode: _nullIfEmpty(barcode.text),
        );
      },
      buildFields: (refresh) => [
        TextFormField(
          controller: name,
          decoration: const InputDecoration(
            labelText: 'Ad',
            prefixIcon: Icon(Icons.inventory_2_outlined),
          ),
          validator: (value) => _requiredText(value, 'Ad gerekli'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: code,
          decoration: const InputDecoration(
            labelText: 'Kod',
            prefixIcon: Icon(Icons.tag_rounded),
          ),
          validator: (value) => _requiredText(value, 'Kod gerekli'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: type,
          decoration: const InputDecoration(
            labelText: 'Tip',
            prefixIcon: Icon(Icons.category_outlined),
          ),
          items: const [
            DropdownMenuItem(value: 'PRODUCT', child: Text('Ürün')),
            DropdownMenuItem(value: 'SERVICE', child: Text('Hizmet')),
          ],
          onChanged: (value) => refresh(() => type = value ?? type),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: salesPrice,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Satış Fiyatı'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: purchasePrice,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Alış Fiyatı'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: manualCost,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Stok Maliyeti',
                  helperText: 'Satışta kâr hesabı için',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: unit,
                decoration: const InputDecoration(labelText: 'Birim'),
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
          onChanged: (value) => refresh(() => vatRate = value ?? vatRate),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: barcode,
          decoration: const InputDecoration(
            labelText: 'Barkod (opsiyonel)',
            prefixIcon: Icon(Icons.qr_code_2_rounded),
          ),
        ),
        const SizedBox(height: 6),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: trackInventory,
          onChanged: (value) => refresh(() => trackInventory = value),
          title: const Text('Stok takibi yapılsın'),
        ),
      ],
    ),
  );
  return created ?? false;
}

/// Depo tanımı oluşturur.
Future<bool> showWarehouseForm(BuildContext context, FinkitApi api) async {
  final code = TextEditingController(
    text: 'D${DateTime.now().millisecondsSinceEpoch % 100000}',
  );
  final name = TextEditingController();
  final city = TextEditingController();
  var isDefault = false;

  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: FinkitColors.canvas,
    builder: (_) => _EntrySheet(
      title: 'Yeni Depo',
      subtitle: 'Stok giriş çıkışları depo bazında izlenir.',
      saveLabel: 'Depoyu Kaydet',
      onSave: () async {
        await api.createWarehouse(
          code: code.text.trim(),
          name: name.text.trim(),
          city: _nullIfEmpty(city.text),
          isDefault: isDefault,
        );
      },
      buildFields: (refresh) => [
        TextFormField(
          controller: name,
          decoration: const InputDecoration(
            labelText: 'Depo Adı',
            prefixIcon: Icon(Icons.warehouse_outlined),
          ),
          validator: (value) => _requiredText(value, 'Depo adı gerekli'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: code,
          decoration: const InputDecoration(
            labelText: 'Depo Kodu',
            prefixIcon: Icon(Icons.tag_rounded),
          ),
          validator: (value) => _requiredText(value, 'Kod gerekli'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: city,
          decoration: const InputDecoration(
            labelText: 'Şehir (opsiyonel)',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
        ),
        const SizedBox(height: 6),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: isDefault,
          onChanged: (value) => refresh(() => isDefault = value),
          title: const Text('Varsayılan depo'),
        ),
      ],
    ),
  );
  return created ?? false;
}

/// Stok giriş/çıkış hareketi oluşturur.
Future<bool> showStockMovementForm(
  BuildContext context,
  FinkitApi api, {
  String type = 'IN',
}) async {
  final warehouses = await api.warehouses();
  final products = await api.products();
  if (!context.mounted) return false;
  if (warehouses.isEmpty || products.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stok hareketi için önce depo ve ürün ekleyin.'),
      ),
    );
    return false;
  }

  final quantity = TextEditingController(text: '1');
  final unitCost = TextEditingController(text: '0');
  final description = TextEditingController();
  var warehouseId = warehouses.first['id'] as int?;
  var productId = products.first['id'] as int?;

  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: FinkitColors.canvas,
    builder: (_) => _EntrySheet(
      title: type == 'IN' ? 'Stok Girişi' : 'Stok Çıkışı',
      subtitle: 'Depo bazlı miktar ve maliyet güncellenir.',
      saveLabel: 'Hareketi Kaydet',
      onSave: () async {
        await api.createStockMovement(
          warehouseId: warehouseId!,
          productId: productId!,
          quantity: _number(quantity.text),
          type: type,
          unitCost: _number(unitCost.text),
          description: _nullIfEmpty(description.text),
        );
      },
      buildFields: (refresh) => [
        DropdownButtonFormField<int>(
          initialValue: productId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Ürün / Hizmet',
            prefixIcon: Icon(Icons.inventory_2_outlined),
          ),
          items: products
              .map(
                (product) => DropdownMenuItem<int>(
                  value: product['id'] as int?,
                  child: Text(
                    product['name']?.toString() ?? 'Ürün',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => refresh(() => productId = value),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: warehouseId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Depo',
            prefixIcon: Icon(Icons.warehouse_outlined),
          ),
          items: warehouses
              .map(
                (warehouse) => DropdownMenuItem<int>(
                  value: warehouse['id'] as int?,
                  child: Text(
                    warehouse['name']?.toString() ?? 'Depo',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => refresh(() => warehouseId = value),
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
                decoration: const InputDecoration(labelText: 'Miktar'),
                validator: (value) =>
                    _number(value ?? '') <= 0 ? 'Miktar > 0 olmalı' : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: unitCost,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Birim Maliyet'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: description,
          decoration: const InputDecoration(
            labelText: 'Açıklama (opsiyonel)',
            prefixIcon: Icon(Icons.notes_rounded),
          ),
        ),
      ],
    ),
  );
  return created ?? false;
}

/// Teklif oluşturur.
Future<bool> showQuoteForm(BuildContext context, FinkitApi api) async {
  final partners = await api.partners();
  final products = await api.products();
  if (!context.mounted) return false;
  final customers = partners
      .where((partner) => partner['partner_type']?.toString() != 'SUPPLIER')
      .toList();
  if (customers.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Teklif için önce müşteri kartı ekleyin.')),
    );
    return false;
  }

  final description = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final unitPrice = TextEditingController();
  final notes = TextEditingController();
  var partnerId = customers.first['id'] as int?;
  var productId = products.isNotEmpty ? products.first['id'] as int? : null;
  var vatRate = 20.0;
  var validUntil = DateTime.now().add(const Duration(days: 15));

  double net() => _number(quantity.text) * _number(unitPrice.text);
  double vat() => net() * vatRate / 100;

  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: FinkitColors.canvas,
    builder: (_) => _EntrySheet(
      title: 'Yeni Teklif',
      subtitle: 'Teklif cari veya stok hareketi oluşturmaz.',
      saveLabel: 'Teklifi Kaydet',
      onSave: () async {
        await api.createQuote(
          partnerId: partnerId!,
          productId: productId,
          description: description.text.trim(),
          quantity: _number(quantity.text),
          unitPrice: _number(unitPrice.text),
          vatRate: vatRate,
          validUntil: validUntil,
          notes: _nullIfEmpty(notes.text),
        );
      },
      buildFields: (refresh) => [
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
          onChanged: (value) => refresh(() => partnerId = value),
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
            onChanged: (value) => refresh(() {
              productId = value;
              final match = products.where(
                (product) => product['id'] == value,
              );
              if (match.isEmpty) return;
              final product = match.first;
              description.text = product['name']?.toString() ?? '';
              unitPrice.text = '${_number('${product['sales_price']}')}';
              vatRate = _number('${product['vat_rate']}');
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
          validator: (value) => _requiredText(value, 'Açıklama gerekli'),
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
                onChanged: (_) => refresh(() {}),
                decoration: const InputDecoration(labelText: 'Miktar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: unitPrice,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => refresh(() {}),
                decoration: const InputDecoration(labelText: 'Birim Fiyat'),
                validator: (value) =>
                    _number(value ?? '') < 0 ? 'Fiyat girin' : null,
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
          onChanged: (value) => refresh(() => vatRate = value ?? vatRate),
        ),
        const SizedBox(height: 12),
        _DateField(
          label: 'Geçerlilik Tarihi',
          value: validUntil,
          onPick: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: validUntil,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked != null) refresh(() => validUntil = picked);
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
      ],
    ),
  );
  return created ?? false;
}

/// Gelen (alış) faturası oluşturur.
Future<bool> showPurchaseInvoiceForm(
  BuildContext context,
  FinkitApi api,
) async {
  final partners = await api.partners();
  final products = await api.products();
  final warehouses = await api.warehouses();
  if (!context.mounted) return false;
  final suppliers = partners
      .where((partner) => partner['partner_type']?.toString() != 'CUSTOMER')
      .toList();
  if (suppliers.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gelen fatura için önce tedarikçi kartı ekleyin.'),
      ),
    );
    return false;
  }

  final description = TextEditingController();
  final netAmount = TextEditingController();
  final invoiceNumber = TextEditingController();
  var supplierId = suppliers.first['id'] as int?;
  var productId = products.isNotEmpty ? products.first['id'] as int? : null;
  var warehouseId = warehouses.isNotEmpty ? warehouses.first['id'] as int? : null;
  var vatRate = 20.0;
  var dueDate = DateTime.now().add(const Duration(days: 30));
  var inventory = products.isNotEmpty && warehouses.isNotEmpty;

  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: FinkitColors.canvas,
    builder: (_) => _EntrySheet(
      title: 'Yeni Gelen Fatura',
      subtitle:
          'Kaydettiğinizde tedarikçi cari borcu, KDV ve (seçiliyse) stok girişi oluşur.',
      saveLabel: 'Faturayı Kaydet',
      onSave: () async {
        final invoice = await api.createPurchaseInvoice(
          supplierId: supplierId!,
          description: description.text.trim(),
          netAmount: _number(netAmount.text),
          vatRate: vatRate,
          dueDate: dueDate,
          inventory: inventory,
          productId: productId,
          warehouseId: warehouseId,
          number: _nullIfEmpty(invoiceNumber.text),
        );
        final invoiceId = invoice['id'] as int?;
        if (invoiceId != null) {
          await api.postPurchaseInvoice(invoiceId);
        }
      },
      buildFields: (refresh) => [
        DropdownButtonFormField<int>(
          initialValue: supplierId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Tedarikçi',
            prefixIcon: Icon(Icons.local_shipping_outlined),
          ),
          items: suppliers
              .map(
                (supplier) => DropdownMenuItem<int>(
                  value: supplier['id'] as int?,
                  child: Text(
                    supplier['name']?.toString() ?? 'Tedarikçi',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => refresh(() => supplierId = value),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: invoiceNumber,
          decoration: const InputDecoration(
            labelText: 'Fatura No (opsiyonel)',
            prefixIcon: Icon(Icons.tag_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: description,
          decoration: const InputDecoration(
            labelText: 'Açıklama',
            prefixIcon: Icon(Icons.notes_rounded),
          ),
          validator: (value) => _requiredText(value, 'Açıklama gerekli'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: netAmount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Net Tutar'),
                validator: (value) =>
                    _number(value ?? '') <= 0 ? 'Tutar girin' : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<double>(
                initialValue: vatRate,
                decoration: const InputDecoration(labelText: 'KDV'),
                items: _vatRates
                    .map(
                      (rate) => DropdownMenuItem<double>(
                        value: rate,
                        child: Text('%${rate.toStringAsFixed(0)}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => refresh(() => vatRate = value ?? vatRate),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DateField(
          label: 'Ödeme Vadesi',
          value: dueDate,
          onPick: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: dueDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked != null) refresh(() => dueDate = picked);
          },
        ),
        if (products.isNotEmpty && warehouses.isNotEmpty) ...[
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: inventory,
            onChanged: (value) => refresh(() => inventory = value),
            title: const Text('Stok girişi olarak işle'),
          ),
          if (inventory) ...[
            DropdownButtonFormField<int?>(
              initialValue: productId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Ürün',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              items: products
                  .map(
                    (product) => DropdownMenuItem<int?>(
                      value: product['id'] as int?,
                      child: Text(
                        product['name']?.toString() ?? 'Ürün',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => refresh(() => productId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: warehouseId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Depo',
                prefixIcon: Icon(Icons.warehouse_outlined),
              ),
              items: warehouses
                  .map(
                    (warehouse) => DropdownMenuItem<int?>(
                      value: warehouse['id'] as int?,
                      child: Text(
                        warehouse['name']?.toString() ?? 'Depo',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => refresh(() => warehouseId = value),
            ),
          ],
        ],
      ],
    ),
  );
  return created ?? false;
}

/// Çalışan kartı oluşturur.
Future<bool> showEmployeeForm(BuildContext context, FinkitApi api) async {
  final employeeNo = TextEditingController(
    text: 'P${DateTime.now().millisecondsSinceEpoch % 100000}',
  );
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final grossSalary = TextEditingController();
  final position = TextEditingController();
  final department = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final nationalId = TextEditingController();
  var hireDate = DateTime.now();

  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: FinkitColors.canvas,
    builder: (_) => _EntrySheet(
      title: 'Yeni Çalışan',
      subtitle: 'Bordro ve puantaj bu kart üzerinden işlenir.',
      saveLabel: 'Çalışanı Kaydet',
      onSave: () async {
        await api.createEmployee(
          employeeNo: employeeNo.text.trim(),
          firstName: firstName.text.trim(),
          lastName: lastName.text.trim(),
          grossSalary: _number(grossSalary.text),
          position: _nullIfEmpty(position.text),
          department: _nullIfEmpty(department.text),
          phone: _nullIfEmpty(phone.text),
          email: _nullIfEmpty(email.text),
          nationalId: _nullIfEmpty(nationalId.text),
          hireDate: hireDate,
        );
      },
      buildFields: (refresh) => [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: firstName,
                decoration: const InputDecoration(labelText: 'Ad'),
                validator: (value) => _requiredText(value, 'Ad gerekli'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: lastName,
                decoration: const InputDecoration(labelText: 'Soyad'),
                validator: (value) => _requiredText(value, 'Soyad gerekli'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: employeeNo,
          decoration: const InputDecoration(
            labelText: 'Sicil No',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          validator: (value) => _requiredText(value, 'Sicil no gerekli'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: nationalId,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'TCKN (opsiyonel)',
            prefixIcon: Icon(Icons.numbers_rounded),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: position,
                decoration: const InputDecoration(labelText: 'Görev'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: department,
                decoration: const InputDecoration(labelText: 'Departman'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: grossSalary,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Brüt Ücret',
            prefixIcon: Icon(Icons.payments_outlined),
          ),
          validator: (value) =>
              _number(value ?? '') <= 0 ? 'Brüt ücret girin' : null,
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
        _DateField(
          label: 'İşe Giriş Tarihi',
          value: hireDate,
          onPick: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: hireDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) refresh(() => hireDate = picked);
          },
        ),
      ],
    ),
  );
  return created ?? false;
}

/// Çalışana avans kaydı ekler.
Future<bool> showEmployeeAdvanceForm(
  BuildContext context,
  FinkitApi api,
  Map<String, dynamic> employee,
) async {
  final amount = TextEditingController();
  final employeeId = int.tryParse('${employee['id']}');
  if (employeeId == null) return false;

  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: FinkitColors.canvas,
    builder: (_) => _EntrySheet(
      title: 'Avans Ver',
      subtitle:
          '${employee['first_name'] ?? ''} ${employee['last_name'] ?? ''}'.trim(),
      saveLabel: 'Avansı Kaydet',
      onSave: () async {
        await api.createEmployeeAdvance(
          employeeId: employeeId,
          amount: _number(amount.text),
        );
      },
      buildFields: (refresh) => [
        TextFormField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Avans Tutarı',
            prefixIcon: Icon(Icons.savings_outlined),
          ),
          validator: (value) =>
              _number(value ?? '') <= 0 ? 'Tutar girin' : null,
        ),
      ],
    ),
  );
  return created ?? false;
}

/// Çek veya senet kaydı oluşturur.
Future<bool> showCheckNoteForm(BuildContext context, FinkitApi api) async {
  final serialNo = TextEditingController();
  final amount = TextEditingController();
  final counterparty = TextEditingController();
  final bankName = TextEditingController();
  final notes = TextEditingController();
  var direction = 'IN';
  var instrumentType = 'CHECK';
  var dueDate = DateTime.now().add(const Duration(days: 30));

  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: FinkitColors.canvas,
    builder: (_) => _EntrySheet(
      title: 'Yeni Çek / Senet',
      subtitle: 'Alınan çekler portföyde, verilenler ödeneceklerde izlenir.',
      saveLabel: 'Kaydet',
      onSave: () async {
        await api.createCheckNote(
          direction: direction,
          instrumentType: instrumentType,
          serialNo: serialNo.text.trim(),
          dueDate: dueDate,
          amount: _number(amount.text),
          bankName: _nullIfEmpty(bankName.text),
          counterparty: _nullIfEmpty(counterparty.text),
          notes: _nullIfEmpty(notes.text),
        );
      },
      buildFields: (refresh) => [
        DropdownButtonFormField<String>(
          initialValue: direction,
          decoration: const InputDecoration(
            labelText: 'Yön',
            prefixIcon: Icon(Icons.swap_horiz_rounded),
          ),
          items: const [
            DropdownMenuItem(value: 'IN', child: Text('Alınan (müşteri)')),
            DropdownMenuItem(value: 'OUT', child: Text('Verilen (tedarikçi)')),
          ],
          onChanged: (value) => refresh(() => direction = value ?? direction),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: instrumentType,
          decoration: const InputDecoration(
            labelText: 'Tür',
            prefixIcon: Icon(Icons.receipt_outlined),
          ),
          items: const [
            DropdownMenuItem(value: 'CHECK', child: Text('Çek')),
            DropdownMenuItem(value: 'PROMISSORY_NOTE', child: Text('Senet')),
          ],
          onChanged: (value) =>
              refresh(() => instrumentType = value ?? instrumentType),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: serialNo,
          decoration: const InputDecoration(
            labelText: 'Seri No',
            prefixIcon: Icon(Icons.tag_rounded),
          ),
          validator: (value) => _requiredText(value, 'Seri no gerekli'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Tutar',
            prefixIcon: Icon(Icons.currency_lira_rounded),
          ),
          validator: (value) =>
              _number(value ?? '') <= 0 ? 'Tutar girin' : null,
        ),
        const SizedBox(height: 12),
        _DateField(
          label: 'Vade Tarihi',
          value: dueDate,
          onPick: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: dueDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (picked != null) refresh(() => dueDate = picked);
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: counterparty,
          decoration: InputDecoration(
            labelText: direction == 'IN' ? 'Keşideci' : 'Lehtar',
            prefixIcon: const Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: bankName,
          decoration: const InputDecoration(
            labelText: 'Banka (opsiyonel)',
            prefixIcon: Icon(Icons.account_balance_outlined),
          ),
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
      ],
    ),
  );
  return created ?? false;
}

/// Tedarikçiye ödeme kaydı oluşturur.
Future<bool> showSupplierPaymentForm(
  BuildContext context,
  FinkitApi api,
) async {
  final partners = await api.partners();
  if (!context.mounted) return false;
  final suppliers = partners
      .where((partner) => partner['partner_type']?.toString() != 'CUSTOMER')
      .toList();
  if (suppliers.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ödeme için önce tedarikçi kartı ekleyin.')),
    );
    return false;
  }

  final amount = TextEditingController();
  var supplierId = suppliers.first['id'] as int?;

  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: FinkitColors.canvas,
    builder: (_) => _EntrySheet(
      title: 'Tedarikçi Ödemesi',
      subtitle: 'Ödeme en eski vadeli faturaya otomatik dağıtılır.',
      saveLabel: 'Ödemeyi Kaydet',
      onSave: () async {
        await api.createSupplierPayment(
          supplierId: supplierId!,
          amount: _number(amount.text),
        );
      },
      buildFields: (refresh) => [
        DropdownButtonFormField<int>(
          initialValue: supplierId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Tedarikçi',
            prefixIcon: Icon(Icons.local_shipping_outlined),
          ),
          items: suppliers
              .map(
                (supplier) => DropdownMenuItem<int>(
                  value: supplier['id'] as int?,
                  child: Text(
                    supplier['name']?.toString() ?? 'Tedarikçi',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => refresh(() => supplierId = value),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Tutar',
            prefixIcon: Icon(Icons.currency_lira_rounded),
          ),
          validator: (value) =>
              _number(value ?? '') <= 0 ? 'Tutar girin' : null,
        ),
      ],
    ),
  );
  return created ?? false;
}

/// Kasa / banka hesabı oluşturur.
Future<bool> showFinancialAccountForm(
  BuildContext context,
  FinkitApi api,
) async {
  final name = TextEditingController();
  final bankName = TextEditingController();
  final iban = TextEditingController();
  final openingBalance = TextEditingController(text: '0');
  var type = 'CASH';

  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: FinkitColors.canvas,
    builder: (_) => _EntrySheet(
      title: 'Yeni Hesap',
      subtitle: 'Kasa, banka, POS ve kredi kartı hesapları tanımlanır.',
      saveLabel: 'Hesabı Kaydet',
      onSave: () async {
        await api.createFinancialAccount(
          name: name.text.trim(),
          type: type,
          bankName: _nullIfEmpty(bankName.text),
          iban: _nullIfEmpty(iban.text),
          openingBalance: _number(openingBalance.text),
        );
      },
      buildFields: (refresh) => [
        TextFormField(
          controller: name,
          decoration: const InputDecoration(
            labelText: 'Hesap Adı',
            prefixIcon: Icon(Icons.account_balance_wallet_outlined),
          ),
          validator: (value) => _requiredText(value, 'Hesap adı gerekli'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: type,
          decoration: const InputDecoration(
            labelText: 'Hesap Türü',
            prefixIcon: Icon(Icons.category_outlined),
          ),
          items: const [
            DropdownMenuItem(value: 'CASH', child: Text('Kasa')),
            DropdownMenuItem(value: 'BANK', child: Text('Banka')),
            DropdownMenuItem(value: 'POS', child: Text('POS')),
            DropdownMenuItem(value: 'CREDIT_CARD', child: Text('Kredi Kartı')),
          ],
          onChanged: (value) => refresh(() => type = value ?? type),
        ),
        if (type != 'CASH') ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: bankName,
            decoration: const InputDecoration(
              labelText: 'Banka Adı',
              prefixIcon: Icon(Icons.account_balance_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: iban,
            decoration: const InputDecoration(
              labelText: 'IBAN (opsiyonel)',
              prefixIcon: Icon(Icons.credit_card_outlined),
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          controller: openingBalance,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Açılış Bakiyesi',
            prefixIcon: Icon(Icons.savings_outlined),
          ),
        ),
      ],
    ),
  );
  return created ?? false;
}

String? _nullIfEmpty(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Ödeme hatırlatma kuralı oluşturur (SMS veya e-posta).
Future<bool> showReminderRuleForm(BuildContext context, FinkitApi api) async {
  final daysBefore = TextEditingController(text: '3');
  final message = TextEditingController();
  var channel = 'sms';

  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: FinkitColors.canvas,
    builder: (_) => _EntrySheet(
      title: 'Yeni Hatırlatma Kuralı',
      subtitle: 'Vade tarihinden belirtilen gün önce hatırlatma gönderilir.',
      saveLabel: 'Kuralı Kaydet',
      onSave: () async {
        await api.createReminderRule(
          channel: channel,
          daysBefore: int.tryParse(daysBefore.text.trim()) ?? 3,
          message: _nullIfEmpty(message.text),
        );
      },
      buildFields: (refresh) => [
        DropdownButtonFormField<String>(
          initialValue: channel,
          decoration: const InputDecoration(
            labelText: 'Kanal',
            prefixIcon: Icon(Icons.send_outlined),
          ),
          items: const [
            DropdownMenuItem(value: 'sms', child: Text('SMS')),
            DropdownMenuItem(value: 'email', child: Text('E-posta')),
          ],
          onChanged: (value) => refresh(() => channel = value ?? channel),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: daysBefore,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Vadeden kaç gün önce',
            prefixIcon: Icon(Icons.event_available_outlined),
          ),
          validator: (value) {
            final parsed = int.tryParse((value ?? '').trim());
            if (parsed == null || parsed < 0 || parsed > 90) {
              return '0-90 arası bir gün girin';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: message,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Mesaj (opsiyonel)',
            prefixIcon: Icon(Icons.notes_rounded),
          ),
        ),
      ],
    ),
  );
  return created ?? false;
}
