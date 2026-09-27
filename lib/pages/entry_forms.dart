import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets.dart';
import 'partner_form_page.dart';
import 'form_layout.dart';
import 'invoice_detail_page.dart';
import 'sales_invoice_form_page.dart';

const _vatRates = <double>[0, 1, 8, 10, 18, 20];

String? _positiveAmount(String? value) {
  final amount = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
  return amount == null || !amount.isFinite || amount <= 0
      ? 'Sıfırdan büyük bir tutar girin (ör. 1250,50)'
      : null;
}

Future<bool> showExpenseEntryForm(BuildContext context, FinkitApi api) async {
  final description = TextEditingController();
  final amount = TextEditingController();
  var vatRate = 20.0;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: FinkitColors.canvas,
    builder: (_) => _EntrySheet(
      title: 'Gider Ekle',
      subtitle:
          'Net tutarı ve KDV oranını girin. Toplamı kontrol ederek kaydedin.',
      onSave: () async {
        await api.createExpense(
          description: description.text.trim(),
          netAmount: _number(amount.text),
          vatRate: vatRate,
        );
      },
      buildFields: (refresh) => [
        TextFormField(
          controller: description,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Açıklama',
            hintText: 'Ör. Ofis malzemeleri',
            prefixIcon: Icon(Icons.edit_note_rounded),
          ),
          validator: (v) => _requiredText(v, 'Açıklama gerekli'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => refresh(() {}),
          decoration: const InputDecoration(
            labelText: 'Net tutar',
            hintText: '0,00',
            suffixText: '₺',
          ),
          validator: _positiveAmount,
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<double>(
          initialValue: vatRate,
          decoration: const InputDecoration(labelText: 'KDV oranı'),
          items: _vatRates
              .map(
                (rate) => DropdownMenuItem(
                  value: rate,
                  child: Text('%${rate.toInt()}'),
                ),
              )
              .toList(),
          onChanged: (v) => refresh(() => vatRate = v ?? 20),
        ),
        const SizedBox(height: 16),
        _TotalsPreview(
          net: _number(amount.text),
          vat: _number(amount.text) * vatRate / 100,
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<bool> showCollectionEntryForm(
  BuildContext context,
  FinkitApi api, {
  int? initialPartnerId,
}) async {
  final partners = (await api.partners())
      .where((p) => p['partner_type'] != 'SUPPLIER')
      .toList();
  final accounts = await api.accounts();
  if (!context.mounted) return false;
  if (partners.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tahsilat için önce bir müşteri ekleyin.')),
    );
    return false;
  }
  final amount = TextEditingController();
  int? partnerId = partners.any((partner) => partner['id'] == initialPartnerId)
      ? initialPartnerId
      : null;
  int? accountId;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: FinkitColors.canvas,
    builder: (_) => _EntrySheet(
      title: 'Tahsilat Al',
      subtitle: 'Müşteriyi seçin ve tahsil edilen tutarı girin.',
      saveLabel: 'Tahsilatı Kaydet',
      onSave: () async {
        await api.createCollection(
          partnerId: partnerId!,
          amount: _number(amount.text),
          accountId: accountId,
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
          items: partners
              .map(
                (p) => DropdownMenuItem(
                  value: p['id'] as int,
                  child: Text('${p['name']}', overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          validator: (v) => v == null ? 'Müşteri seçin' : null,
          onChanged: (v) => refresh(() => partnerId = v),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(
          initialValue: accountId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Kasa / Banka (opsiyonel)',
          ),
          items: accounts
              .map(
                (a) => DropdownMenuItem(
                  value: a['id'] as int,
                  child: Text('${a['name']}', overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (v) => refresh(() => accountId = v),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Tahsilat tutarı',
            hintText: '0,00',
            suffixText: '₺',
          ),
          validator: _positiveAmount,
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Cari kartı oluşturma ekranını açar. Kayıt başarılıysa `true` döner.
///
/// Ayrıntılı form `partner_form_page.dart` içindedir: cari bilgileri, adres(ler),
/// e-dönüşüm kutusu, yetkili bilgileri, IBAN ve açılış bakiyesi alanlarını içerir.
Future<bool> showPartnerForm(
  BuildContext context,
  FinkitApi api, {
  String defaultType = 'CUSTOMER',
}) => showPartnerCreatePage(context, api, defaultType: defaultType);

/// Çok satırlı satış faturası formu. Kayıt oluşturulduysa `true` döner.
Future<bool> showSalesInvoiceForm(
  BuildContext context,
  FinkitApi api, {
  String type = 'SATIS',
}) async =>
    await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => SalesInvoiceFormPage(api: api, initialType: type),
      ),
    ) !=
    null;

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
    if (_saving || !validateAndReveal(_formKey)) return;
    FocusScope.of(context).unfocus();
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
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: EntryFormLayout(
        title: widget.title,
        subtitle: widget.subtitle,
        saving: _saving,
        fields: [
          const FormSectionLabel('Kayıt bilgileri'),
          ...widget.buildFields((update) => setState(update)),
        ],
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              _FormError(message: _error!),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox.shrink()
                    : const Icon(Icons.check_rounded),
                label: _saving
                    ? const _ButtonSpinner(label: 'Kaydediliyor')
                    : Text(widget.saveLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _number(String value) =>
    double.tryParse(value.replaceAll(',', '.')) ?? 0;

String? _requiredText(String? value, String message) =>
    (value ?? '').trim().isEmpty ? message : null;

/// Ürün veya hizmet kartı oluşturur ya da mevcut kartı düzenler.
Future<bool> showProductForm(
  BuildContext context,
  FinkitApi api, {
  Map<String, dynamic>? product,
}) async {
  List<Map<String, dynamic>> warehouses = const [];
  if (product == null) {
    try {
      warehouses = (await api.warehouses())
          .where((warehouse) => warehouse['is_active'] != false)
          .toList();
    } catch (_) {
      // Katalog kaydı, depo listesi geçici olarak alınamasa da açılabilir.
    }
    if (!context.mounted) return false;
  }
  final code = TextEditingController(
    text:
        product?['code']?.toString() ??
        'U${DateTime.now().millisecondsSinceEpoch % 100000}',
  );
  final name = TextEditingController(text: product?['name']?.toString() ?? '');
  final salesPrice = TextEditingController(
    text: product?['sales_price']?.toString() ?? '0',
  );
  final purchasePrice = TextEditingController(
    text: product?['purchase_price']?.toString() ?? '0',
  );
  final unit = TextEditingController(
    text: product?['unit']?.toString() ?? 'ADET',
  );
  final barcode = TextEditingController(
    text: product?['barcode']?.toString() ?? '',
  );
  final description = TextEditingController(
    text: product?['description']?.toString() ?? '',
  );
  final minimumStock = TextEditingController(
    text: product?['minimum_stock']?.toString() ?? '0',
  );
  final openingQuantity = TextEditingController(text: '0');
  final openingUnitCost = TextEditingController();
  var openingWarehouseId =
      (warehouses
                  .where((warehouse) => warehouse['is_default'] == true)
                  .firstOrNull ??
              warehouses.firstOrNull)?['id']
          as int?;
  var openingDate = DateTime.now();
  var priceIncludesVat = false;
  var type = product?['product_type']?.toString() ?? 'PRODUCT';
  var vatRate = double.tryParse('${product?['vat_rate'] ?? 20}') ?? 20.0;
  var trackInventory = product?['track_inventory'] == true || product == null;
  var isActive = product?['is_active'] != false;

  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: FinkitColors.canvas,
    builder: (_) => _EntrySheet(
      title: product == null ? 'Yeni Ürün / Hizmet' : 'Ürün / Hizmet Düzenle',
      subtitle:
          'Satış faturasında bu kartı seçerek fiyat ve KDV otomatik gelir.',
      saveLabel: product == null ? 'Ürünü Kaydet' : 'Değişiklikleri Kaydet',
      onSave: () async {
        final enteredPrice = _number(salesPrice.text);
        final netPrice = priceIncludesVat && vatRate > 0
            ? ((enteredPrice / (1 + vatRate / 100)) * 100).round() / 100
            : (enteredPrice * 100).round() / 100;
        if (product == null) {
          final quantity = _number(openingQuantity.text);
          if (quantity > 0 &&
              (type == 'SERVICE' ||
                  !trackInventory ||
                  openingWarehouseId == null)) {
            throw StateError(
              'Başlangıç stoğu için stok takipli ürün ve aktif depo seçin.',
            );
          }
          await api.createProduct(
            code: code.text.trim(),
            name: name.text.trim(),
            type: type,
            unit: unit.text.trim().isEmpty ? 'ADET' : unit.text.trim(),
            vatRate: vatRate,
            salesPrice: netPrice,
            purchasePrice: _number(purchasePrice.text),
            manualCost: _number(purchasePrice.text),
            trackInventory: type == 'SERVICE' ? false : trackInventory,
            barcode: _nullIfEmpty(barcode.text),
            description: _nullIfEmpty(description.text),
            minimumStock: _number(minimumStock.text),
            isActive: isActive,
            openingStock: quantity > 0
                ? {
                    'warehouse_id': openingWarehouseId,
                    'quantity': quantity,
                    'unit_cost': _number(openingUnitCost.text) > 0
                        ? _number(openingUnitCost.text)
                        : _number(purchasePrice.text),
                    'movement_date':
                        '${openingDate.year.toString().padLeft(4, '0')}-${openingDate.month.toString().padLeft(2, '0')}-${openingDate.day.toString().padLeft(2, '0')}',
                  }
                : null,
          );
        } else {
          await api.updateProduct((product['id'] as num).toInt(), {
            'code': code.text.trim(),
            'name': name.text.trim(),
            'product_type': type,
            'unit': unit.text.trim().isEmpty ? 'ADET' : unit.text.trim(),
            'vat_rate': vatRate,
            'sales_price': netPrice,
            'purchase_price': _number(purchasePrice.text),
            'minimum_stock': _number(minimumStock.text),
            'track_inventory': type == 'SERVICE' ? false : trackInventory,
            'barcode': _nullIfEmpty(barcode.text),
            'description': _nullIfEmpty(description.text),
            'is_active': isActive,
          });
        }
      },
      buildFields: (refresh) => [
        TextFormField(
          textInputAction: TextInputAction.next,
          controller: name,
          decoration: const InputDecoration(
            labelText: 'Ad',
            prefixIcon: Icon(Icons.inventory_2_outlined),
          ),
          validator: (value) => _requiredText(value, 'Ad gerekli'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          textInputAction: TextInputAction.next,
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
          onChanged: (value) => refresh(() {
            type = value ?? type;
            if (type == 'SERVICE') trackInventory = false;
          }),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                textInputAction: TextInputAction.next,
                controller: salesPrice,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Satış Fiyatı'),
                onChanged: (_) => refresh(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                textInputAction: TextInputAction.next,
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
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: priceIncludesVat,
          onChanged: (value) => refresh(() => priceIncludesVat = value),
          title: const Text('Girilen satış fiyatına KDV dâhil'),
        ),
        Text(
          'KDV hariç: ${moneyText(priceIncludesVat && vatRate > 0 ? ((_number(salesPrice.text) / (1 + vatRate / 100)) * 100).round() / 100 : _number(salesPrice.text))}',
        ),
        const SizedBox(height: 12),
        TextFormField(
          textInputAction: TextInputAction.next,
          controller: unit,
          decoration: const InputDecoration(labelText: 'Birim'),
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
          textInputAction: TextInputAction.next,
          controller: barcode,
          decoration: const InputDecoration(
            labelText: 'Barkod (opsiyonel)',
            prefixIcon: Icon(Icons.qr_code_2_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: description,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Açıklama'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: minimumStock,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Minimum stok'),
        ),
        const SizedBox(height: 6),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: type == 'SERVICE' ? false : trackInventory,
          onChanged: type == 'SERVICE'
              ? null
              : (value) => refresh(() => trackInventory = value),
          title: const Text('Stok takibi yapılsın'),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: isActive,
          onChanged: (value) => refresh(() => isActive = value),
          title: const Text('Aktif'),
        ),
        if (product == null && type == 'PRODUCT' && trackInventory) ...[
          const SizedBox(height: 16),
          Text(
            'Başlangıç stoğu',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: openingQuantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Miktar'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: openingWarehouseId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Depo'),
            items: warehouses
                .map(
                  (warehouse) => DropdownMenuItem<int>(
                    value: (warehouse['id'] as num).toInt(),
                    child: Text('${warehouse['name']}'),
                  ),
                )
                .toList(),
            onChanged: (value) => refresh(() => openingWarehouseId = value),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: openingUnitCost,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Birim maliyet',
              helperText: 'Boşsa alış fiyatı kullanılır',
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: openingDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) refresh(() => openingDate = picked);
            },
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              'Stok tarihi: ${openingDate.day}.${openingDate.month}.${openingDate.year}',
            ),
          ),
        ],
      ],
    ),
  );
  return created ?? false;
}

/// Depo tanımı oluşturur veya düzenler.
Future<bool> showWarehouseForm(
  BuildContext context,
  FinkitApi api, {
  Map<String, dynamic>? warehouse,
}) async {
  final code = TextEditingController(
    text:
        warehouse?['code']?.toString() ??
        'D${DateTime.now().millisecondsSinceEpoch % 100000}',
  );
  final name = TextEditingController(
    text: warehouse?['name']?.toString() ?? '',
  );
  final city = TextEditingController(
    text: warehouse?['city']?.toString() ?? '',
  );
  final district = TextEditingController(
    text: warehouse?['district']?.toString() ?? '',
  );
  final address = TextEditingController(
    text: warehouse?['address']?.toString() ?? '',
  );
  var isDefault = warehouse?['is_default'] == true;
  var isActive = warehouse?['is_active'] != false;

  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: FinkitColors.canvas,
    builder: (_) => _EntrySheet(
      title: warehouse == null ? 'Yeni Depo' : 'Depo Düzenle',
      subtitle: 'Stok giriş çıkışları depo bazında izlenir.',
      saveLabel: warehouse == null ? 'Depoyu Kaydet' : 'Değişiklikleri Kaydet',
      onSave: () async {
        if (warehouse == null) {
          await api.createWarehouse(
            code: code.text.trim(),
            name: name.text.trim(),
            city: _nullIfEmpty(city.text),
            district: _nullIfEmpty(district.text),
            address: _nullIfEmpty(address.text),
            isDefault: isDefault,
          );
        } else {
          await api.updateWarehouse((warehouse['id'] as num).toInt(), {
            'code': code.text.trim(),
            'name': name.text.trim(),
            'city': _nullIfEmpty(city.text),
            'district': _nullIfEmpty(district.text),
            'address': _nullIfEmpty(address.text),
            'is_default': isDefault,
            'is_active': isActive,
          });
        }
      },
      buildFields: (refresh) => [
        TextFormField(
          textInputAction: TextInputAction.next,
          controller: name,
          decoration: const InputDecoration(
            labelText: 'Depo Adı',
            prefixIcon: Icon(Icons.warehouse_outlined),
          ),
          validator: (value) => _requiredText(value, 'Depo adı gerekli'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          textInputAction: TextInputAction.next,
          controller: code,
          decoration: const InputDecoration(
            labelText: 'Depo Kodu',
            prefixIcon: Icon(Icons.tag_rounded),
          ),
          validator: (value) => _requiredText(value, 'Kod gerekli'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          textInputAction: TextInputAction.next,
          controller: city,
          decoration: const InputDecoration(
            labelText: 'Şehir (opsiyonel)',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          textInputAction: TextInputAction.next,
          controller: district,
          decoration: const InputDecoration(labelText: 'İlçe'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: address,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Adres'),
        ),
        const SizedBox(height: 6),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: isDefault,
          onChanged: (value) => refresh(() => isDefault = value),
          title: const Text('Varsayılan depo'),
        ),
        if (warehouse != null)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: isActive,
            onChanged: (value) => refresh(() => isActive = value),
            title: const Text('Aktif'),
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
                textInputAction: TextInputAction.next,
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
                textInputAction: TextInputAction.next,
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
          textInputAction: TextInputAction.next,
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

/// Gelen (alış) faturası için çok kalemli taslak oluşturur ve ayrıntıyı açar.
Future<bool> showPurchaseInvoiceForm(
  BuildContext context,
  FinkitApi api,
) async {
  final id = await Navigator.of(context).push<int>(
    MaterialPageRoute(
      builder: (_) =>
          SalesInvoiceFormPage(api: api, initialType: 'ALIS', purchase: true),
    ),
  );
  if (id == null || !context.mounted) return false;
  await openInvoiceDetail(context, api, {'id': id}, purchase: true);
  return true;
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
                textInputAction: TextInputAction.next,
                controller: firstName,
                decoration: const InputDecoration(labelText: 'Ad'),
                validator: (value) => _requiredText(value, 'Ad gerekli'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                textInputAction: TextInputAction.next,
                controller: lastName,
                decoration: const InputDecoration(labelText: 'Soyad'),
                validator: (value) => _requiredText(value, 'Soyad gerekli'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          textInputAction: TextInputAction.next,
          controller: employeeNo,
          decoration: const InputDecoration(
            labelText: 'Sicil No',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          validator: (value) => _requiredText(value, 'Sicil no gerekli'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          textInputAction: TextInputAction.next,
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
                textInputAction: TextInputAction.next,
                controller: position,
                decoration: const InputDecoration(labelText: 'Görev'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                textInputAction: TextInputAction.next,
                controller: department,
                decoration: const InputDecoration(labelText: 'Departman'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          textInputAction: TextInputAction.next,
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
          textInputAction: TextInputAction.next,
          controller: phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Telefon (opsiyonel)',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          textInputAction: TextInputAction.next,
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
      subtitle: '${employee['first_name'] ?? ''} ${employee['last_name'] ?? ''}'
          .trim(),
      saveLabel: 'Avansı Kaydet',
      onSave: () async {
        await api.createEmployeeAdvance(
          employeeId: employeeId,
          amount: _number(amount.text),
        );
      },
      buildFields: (refresh) => [
        TextFormField(
          textInputAction: TextInputAction.next,
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
          textInputAction: TextInputAction.next,
          controller: serialNo,
          decoration: const InputDecoration(
            labelText: 'Seri No',
            prefixIcon: Icon(Icons.tag_rounded),
          ),
          validator: (value) => _requiredText(value, 'Seri no gerekli'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          textInputAction: TextInputAction.next,
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
          textInputAction: TextInputAction.next,
          controller: counterparty,
          decoration: InputDecoration(
            labelText: direction == 'IN' ? 'Keşideci' : 'Lehtar',
            prefixIcon: const Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          textInputAction: TextInputAction.next,
          controller: bankName,
          decoration: const InputDecoration(
            labelText: 'Banka (opsiyonel)',
            prefixIcon: Icon(Icons.account_balance_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          textInputAction: TextInputAction.next,
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

/// Kasa / banka hesabı oluşturur.
Future<bool> showFinancialAccountForm(
  BuildContext context,
  FinkitApi api,
) async {
  final name = TextEditingController();
  final bankName = TextEditingController();
  final branchName = TextEditingController();
  final iban = TextEditingController();
  final openingBalance = TextEditingController(text: '0');
  var type = 'CASH';
  var currency = 'TRY';

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
          branchName: _nullIfEmpty(branchName.text),
          iban: _nullIfEmpty(iban.text),
          currency: currency,
          openingBalance: _number(openingBalance.text),
        );
      },
      buildFields: (refresh) => [
        TextFormField(
          textInputAction: TextInputAction.next,
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
            textInputAction: TextInputAction.next,
            controller: bankName,
            decoration: const InputDecoration(
              labelText: 'Banka Adı',
              prefixIcon: Icon(Icons.account_balance_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            textInputAction: TextInputAction.next,
            controller: branchName,
            decoration: const InputDecoration(labelText: 'Şube Adı'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            textInputAction: TextInputAction.next,
            controller: iban,
            decoration: const InputDecoration(
              labelText: 'IBAN (opsiyonel)',
              prefixIcon: Icon(Icons.credit_card_outlined),
            ),
          ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: currency,
          decoration: const InputDecoration(labelText: 'Para Birimi'),
          items: const [
            DropdownMenuItem(value: 'TRY', child: Text('TRY')),
            DropdownMenuItem(value: 'USD', child: Text('USD')),
            DropdownMenuItem(value: 'EUR', child: Text('EUR')),
          ],
          onChanged: (value) => refresh(() => currency = value ?? 'TRY'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          textInputAction: TextInputAction.next,
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
Future<bool> showReminderRuleForm(
  BuildContext context,
  FinkitApi api, {
  Map<String, dynamic>? rule,
}) async {
  final daysBefore = TextEditingController(
    text: '${rule?['days_before'] ?? 3}',
  );
  final message = TextEditingController(
    text: rule?['message']?.toString() ?? '',
  );
  var channel = rule?['channel']?.toString() ?? 'sms';

  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: FinkitColors.canvas,
    builder: (_) => _EntrySheet(
      title: rule == null ? 'Yeni Hatırlatma Kuralı' : 'Kuralı Düzenle',
      subtitle: 'Vade tarihinden belirtilen gün önce hatırlatma gönderilir.',
      saveLabel: 'Kuralı Kaydet',
      onSave: () async {
        if (rule == null) {
          await api.createReminderRule(
            channel: channel,
            daysBefore: int.tryParse(daysBefore.text.trim()) ?? 3,
            message: _nullIfEmpty(message.text),
          );
        } else {
          await api.updateReminderRule(
            int.parse('${rule['id']}'),
            daysBefore: int.parse(daysBefore.text.trim()),
            message: message.text.trim(),
          );
        }
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
          onChanged: rule == null
              ? (value) => refresh(() => channel = value ?? channel)
              : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          textInputAction: TextInputAction.next,
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
          textInputAction: TextInputAction.next,
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

/// Müşavir için yeni mükellef kaydı oluşturur. Geçici şifre üretildiyse
/// çağırana döndürülür; böylece kullanıcıya iletilebilir.
Future<String?> showClientForm(BuildContext context, FinkitApi api) async {
  final companyTitle = TextEditingController();
  final fullName = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final taxNumber = TextEditingController();
  final tckn = TextEditingController();
  final monthlyFee = TextEditingController();
  final dueDay = TextEditingController(text: '1');
  final password = TextEditingController();
  var sendEmail = false;
  String? temporaryPassword;

  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: FinkitColors.canvas,
    builder: (_) => _EntrySheet(
      title: 'Yeni Mükellef',
      subtitle: 'Şifre boş bırakılırsa geçici şifre üretilir ve kayıt sonrası gösterilir.',
      saveLabel: 'Mükellefi Kaydet',
      onSave: () async {
        final result = await api.createClient(
          companyTitle: companyTitle.text.trim(),
          fullName: fullName.text.trim(),
          email: email.text.trim(),
          tckn: tckn.text.trim(),
          monthlyFee: _number(monthlyFee.text),
          paymentDueDay: int.tryParse(dueDay.text.trim()) ?? 1,
          phoneNumber: _nullIfEmpty(phone.text),
          taxNumber: _nullIfEmpty(taxNumber.text),
          password: _nullIfEmpty(password.text),
          sendCredentialsEmail: sendEmail,
        );
        temporaryPassword = result['temporary_password']?.toString();
      },
      buildFields: (refresh) => [
        TextFormField(
          textInputAction: TextInputAction.next,
          controller: companyTitle,
          decoration: const InputDecoration(
            labelText: 'Firma Ünvanı',
            prefixIcon: Icon(Icons.business_outlined),
          ),
          validator: (value) => _requiredText(value, 'Ünvan gerekli'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          textInputAction: TextInputAction.next,
          controller: fullName,
          decoration: const InputDecoration(
            labelText: 'Yetkili Ad Soyad',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
          validator: (value) => _requiredText(value, 'Ad soyad gerekli'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          textInputAction: TextInputAction.next,
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'E-posta (giriş)',
            prefixIcon: Icon(Icons.mail_outline_rounded),
          ),
          validator: (value) {
            final text = (value ?? '').trim();
            if (!text.contains('@') || text.length < 5) {
              return 'Geçerli e-posta girin';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          textInputAction: TextInputAction.next,
          controller: tckn,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'TCKN (11 hane)',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          validator: (value) {
            final text = (value ?? '').trim();
            if (!RegExp(r'^\d{11}$').hasMatch(text)) {
              return 'TCKN 11 haneli olmalı';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                textInputAction: TextInputAction.next,
                controller: taxNumber,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Vergi No'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                textInputAction: TextInputAction.next,
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefon'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                textInputAction: TextInputAction.next,
                controller: monthlyFee,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Aylık Ücret'),
                validator: (value) =>
                    _number(value ?? '') < 0 ? 'Ücret girin' : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                textInputAction: TextInputAction.next,
                controller: dueDay,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ödeme Günü'),
                validator: (value) {
                  final parsed = int.tryParse((value ?? '').trim());
                  if (parsed == null || parsed < 1 || parsed > 31) {
                    return '1-31 arası';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          textInputAction: TextInputAction.next,
          controller: password,
          decoration: const InputDecoration(
            labelText: 'Şifre (opsiyonel)',
            prefixIcon: Icon(Icons.lock_outline_rounded),
          ),
        ),
        const SizedBox(height: 6),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: sendEmail,
          onChanged: (value) => refresh(() => sendEmail = value),
          title: const Text('Giriş bilgilerini e-posta ile gönder'),
        ),
      ],
    ),
  );

  if (created == true && temporaryPassword != null && context.mounted) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Geçici şifre'),
        content: Text(
          'Mükellefe iletmeniz gereken geçici şifre:\n\n$temporaryPassword',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
  return created == true ? temporaryPassword : null;
}

/// Mükellef kartını düzenler (müşavir).
Future<bool> showClientEditForm(
  BuildContext context,
  FinkitApi api, {
  required int clientId,
  required String companyTitle,
  required String fullName,
  required String phoneNumber,
  required String taxNumber,
  required double monthlyFee,
  required int paymentDueDay,
}) async {
  final company = TextEditingController(text: companyTitle);
  final name = TextEditingController(text: fullName);
  final phone = TextEditingController(text: phoneNumber);
  final tax = TextEditingController(text: taxNumber);
  final fee = TextEditingController(text: monthlyFee.toStringAsFixed(2));
  final dueDay = TextEditingController(text: '$paymentDueDay');

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: FinkitColors.canvas,
    builder: (_) => _EntrySheet(
      title: 'Mükellef Kartını Düzenle',
      subtitle: 'Ünvan, iletişim ve ücret bilgileri güncellenir.',
      saveLabel: 'Değişiklikleri Kaydet',
      onSave: () async {
        await api.updateClient(
          clientId,
          companyTitle: company.text.trim(),
          fullName: name.text.trim(),
          phoneNumber: _nullIfEmpty(phone.text),
          taxNumber: _nullIfEmpty(tax.text),
          monthlyFee: _number(fee.text),
          paymentDueDay: int.tryParse(dueDay.text.trim()) ?? paymentDueDay,
        );
      },
      buildFields: (refresh) => [
        TextFormField(
          textInputAction: TextInputAction.next,
          controller: company,
          decoration: const InputDecoration(
            labelText: 'Firma Ünvanı',
            prefixIcon: Icon(Icons.business_outlined),
          ),
          validator: (value) => _requiredText(value, 'Ünvan gerekli'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          textInputAction: TextInputAction.next,
          controller: name,
          decoration: const InputDecoration(
            labelText: 'Yetkili Ad Soyad',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
          validator: (value) => _requiredText(value, 'Ad soyad gerekli'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                textInputAction: TextInputAction.next,
                controller: tax,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Vergi No'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                textInputAction: TextInputAction.next,
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefon'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                textInputAction: TextInputAction.next,
                controller: fee,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Aylık Ücret'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                textInputAction: TextInputAction.next,
                controller: dueDay,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ödeme Günü'),
                validator: (value) {
                  final parsed = int.tryParse((value ?? '').trim());
                  if (parsed == null || parsed < 1 || parsed > 31) {
                    return '1-31 arası';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return saved ?? false;
}
