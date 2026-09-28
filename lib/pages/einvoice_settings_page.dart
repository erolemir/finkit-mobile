import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';

class EInvoiceSettingsPage extends StatefulWidget {
  const EInvoiceSettingsPage({
    super.key,
    required this.api,
    required this.isClient,
  });

  final FinkitApi api;
  final bool isClient;

  @override
  State<EInvoiceSettingsPage> createState() => _EInvoiceSettingsPageState();
}

class _EInvoiceSettingsPageState extends State<EInvoiceSettingsPage> {
  final _fields = <String, TextEditingController>{};
  Map<String, dynamic>? _account;
  late Future<void> _loading;
  bool _busy = false;
  String? _error;
  String _environment = 'PRODUCTION';
  String _profile = 'TICARIFATURA';

  static const _fieldLabels = <String, String>{
    'izibiz_username': 'İzibiz kullanıcı adı',
    'izibiz_password': 'İzibiz şifresi',
    'sender_identifier': 'Gönderici VKN / TCKN',
    'sender_name': 'Gönderici ünvanı',
    'sender_tax_office': 'Vergi dairesi',
    'sender_street': 'Adres',
    'sender_building_no': 'Bina no',
    'sender_district': 'İlçe',
    'sender_city': 'İl',
    'sender_postal_code': 'Posta kodu',
    'sender_email': 'E-posta',
    'sender_phone': 'Telefon',
    'sender_mersis_no': 'MERSİS no',
    'sender_trade_registry_no': 'Ticaret sicil no',
    'einvoice_serie': 'E-Fatura serisi',
    'einvoice_series': 'Ek E-Fatura kodları (virgülle ayırın)',
    'einvoice_last_document_no': 'Son E-Fatura no',
    'earchive_serie': 'E-Arşiv serisi',
    'earchive_series': 'Ek E-Arşiv kodları (virgülle ayırın)',
    'earchive_last_document_no': 'Son E-Arşiv no',
    'despatch_serie': 'E-İrsaliye serisi',
    'esmm_serie': 'E-SMM serisi',
    'mm_serie': 'E-Müstahsil serisi',
  };

  @override
  void initState() {
    super.initState();
    for (final key in _fieldLabels.keys) {
      _fields[key] = TextEditingController();
    }
    _loading = _load();
  }

  Future<void> _load() async {
    final result = await widget.api.electronicInvoiceAccount(
      isClient: widget.isClient,
    );
    if (!mounted) return;
    final account = result['account'];
    _account = account is Map ? Map<String, dynamic>.from(account) : null;
    for (final entry in _fields.entries) {
      if (entry.key != 'izibiz_password') {
        final saved = _account?[entry.key];
        entry.value.text = saved is List
            ? saved
                  .map((code) => '$code')
                  .where(
                    (code) =>
                        code !=
                        _account?[entry.key.replaceFirst('_series', '_serie')],
                  )
                  .join(', ')
            : '${saved ?? ''}';
      }
    }
    _environment = '${_account?['environment'] ?? 'PRODUCTION'}';
    _profile = '${_account?['default_einvoice_profile'] ?? 'TICARIFATURA'}';
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _value(String key) => _fields[key]!.text.trim();

  List<String> _series(String kind) => {
    if (_value('${kind}_serie').isNotEmpty)
      _value('${kind}_serie').toUpperCase(),
    ..._value('${kind}_series')
        .split(RegExp(r'[\s,;]+'))
        .where((code) => code.isNotEmpty)
        .map((code) => code.toUpperCase()),
  }.toList();

  String? _validationError() {
    if (_value('izibiz_username').isEmpty)
      return 'İzibiz kullanıcı adı gerekli.';
    if (_account == null && _value('izibiz_password').isEmpty) {
      return 'İzibiz şifresi gerekli.';
    }
    if (!RegExp(r'^\d{10,11}$').hasMatch(_value('sender_identifier'))) {
      return 'VKN 10, TCKN 11 haneli olmalı.';
    }
    if (_value('sender_name').isEmpty) return 'Gönderici ünvanı gerekli.';
    for (final key in const [
      'einvoice_serie',
      'earchive_serie',
      'despatch_serie',
      'esmm_serie',
      'mm_serie',
    ]) {
      final value = _value(key).toUpperCase();
      if (value.isNotEmpty && !RegExp(r'^[A-Z]{3}$').hasMatch(value)) {
        return '${_fieldLabels[key]} üç harf olmalı.';
      }
    }
    for (final pair in const [
      ('einvoice_serie', 'einvoice_last_document_no'),
      ('earchive_serie', 'earchive_last_document_no'),
    ]) {
      final number = _value(pair.$2).toUpperCase();
      if (number.isNotEmpty &&
          (!RegExp(r'^[A-Z]{3}\d{13}$').hasMatch(number) ||
              number.substring(0, 3) != _value(pair.$1).toUpperCase())) {
        return '${_fieldLabels[pair.$2]} seriyle başlamalı ve 16 karakter olmalı.';
      }
    }
    final invoiceCodes = _series('einvoice');
    final archiveCodes = _series('earchive');
    if ([
      ...invoiceCodes,
      ...archiveCodes,
    ].any((code) => !RegExp(r'^[A-Z]{3}$').hasMatch(code))) {
      return 'Her ek belge kodu üç harf olmalı.';
    }
    if (invoiceCodes.any(archiveCodes.contains)) {
      return 'E-Fatura ve E-Arşiv kodları farklı olmalı.';
    }
    return null;
  }

  Future<void> _save() async {
    final validation = _validationError();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    final payload = <String, dynamic>{
      'izibiz_username': _value('izibiz_username'),
      if (_value('izibiz_password').isNotEmpty)
        'izibiz_password': _value('izibiz_password'),
      'environment': _environment,
      'sender_identifier': _value('sender_identifier'),
      'sender_name': _value('sender_name'),
      'default_einvoice_profile': _profile,
      for (final key in _fieldLabels.keys)
        if (!const {
          'izibiz_username',
          'izibiz_password',
          'sender_identifier',
          'sender_name',
          'einvoice_last_document_no',
          'earchive_last_document_no',
          'einvoice_series',
          'earchive_series',
        }.contains(key))
          key: _value(key).isEmpty
              ? null
              : key.endsWith('_serie')
              ? _value(key).toUpperCase()
              : _value(key),
    };
    payload['einvoice_series'] = _series('einvoice');
    payload['earchive_series'] = _series('earchive');
    for (final key in const [
      'einvoice_last_document_no',
      'earchive_last_document_no',
    ]) {
      final current = '${_account?[key] ?? ''}';
      if (_value(key).toUpperCase() != current) {
        payload[key] = _value(key).isEmpty ? null : _value(key).toUpperCase();
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.saveElectronicInvoiceAccount(
        payload,
        isClient: widget.isClient,
      );
      if (!mounted) return;
      final account = result['account'];
      if (account is Map) _account = Map<String, dynamic>.from(account);
      _fields['izibiz_password']!.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-Belge hesabı kaydedildi.')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.verifyElectronicInvoiceAccount(
        isClient: widget.isClient,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result['message'] ?? (result['ok'] == true ? 'Bağlantı başarılı.' : 'Bağlantı kurulamadı.')}',
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setTestAccount(bool active) async {
    if (!active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Test modundan çık'),
          content: const Text(
            'Test hesabını devreden çıkarıp normal moda dönmek istiyor musunuz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Normal moda dön'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.setElectronicInvoiceTestAccount(active);
      if (!mounted) return;
      final account = result['account'];
      setState(() {
        _account = account is Map ? Map<String, dynamic>.from(account) : null;
        if (_account != null) {
          for (final entry in _fields.entries) {
            if (entry.key != 'izibiz_password') {
              entry.value.text = '${_account?[entry.key] ?? ''}';
            }
          }
          _environment = '${_account?['environment'] ?? 'TEST'}';
          _profile =
              '${_account?['default_einvoice_profile'] ?? 'TICARIFATURA'}';
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            active ? 'Test hesabı açıldı.' : 'Test hesabı kapatıldı.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String key) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: _fields[key],
      obscureText: key == 'izibiz_password',
      decoration: InputDecoration(
        labelText: _fieldLabels[key],
        hintText: key == 'izibiz_password' && _account != null
            ? 'Değiştirmek için yazın'
            : null,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fatura Ayarları')),
    body: FutureBuilder<void>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: LoadingState());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => _loading = _load()),
              child: Text('Hesap alınamadı: ${snapshot.error}'),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const PageTitle(
              title: 'İzibiz Hesap Ayarları',
              subtitle: 'E-Fatura ve E-Arşiv gönderim bilgileri',
            ),
            if (!widget.isClient && _account == null)
              OutlinedButton(
                onPressed: _busy ? null : () => _setTestAccount(true),
                child: const Text('Test Hesabını Aktifleştir'),
              ),
            if (!widget.isClient && _account?['is_test_bypass'] == true)
              OutlinedButton(
                onPressed: _busy ? null : () => _setTestAccount(false),
                child: const Text('Test Modundan Çık'),
              ),
            const SectionHeader(title: 'Bağlantı'),
            _field('izibiz_username'),
            _field('izibiz_password'),
            DropdownButtonFormField<String>(
              initialValue: _environment,
              decoration: const InputDecoration(labelText: 'Ortam'),
              items: const [
                DropdownMenuItem(value: 'PRODUCTION', child: Text('Canlı')),
                DropdownMenuItem(value: 'TEST', child: Text('Test')),
              ],
              onChanged: (value) =>
                  setState(() => _environment = value ?? _environment),
            ),
            const SizedBox(height: 16),
            const SectionHeader(title: 'Gönderici'),
            for (final key in const [
              'sender_identifier',
              'sender_name',
              'sender_tax_office',
              'sender_street',
              'sender_building_no',
              'sender_district',
              'sender_city',
              'sender_postal_code',
              'sender_email',
              'sender_phone',
              'sender_mersis_no',
              'sender_trade_registry_no',
            ])
              _field(key),
            const SectionHeader(title: 'Seri ve Numaralandırma'),
            for (final key in const [
              'einvoice_serie',
              'einvoice_series',
              'einvoice_last_document_no',
              'earchive_serie',
              'earchive_series',
              'earchive_last_document_no',
              'despatch_serie',
              'esmm_serie',
              'mm_serie',
            ])
              _field(key),
            DropdownButtonFormField<String>(
              initialValue: _profile,
              decoration: const InputDecoration(
                labelText: 'Varsayılan E-Fatura profili',
              ),
              items: const [
                DropdownMenuItem(value: 'TICARIFATURA', child: Text('Ticari')),
                DropdownMenuItem(value: 'TEMELFATURA', child: Text('Temel')),
              ],
              onChanged: (value) =>
                  setState(() => _profile = value ?? _profile),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'İşleniyor…' : 'Kaydet'),
            ),
            OutlinedButton(
              onPressed: _busy || _account == null ? null : _verify,
              child: const Text('Bağlantıyı Doğrula'),
            ),
          ],
        );
      },
    ),
  );
}
