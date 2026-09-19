import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_client.dart';
import '../data/turkey_locations.dart';
import '../theme.dart';
import '../widgets.dart';
import 'form_layout.dart';

/// Mobil "Yeni Cari Oluştur" ekranını açar. Kayıt oluşturulduysa `true` döner.
Future<bool> showPartnerCreatePage(
  BuildContext context,
  FinkitApi api, {
  String defaultType = 'CUSTOMER',
}) async {
  final created = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => PartnerFormPage(api: api, defaultType: defaultType),
    ),
  );
  return created ?? false;
}

class _Option {
  const _Option(this.value, this.label);

  final String value;
  final String label;
}

const _currencies = <_Option>[
  _Option('TRY', 'Türk Lirası'),
  _Option('USD', 'ABD Doları'),
  _Option('EUR', 'Euro'),
  _Option('GBP', 'İngiliz Sterlini'),
];

const _addressTypes = <_Option>[
  _Option('CARI', 'Cari Adresi'),
  _Option('INVOICE', 'Fatura Adresi'),
  _Option('SHIPPING', 'Sevk Adresi'),
  _Option('OTHER', 'Diğer'),
];

const _countries = <String>[
  'Türkiye',
  'Almanya',
  'Amerika Birleşik Devletleri',
  'Azerbaycan',
  'Fransa',
  'Hollanda',
  'İngiltere',
  'İtalya',
  'Katar',
  'Rusya',
  'Suudi Arabistan',
  'Türkmenistan',
  'Yunanistan',
  'Diğer',
];

const _countryCodes = <String>[
  '+90',
  '+1',
  '+44',
  '+49',
  '+33',
  '+31',
  '+7',
  '+994',
  '+966',
  '+971',
  '+974',
  '+965',
  '+973',
  '+968',
  '+20',
];

String _formatPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  final trimmed = digits.length > 10 ? digits.substring(0, 10) : digits;
  final buffer = StringBuffer();
  for (var index = 0; index < trimmed.length; index++) {
    if (index == 3 || index == 6 || index == 8) buffer.write(' ');
    buffer.write(trimmed[index]);
  }
  return buffer.toString();
}

String? _composePhone(String countryCode, String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  return '$countryCode ${_formatPhone(digits)}';
}

String? _nullIfEmpty(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
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

String _formatDateTime(DateTime value) {
  String two(int input) => input.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}.${value.year} '
      '${two(value.hour)}:${two(value.minute)}';
}

String _dateValue(DateTime value) {
  String two(int input) => input.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
}

class _AddressDraft {
  _AddressDraft({required int index, this.isDefault = false})
    : title = TextEditingController(text: 'Adres ${index + 1}');

  final TextEditingController title;
  String type = 'CARI';
  bool isDefault;
  final TextEditingController email = TextEditingController();
  String countryCode = '+90';
  final TextEditingController phone = TextEditingController();
  String country = 'Türkiye';
  String city = '';
  final TextEditingController district = TextEditingController();
  final TextEditingController address = TextEditingController();

  void dispose() {
    title.dispose();
    email.dispose();
    phone.dispose();
    district.dispose();
    address.dispose();
  }
}

class _ContactDraft {
  final TextEditingController fullName = TextEditingController();
  final TextEditingController email = TextEditingController();
  String countryCode = '+90';
  final TextEditingController phone = TextEditingController();

  bool get isEmpty =>
      fullName.text.trim().isEmpty &&
      email.text.trim().isEmpty &&
      phone.text.trim().isEmpty;

  void dispose() {
    fullName.dispose();
    email.dispose();
    phone.dispose();
  }
}

class _IbanDraft {
  final TextEditingController iban = TextEditingController();
  final TextEditingController bankName = TextEditingController();

  void dispose() {
    iban.dispose();
    bankName.dispose();
  }
}

class _BalanceDraft {
  _BalanceDraft({required this.isDefault});

  final TextEditingController amount = TextEditingController(text: '0.00');
  String currency = 'TRY';
  DateTime openingDate = DateTime.now();
  String direction = 'DEBIT';
  bool isDefault;

  void dispose() => amount.dispose();
}

/// Cari kartı oluşturma formu: cari bilgileri, adres(ler), e-dönüşüm kutusu,
/// yetkili bilgileri, IBAN ve açılış bakiyesi alanlarını içerir.
class PartnerFormPage extends StatefulWidget {
  const PartnerFormPage({
    super.key,
    required this.api,
    this.defaultType = 'CUSTOMER',
  });

  final FinkitApi api;
  final String defaultType;

  @override
  State<PartnerFormPage> createState() => _PartnerFormPageState();
}

class _PartnerFormPageState extends State<PartnerFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _surname = TextEditingController();
  final _taxNumber = TextEditingController();
  final _taxOffice = TextEditingController();
  final _termDays = TextEditingController(text: '30');
  final _addresses = <_AddressDraft>[];
  final _contacts = <_ContactDraft>[];
  final _ibans = <_IbanDraft>[];
  final _balances = <_BalanceDraft>[];

  late bool _isCustomer;
  late bool _isSupplier;
  bool _eTransformation = false;
  int _activeAddress = 0;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isCustomer = widget.defaultType != 'SUPPLIER';
    _isSupplier = widget.defaultType == 'SUPPLIER';
    _code.text = _suggestCode(widget.defaultType);
    _addresses.add(_AddressDraft(index: 0, isDefault: true));
    _contacts.add(_ContactDraft());
    _ibans.add(_IbanDraft());
    _balances.add(_BalanceDraft(isDefault: true));
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _surname.dispose();
    _taxNumber.dispose();
    _taxOffice.dispose();
    _termDays.dispose();
    for (final row in _addresses) {
      row.dispose();
    }
    for (final row in _contacts) {
      row.dispose();
    }
    for (final row in _ibans) {
      row.dispose();
    }
    for (final row in _balances) {
      row.dispose();
    }
    super.dispose();
  }

  int get _addressIndex {
    if (_activeAddress < 0) return 0;
    if (_activeAddress > _addresses.length - 1) return _addresses.length - 1;
    return _activeAddress;
  }

  _AddressDraft get _currentAddress => _addresses[_addressIndex];

  void _addAddress() {
    setState(() {
      _addresses.add(_AddressDraft(index: _addresses.length));
      _activeAddress = _addresses.length - 1;
    });
  }

  void _removeAddress() {
    if (_addresses.length <= 1) return;
    setState(() {
      final removed = _addresses.removeAt(_activeAddress);
      removed.dispose();
      if (!_addresses.any((row) => row.isDefault)) {
        _addresses.first.isDefault = true;
      }
      if (_activeAddress > _addresses.length - 1) {
        _activeAddress = _addresses.length - 1;
      }
    });
  }

  void _markDefaultAddress() {
    setState(() {
      for (var index = 0; index < _addresses.length; index++) {
        _addresses[index].isDefault = index == _activeAddress;
      }
    });
  }

  String? _validate() {
    if (_code.text.trim().isEmpty) return 'Cari kodu zorunludur.';
    if (_name.text.trim().length < 2) {
      return 'Ad / Ünvan en az 2 karakter olmalıdır.';
    }
    if (!_isCustomer && !_isSupplier) {
      return 'Cari tipi seçin: Müşteri ve/veya Tedarikçi.';
    }
    final tax = _taxNumber.text.trim();
    if (tax.isNotEmpty && !RegExp(r'^\d{10,11}$').hasMatch(tax)) {
      return 'VKN 10, TCKN 11 haneli rakam olmalıdır.';
    }
    for (final row in _ibans) {
      final value = row.iban.text.replaceAll(' ', '').toUpperCase();
      if (value.isEmpty) continue;
      if (!RegExp(r'^TR\d{24}$').hasMatch(value)) {
        return 'IBAN TR ile başlamalı ve 26 karakter olmalıdır.';
      }
    }
    return null;
  }

  Future<void> _pickOpeningDate(_BalanceDraft row) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: row.openingDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(row.openingDate),
    );
    if (!mounted) return;
    setState(() {
      row.openingDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time?.hour ?? row.openingDate.hour,
        time?.minute ?? row.openingDate.minute,
      );
    });
  }

  Map<String, dynamic> _buildPayload() {
    final primary = _addresses.firstWhere(
      (row) => row.isDefault,
      orElse: () => _addresses.first,
    );
    final contacts = _contacts.where((row) => !row.isEmpty).toList();
    final ibans = _ibans
        .where((row) => row.iban.text.trim().isNotEmpty)
        .toList();
    final balances = _balances
        .where(
          (row) =>
              (double.tryParse(row.amount.text.replaceAll(',', '.')) ?? 0) > 0,
        )
        .toList();

    return <String, dynamic>{
      'code': _code.text.trim(),
      'name': _name.text.trim(),
      'surname': _nullIfEmpty(_surname.text),
      'partner_type': _isCustomer && _isSupplier
          ? 'BOTH'
          : (_isCustomer ? 'CUSTOMER' : 'SUPPLIER'),
      'tax_number': _nullIfEmpty(_taxNumber.text),
      'tax_office': _nullIfEmpty(_taxOffice.text),
      'email': _nullIfEmpty(primary.email.text),
      'phone': _composePhone(primary.countryCode, primary.phone.text),
      'country': primary.country,
      'city': _nullIfEmpty(primary.city),
      'district': _nullIfEmpty(primary.district.text),
      'address': _nullIfEmpty(primary.address.text),
      'currency': balances.isEmpty ? 'TRY' : balances.first.currency,
      'payment_term_days': int.tryParse(_termDays.text.trim()) ?? 0,
      'e_transformation_enabled': _eTransformation,
      'addresses': <Map<String, dynamic>>[
        for (var index = 0; index < _addresses.length; index++)
          <String, dynamic>{
            'title': _addresses[index].title.text.trim().isEmpty
                ? 'Adres ${index + 1}'
                : _addresses[index].title.text.trim(),
            'address_type': _addresses[index].type,
            'is_default': _addresses[index].isDefault,
            'email': _nullIfEmpty(_addresses[index].email.text),
            'phone': _composePhone(
              _addresses[index].countryCode,
              _addresses[index].phone.text,
            ),
            'country': _addresses[index].country,
            'city': _nullIfEmpty(_addresses[index].city),
            'district': _nullIfEmpty(_addresses[index].district.text),
            'address': _nullIfEmpty(_addresses[index].address.text),
            'sort_order': index,
          },
      ],
      'contacts': <Map<String, dynamic>>[
        for (var index = 0; index < contacts.length; index++)
          <String, dynamic>{
            'full_name': _nullIfEmpty(contacts[index].fullName.text),
            'email': _nullIfEmpty(contacts[index].email.text),
            'phone': _composePhone(
              contacts[index].countryCode,
              contacts[index].phone.text,
            ),
            'is_primary': index == 0,
            'sort_order': index,
          },
      ],
      'bank_accounts': <Map<String, dynamic>>[
        for (var index = 0; index < ibans.length; index++)
          <String, dynamic>{
            'iban': ibans[index].iban.text.replaceAll(' ', '').toUpperCase(),
            'bank_name': _nullIfEmpty(ibans[index].bankName.text),
            'currency': 'TRY',
            'is_default': index == 0,
            'sort_order': index,
          },
      ],
      'opening_balances': <Map<String, dynamic>>[
        for (var index = 0; index < balances.length; index++)
          <String, dynamic>{
            'amount':
                (double.tryParse(
                          balances[index].amount.text.replaceAll(',', '.'),
                        ) ??
                        0)
                    .toStringAsFixed(2),
            'currency': balances[index].currency,
            'direction': balances[index].direction,
            'opening_date': _dateValue(balances[index].openingDate),
            'is_default': balances[index].isDefault,
            'sort_order': index,
          },
      ],
    };
  }

  Future<void> _save() async {
    if (_saving || !validateAndReveal(_formKey)) return;
    final validationError = _validate();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.createPartnerRecord(_buildPayload());
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = exception.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final address = _currentAddress;
    final districts = turkeyDistricts[address.city] ?? const <String>[];

    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('Yeni Cari Oluştur')),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          children: [
            _FormSection(
              title: 'Cari Bilgileri',
              children: [
                Text(
                  'Cari Tipi',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  children: [
                    FilterChip(
                      label: const Text('Müşteri'),
                      selected: _isCustomer,
                      onSelected: (value) =>
                          setState(() => _isCustomer = value),
                    ),
                    FilterChip(
                      label: const Text('Tedarikçi'),
                      selected: _isSupplier,
                      onSelected: (value) =>
                          setState(() => _isSupplier = value),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _code,
                  decoration: const InputDecoration(
                    labelText: 'Cari Kodu',
                    prefixIcon: Icon(Icons.tag_rounded),
                  ),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Cari kodu zorunlu' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _taxNumber,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'VKN / TCKN',
                    prefixIcon: Icon(Icons.numbers_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Ad / Ünvan',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) => (value ?? '').trim().length < 2
                      ? 'En az 2 karakter girin'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _surname,
                  decoration: const InputDecoration(
                    labelText: 'Soyad',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _taxOffice,
                  decoration: const InputDecoration(
                    labelText: 'Vergi Dairesi',
                    hintText: 'Vergi Dairesi Seçiniz',
                    prefixIcon: Icon(Icons.account_balance_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _termDays,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Ödeme Vadesi (gün)',
                    prefixIcon: Icon(Icons.event_available_outlined),
                  ),
                ),
              ],
            ),
            _FormSection(
              title: 'Adres Bilgileri',
              action: TextButton.icon(
                onPressed: _addAddress,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Yeni Adres',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: _activeAddress == 0
                          ? null
                          : () => setState(() => _activeAddress -= 1),
                      icon: const Icon(Icons.chevron_left_rounded),
                      tooltip: 'Önceki adres',
                    ),
                    Text(
                      'Adres ${_addressIndex + 1} / ${_addresses.length}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      onPressed: _activeAddress >= _addresses.length - 1
                          ? null
                          : () => setState(() => _activeAddress += 1),
                      icon: const Icon(Icons.chevron_right_rounded),
                      tooltip: 'Sonraki adres',
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _addresses.length > 1 ? _removeAddress : null,
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: FinkitColors.danger,
                      tooltip: 'Adresi sil',
                    ),
                  ],
                ),
                KeyedSubtree(
                  key: ValueKey('address-form-$_addressIndex'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: address.type,
                        decoration: const InputDecoration(
                          labelText: 'Adres Tipi',
                        ),
                        items: [
                          for (final option in _addressTypes)
                            DropdownMenuItem(
                              value: option.value,
                              child: Text(option.label),
                            ),
                        ],
                        onChanged: (value) => setState(
                          () => address.type = value ?? address.type,
                        ),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: address.isDefault,
                        title: const Text(
                          'Varsayılan Cari Adresi',
                          style: TextStyle(fontSize: 13.5),
                        ),
                        onChanged: (_) => _markDefaultAddress(),
                      ),
                      TextFormField(
                        controller: address.title,
                        decoration: const InputDecoration(
                          labelText: 'Adres Başlığı',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: address.email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'e-Posta',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PhoneField(
                        key: ValueKey('address-phone-$_addressIndex'),
                        countryCode: address.countryCode,
                        controller: address.phone,
                        onCountryCodeChanged: (value) =>
                            setState(() => address.countryCode = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: address.country,
                        decoration: const InputDecoration(labelText: 'Ülke'),
                        items: [
                          for (final country in _countries)
                            DropdownMenuItem(
                              value: country,
                              child: Text(country),
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          address.country = value ?? address.country;
                          address.city = '';
                          address.district.clear();
                        }),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: address.city.isEmpty
                            ? null
                            : address.city,
                        decoration: const InputDecoration(labelText: 'İl'),
                        items: [
                          for (final province in turkeyProvinces)
                            DropdownMenuItem(
                              value: province,
                              child: Text(province),
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          address.city = value ?? '';
                          address.district.clear();
                        }),
                      ),
                      const SizedBox(height: 12),
                      if (districts.isEmpty)
                        TextFormField(
                          controller: address.district,
                          decoration: const InputDecoration(labelText: 'İlçe'),
                        )
                      else
                        DropdownButtonFormField<String>(
                          initialValue:
                              districts.contains(address.district.text)
                              ? address.district.text
                              : null,
                          decoration: const InputDecoration(labelText: 'İlçe'),
                          items: [
                            for (final district in districts)
                              DropdownMenuItem(
                                value: district,
                                child: Text(district),
                              ),
                          ],
                          onChanged: (value) => setState(
                            () => address.district.text = value ?? '',
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: address.address,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Adres',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _FormSection(
              title: 'e-Dönüşüm',
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _eTransformation,
                  title: const Text(
                    'e-Dönüşüm posta kutusu bilgileri tanımla',
                    style: TextStyle(fontSize: 13.5),
                  ),
                  onChanged: (value) =>
                      setState(() => _eTransformation = value ?? false),
                ),
              ],
            ),
            _FormSection(
              title: 'Yetkili Bilgileri',
              action: _CircleAddButton(
                tooltip: 'Yetkili ekle',
                onPressed: () => setState(() => _contacts.add(_ContactDraft())),
              ),
              children: [
                for (var index = 0; index < _contacts.length; index++) ...[
                  if (index > 0) const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _contacts[index].fullName,
                          decoration: const InputDecoration(
                            labelText: 'Ad-Soyad',
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _contacts.length > 1
                            ? () => setState(() {
                                _contacts.removeAt(index).dispose();
                              })
                            : null,
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: FinkitColors.danger,
                        tooltip: 'Yetkiliyi sil',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _contacts[index].email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'e-Posta',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PhoneField(
                    countryCode: _contacts[index].countryCode,
                    controller: _contacts[index].phone,
                    onCountryCodeChanged: (value) =>
                        setState(() => _contacts[index].countryCode = value),
                  ),
                ],
              ],
            ),
            _FormSection(
              title: 'IBAN',
              action: _CircleAddButton(
                tooltip: 'IBAN ekle',
                onPressed: () => setState(() => _ibans.add(_IbanDraft())),
              ),
              children: [
                for (var index = 0; index < _ibans.length; index++) ...[
                  if (index > 0) const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _ibans[index].iban,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'IBAN',
                            hintText: 'TR00 0000 0000 0000 0000 0000 00',
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _ibans.length > 1
                            ? () => setState(() {
                                _ibans.removeAt(index).dispose();
                              })
                            : null,
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: FinkitColors.danger,
                        tooltip: 'IBAN sil',
                      ),
                    ],
                  ),
                ],
              ],
            ),
            _FormSection(
              title: 'Bakiye Bilgileri',
              action: _CircleAddButton(
                tooltip: 'Bakiye ekle',
                onPressed: () => setState(
                  () => _balances.add(_BalanceDraft(isDefault: false)),
                ),
              ),
              children: [
                for (var index = 0; index < _balances.length; index++) ...[
                  if (index > 0) const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: _balances[index].isDefault,
                          title: const Text(
                            'Varsayılan Yap',
                            style: TextStyle(fontSize: 13.5),
                          ),
                          onChanged: (value) => setState(() {
                            for (var row = 0; row < _balances.length; row++) {
                              _balances[row].isDefault = row == index
                                  ? (value ?? false)
                                  : false;
                            }
                          }),
                        ),
                      ),
                      IconButton(
                        onPressed: _balances.length > 1
                            ? () => setState(() {
                                _balances.removeAt(index).dispose();
                              })
                            : null,
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: FinkitColors.danger,
                        tooltip: 'Bakiyeyi sil',
                      ),
                    ],
                  ),
                  TextFormField(
                    controller: _balances[index].amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Açılış Bakiyesi',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _balances[index].currency,
                    decoration: const InputDecoration(labelText: 'Para Birimi'),
                    items: [
                      for (final currency in _currencies)
                        DropdownMenuItem(
                          value: currency.value,
                          child: Text(currency.label),
                        ),
                    ],
                    onChanged: (value) => setState(
                      () => _balances[index].currency = value ?? 'TRY',
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _pickOpeningDate(_balances[index]),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Açılış Tarihi',
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDateTime(_balances[index].openingDate)),
                          const Icon(
                            Icons.event_rounded,
                            size: 18,
                            color: FinkitColors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Bakiye Durumu',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'CREDIT', label: Text('Alacaklı')),
                      ButtonSegment(value: 'DEBIT', label: Text('Borçlu')),
                    ],
                    selected: {_balances[index].direction},
                    onSelectionChanged: (value) => setState(
                      () => _balances[index].direction = value.first,
                    ),
                  ),
                ],
              ],
            ),
            if (_error != null) _ErrorBanner(message: _error!),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Vazgeç'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text('Kaydediliyor'),
                        ],
                      )
                    : const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.children,
    this.action,
  });

  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: FinkitColors.primary),
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({
    super.key,
    required this.countryCode,
    required this.controller,
    required this.onCountryCodeChanged,
  });

  final String countryCode;
  final TextEditingController controller;
  final ValueChanged<String> onCountryCodeChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: DropdownButtonFormField<String>(
            initialValue: countryCode,
            decoration: const InputDecoration(labelText: 'Ülke Kodu'),
            items: [
              for (final code in _countryCodes)
                DropdownMenuItem(value: code, child: Text(code)),
            ],
            onChanged: (value) => onCountryCodeChanged(value ?? countryCode),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d ]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Telefon No',
              hintText: '5xx xxx xx xx',
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleAddButton extends StatelessWidget {
  const _CircleAddButton({required this.onPressed, required this.tooltip});

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: FinkitColors.success,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.add_rounded, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
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
