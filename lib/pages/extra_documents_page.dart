import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';
import 'electronic_invoice_page.dart';

const extraDocumentLabels = <String, String>{
  'despatches': 'E-İrsaliye',
  'esmm': 'E-SMM',
  'creditnotes': 'E-Müstahsil',
};

class ExtraDocumentsPage extends StatefulWidget {
  const ExtraDocumentsPage({super.key, required this.api});
  final FinkitApi api;

  @override
  State<ExtraDocumentsPage> createState() => _ExtraDocumentsPageState();
}

class _ExtraDocumentsPageState extends State<ExtraDocumentsPage> {
  String _kind = 'despatches';
  bool _incoming = false;
  String _status = '';
  String _search = '';
  int _page = 1;
  late Future<Map<String, dynamic>> _future;
  final _start = TextEditingController();
  final _end = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  void _reload() {
    _future = widget.api.extraDocuments(
      _kind,
      incoming: _incoming,
      status: _status,
      startDate: _start.text.trim(),
      endDate: _end.text.trim(),
      page: _page,
    );
  }

  void _change(String kind, bool incoming) => setState(() {
    _kind = kind;
    _incoming = incoming;
    _page = 1;
    _status = '';
    _reload();
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('E-İrsaliye, E-SMM ve Diğerleri')),
    body: RefreshIndicator(
      onRefresh: () async => setState(_reload),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PageTitle(
            title: 'Diğer E-Belgeler',
            subtitle: 'İrsaliye, serbest meslek ve müstahsil makbuzları',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in extraDocumentLabels.keys)
                ChoiceChip(
                  label: Text(extraDocumentLabels[kind]!),
                  selected: _kind == kind && !_incoming,
                  onSelected: (_) => _change(kind, false),
                ),
              ChoiceChip(
                label: const Text('Gelen E-İrsaliye'),
                selected: _incoming,
                onSelected: (_) => _change('despatches', true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_incoming)
            FilledButton.icon(
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        ExtraDocumentCreatePage(api: widget.api, kind: _kind),
                  ),
                );
                if (created == true && mounted) setState(_reload);
              },
              icon: const Icon(Icons.add),
              label: Text('Yeni ${extraDocumentLabels[_kind]}'),
            ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Müşteri, VKN veya belge no ara',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _search = value.toLowerCase()),
          ),
          if (!_incoming)
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Durum'),
              items: const [
                DropdownMenuItem(value: '', child: Text('Tüm Durumlar')),
                DropdownMenuItem(value: 'QUEUED', child: Text('Kuyrukta')),
                DropdownMenuItem(value: 'SENT', child: Text('Gönderildi')),
                DropdownMenuItem(value: 'DELIVERED', child: Text('Teslim')),
                DropdownMenuItem(value: 'CANCELLED', child: Text('İptal')),
                DropdownMenuItem(value: 'ERROR', child: Text('Hata')),
              ],
              onChanged: (value) => setState(() {
                _status = value ?? '';
                _page = 1;
                _reload();
              }),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _start,
                  decoration: const InputDecoration(
                    labelText: 'Başlangıç YYYY-AA-GG',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _end,
                  decoration: const InputDecoration(
                    labelText: 'Bitiş YYYY-AA-GG',
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Tarihleri uygula',
                onPressed: () => setState(() {
                  _page = 1;
                  _reload();
                }),
                icon: const Icon(Icons.filter_alt_outlined),
              ),
            ],
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData && !snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return TextButton(
                  onPressed: () => setState(_reload),
                  child: Text('Belgeler yüklenemedi: ${snapshot.error}'),
                );
              }
              final raw = snapshot.data?['items'];
              final items = raw is List
                  ? raw
                        .whereType<Map>()
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList()
                  : <Map<String, dynamic>>[];
              final filtered = items.where((item) {
                if (_search.isEmpty) return true;
                return [
                  item['customer_name'],
                  item['sender_name'],
                  item['customer_identifier'],
                  item['document_no'],
                  item['uuid'],
                ].any((value) => '$value'.toLowerCase().contains(_search));
              }).toList();
              if (filtered.isEmpty)
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Bu filtrede belge bulunamadı.'),
                );
              final total =
                  int.tryParse('${snapshot.data?['total']}') ?? items.length;
              return Column(
                children: [
                  for (final item in filtered)
                    Card(
                      child: ListTile(
                        title: Text(
                          '${item['document_no'] ?? item['invoice_number'] ?? item['uuid'] ?? 'Belge'}',
                        ),
                        subtitle: Text(
                          '${item['customer_name'] ?? item['sender_name'] ?? '—'} · ${item['status'] ?? item['statusDesc'] ?? '—'}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExtraDocumentDetailPage(
                                api: widget.api,
                                kind: _kind,
                                incoming: _incoming,
                                document: item,
                              ),
                            ),
                          );
                          if (mounted) setState(_reload);
                        },
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Önceki sayfa',
                        onPressed: _page <= 1
                            ? null
                            : () => setState(() {
                                _page--;
                                _reload();
                              }),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text('Sayfa $_page'),
                      IconButton(
                        tooltip: 'Sonraki sayfa',
                        onPressed:
                            items.length < 20 ||
                                (!_incoming && _page * 20 >= total)
                            ? null
                            : () => setState(() {
                                _page++;
                                _reload();
                              }),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

class ExtraDocumentDetailPage extends StatefulWidget {
  const ExtraDocumentDetailPage({
    super.key,
    required this.api,
    required this.kind,
    required this.incoming,
    required this.document,
  });
  final FinkitApi api;
  final String kind;
  final bool incoming;
  final Map<String, dynamic> document;

  @override
  State<ExtraDocumentDetailPage> createState() =>
      _ExtraDocumentDetailPageState();
}

class _ExtraDocumentDetailPageState extends State<ExtraDocumentDetailPage> {
  late Map<String, dynamic> _document = {...widget.document};
  bool _busy = false;

  String get _id =>
      '${widget.incoming ? _document['provider_id'] ?? _document['id'] : _document['uuid'] ?? ''}';

  Future<void> _action(bool cancel) async {
    if (_busy || _id.isEmpty) return;
    if (cancel) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Belgeyi İptal Et'),
          content: const Text('Belge için iptal isteği gönderilsin mi?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('İptal Et'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final result = cancel
          ? await widget.api.cancelExtraDocument(widget.kind, _id)
          : await widget.api.refreshExtraDocument(widget.kind, _id);
      if (mounted) setState(() => _document = {..._document, ...result});
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _content(String format) async {
    if (_busy || _id.isEmpty) return;
    setState(() => _busy = true);
    try {
      final bytes = await widget.api.extraDocumentContent(
        widget.kind,
        _id,
        format,
        incoming: widget.incoming,
      );
      if (!mounted) return;
      if (format == 'html') {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ElectronicDocumentPreview(
              loader: () async => utf8.decode(bytes),
            ),
          ),
        );
      } else {
        final name = '${_document['document_no'] ?? _id}'.replaceAll(
          RegExp(r'[^a-zA-Z0-9_-]'),
          '_',
        );
        final path = await FilePicker.saveFile(
          fileName: '$name.${format == 'ubl' ? 'xml' : 'pdf'}',
          bytes: bytes,
          mimeType: format == 'ubl' ? 'application/xml' : 'application/pdf',
        );
        if (mounted && path != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${format.toUpperCase()} kaydedildi.')),
          );
        }
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${extraDocumentLabels[widget.kind]} Detayı')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final field in const [
          ('document_no', 'Belge No'),
          ('uuid', 'ETTN'),
          ('customer_name', 'Alıcı'),
          ('customer_identifier', 'VKN / TCKN'),
          ('issue_date', 'Tarih'),
          ('status', 'Durum'),
          ('payable_amount', 'Tutar'),
          ('error_message', 'Hata'),
        ])
          if ('${_document[field.$1] ?? ''}'.isNotEmpty)
            ListTile(
              title: Text(field.$2),
              subtitle: Text('${_document[field.$1]}'),
            ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final format in const ['html', 'pdf', 'ubl'])
              OutlinedButton(
                onPressed: _busy ? null : () => _content(format),
                child: Text(
                  format == 'html'
                      ? 'İçeriği Gör'
                      : '${format.toUpperCase()} Kaydet',
                ),
              ),
            if (!widget.incoming)
              OutlinedButton(
                onPressed: _busy ? null : () => _action(false),
                child: const Text('Durumu Yenile'),
              ),
            if (!widget.incoming &&
                widget.kind != 'despatches' &&
                '${_document['status']}'.toUpperCase() != 'CANCELLED')
              OutlinedButton(
                onPressed: _busy ? null : () => _action(true),
                child: const Text('İptal Et'),
              ),
          ],
        ),
      ],
    ),
  );
}

class _ExtraLine {
  _ExtraLine()
    : name = TextEditingController(),
      quantity = TextEditingController(text: '1'),
      price = TextEditingController(),
      vat = TextEditingController(text: '20'),
      stopaj = TextEditingController(text: '2');
  final TextEditingController name, quantity, price, vat, stopaj;
  String unit = 'C62';

  void dispose() {
    name.dispose();
    quantity.dispose();
    price.dispose();
    vat.dispose();
    stopaj.dispose();
  }
}

class ExtraDocumentCreatePage extends StatefulWidget {
  const ExtraDocumentCreatePage({
    super.key,
    required this.api,
    required this.kind,
  });
  final FinkitApi api;
  final String kind;

  @override
  State<ExtraDocumentCreatePage> createState() =>
      _ExtraDocumentCreatePageState();
}

class _ExtraDocumentCreatePageState extends State<ExtraDocumentCreatePage> {
  final _fields = <String, TextEditingController>{};
  final _lines = <_ExtraLine>[_ExtraLine()];
  bool _busy = false;
  bool _sendEmail = false;
  bool _sameAddress = true;
  bool _hasCarrier = false;
  String _sendingType = 'ELEKTRONIK';
  Map<String, dynamic>? _recipient;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.kind == 'esmm') _lines.first.stopaj.text = '20';
    final today = DateTime.now();
    final date =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    for (final key in const [
      'identifier',
      'name',
      'tax_office',
      'email',
      'phone',
      'street',
      'building_no',
      'district',
      'city',
      'postal_code',
      'issue_date',
      'delivery_street',
      'delivery_building_no',
      'delivery_district',
      'delivery_city',
      'delivery_postal_code',
      'vehicle_plate',
      'driver_first_name',
      'driver_last_name',
      'driver_tckn',
      'actual_despatch_date',
      'actual_despatch_time',
      'carrier_name',
      'carrier_identifier',
      'carrier_tax_office',
      'iban',
      'note',
    ]) {
      _fields[key] = TextEditingController(
        text: key == 'issue_date' || key == 'actual_despatch_date' ? date : '',
      );
    }
    _fields['actual_despatch_time']!.text =
        '${today.hour.toString().padLeft(2, '0')}:${today.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  String _v(String key) => _fields[key]!.text.trim();
  Widget _field(String key, String label, {bool numeric = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: _fields[key],
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      decoration: InputDecoration(labelText: label),
      onChanged: key == 'identifier'
          ? (_) => setState(() => _recipient = null)
          : null,
    ),
  );

  Map<String, dynamic> _address(String prefix) => {
    for (final key in const [
      'street',
      'building_no',
      'district',
      'city',
      'postal_code',
    ])
      if (_v('$prefix$key').isNotEmpty) key: _v('$prefix$key'),
    'country': 'Türkiye',
  };

  String? _validate() {
    if (!RegExp(r'^\d{10,11}$').hasMatch(_v('identifier'))) {
      return 'VKN 10, TCKN 11 haneli olmalı.';
    }
    if (_v('name').isEmpty) return 'Alıcı/üretici adı gerekli.';
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(_v('issue_date'))) {
      return 'Belge tarihi YYYY-AA-GG biçiminde olmalı.';
    }
    if (_sendEmail && _v('email').isEmpty) return 'Gönderim e-postası gerekli.';
    if (widget.kind == 'despatches') {
      if (_recipient?['is_einvoice_user'] == false) {
        return 'Alıcı e-irsaliye mükellefi değil.';
      }
      final driver = [
        _v('driver_first_name'),
        _v('driver_last_name'),
        _v('driver_tckn'),
      ];
      if (driver.any((s) => s.isNotEmpty) &&
          (driver.take(2).any((s) => s.isEmpty) ||
              !RegExp(r'^\d{11}$').hasMatch(driver.last))) {
        return 'Şoför adı, soyadı ve 11 haneli TCKN gerekli.';
      }
      if (_hasCarrier &&
          (_v('carrier_name').isEmpty ||
              !RegExp(r'^\d{10,11}$').hasMatch(_v('carrier_identifier')))) {
        return 'Taşıyıcı ünvanı ve VKN/TCKN gerekli.';
      }
    }
    if (!_lines.any(
      (line) =>
          line.name.text.trim().isNotEmpty &&
          (double.tryParse(line.quantity.text) ?? 0) > 0 &&
          (widget.kind == 'despatches' ||
              (double.tryParse(line.price.text) ?? 0) > 0),
    )) {
      return 'En az bir geçerli belge satırı gerekli.';
    }
    return null;
  }

  Map<String, dynamic> _payload() {
    final kind = widget.kind;
    final lines = _lines
        .where(
          (line) =>
              line.name.text.trim().isNotEmpty &&
              (double.tryParse(line.quantity.text) ?? 0) > 0 &&
              (kind == 'despatches' ||
                  (double.tryParse(line.price.text) ?? 0) > 0),
        )
        .map((line) {
          final price = double.tryParse(line.price.text) ?? 0;
          return <String, dynamic>{
            'name': line.name.text.trim(),
            'quantity': kind == 'esmm' ? 1 : double.parse(line.quantity.text),
            if (kind != 'esmm') 'unit_code': line.unit,
            if (kind != 'despatches' || price > 0) 'unit_price': price,
            if (kind == 'esmm') ...{
              'vat_rate': double.tryParse(line.vat.text) ?? 0,
              'gv_stopaj_rate': double.tryParse(line.stopaj.text) ?? 0,
            },
            if (kind == 'creditnotes')
              'stopaj_rate': double.tryParse(line.stopaj.text) ?? 2,
          };
        })
        .toList();
    return {
      'issue_date': _v('issue_date'),
      'customer': {
        'identifier': _v('identifier'),
        'name': _v('name'),
        if (_v('tax_office').isNotEmpty) 'tax_office': _v('tax_office'),
        if (_v('email').isNotEmpty) 'email': _v('email'),
        if (_v('phone').isNotEmpty) 'phone': _v('phone'),
        'address': _address(''),
      },
      'lines': lines,
      if (_v('note').isNotEmpty) 'notes': [_v('note')],
      if (kind == 'despatches') ...{
        if (_recipient?['suggested_alias'] != null)
          'receiver_alias': _recipient!['suggested_alias'],
        if (!_sameAddress) 'delivery_address': _address('delivery_'),
        if (_v('vehicle_plate').isNotEmpty)
          'vehicle_plate': _v('vehicle_plate').toUpperCase(),
        if (_v('driver_tckn').isNotEmpty)
          'driver': {
            'first_name': _v('driver_first_name'),
            'last_name': _v('driver_last_name'),
            'tckn': _v('driver_tckn'),
          },
        if (_hasCarrier)
          'carrier': {
            'name': _v('carrier_name'),
            'identifier': _v('carrier_identifier'),
            if (_v('carrier_tax_office').isNotEmpty)
              'tax_office': _v('carrier_tax_office'),
          },
        if (_v('actual_despatch_date').isNotEmpty)
          'actual_despatch_date': _v('actual_despatch_date'),
        if (_v('actual_despatch_time').isNotEmpty)
          'actual_despatch_time': '${_v('actual_despatch_time')}:00',
      },
      if (kind == 'esmm') ...{
        'sending_type': _sendingType,
        if (_v('iban').isNotEmpty)
          'iban': _v('iban').replaceAll(' ', '').toUpperCase(),
      },
      if (kind == 'creditnotes') ...{
        'send_email': _sendEmail,
        if (_sendEmail) 'emails': [_v('email')],
      },
    };
  }

  Future<void> _checkRecipient() async {
    if (!RegExp(r'^\d{10,11}$').hasMatch(_v('identifier'))) {
      setState(() => _error = 'Önce geçerli VKN/TCKN girin.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.checkDespatchUser(_v('identifier'));
      if (mounted) setState(() => _recipient = result);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final error = _validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${extraDocumentLabels[widget.kind]} Gönder'),
        content: Text(
          '${_v('name')} için ${_lines.length} satırlı belge sağlayıcıya gönderilecek. Onaylıyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Onayla ve Gönder'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.createExtraDocument(widget.kind, _payload());
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Yeni ${extraDocumentLabels[widget.kind]}')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(title: 'Alıcı / Üretici'),
        _field('identifier', 'VKN / TCKN', numeric: true),
        if (widget.kind == 'despatches')
          OutlinedButton(
            onPressed: _busy ? null : _checkRecipient,
            child: const Text('E-İrsaliye Mükellefiyetini Kontrol Et'),
          ),
        if (_recipient != null)
          Text(
            _recipient?['is_einvoice_user'] == true
                ? 'E-İrsaliye mükellefi'
                : 'E-İrsaliye mükellefi değil',
          ),
        _field('name', 'Ad / Ünvan'),
        _field('tax_office', 'Vergi dairesi'),
        _field('email', 'E-posta'),
        if (widget.kind != 'creditnotes') _field('phone', 'Telefon'),
        _field('street', 'Adres'),
        if (widget.kind == 'despatches') _field('building_no', 'Bina no'),
        _field('district', 'İlçe'),
        _field('city', 'İl'),
        if (widget.kind == 'despatches') _field('postal_code', 'Posta kodu'),
        const SectionHeader(title: 'Belge'),
        _field('issue_date', 'Belge tarihi (YYYY-AA-GG)'),
        if (widget.kind == 'esmm') ...[
          DropdownButtonFormField<String>(
            initialValue: _sendingType,
            decoration: const InputDecoration(labelText: 'Teslim türü'),
            items: const [
              DropdownMenuItem(value: 'ELEKTRONIK', child: Text('Elektronik')),
              DropdownMenuItem(value: 'KAGIT', child: Text('Kağıt')),
            ],
            onChanged: (value) =>
                setState(() => _sendingType = value ?? _sendingType),
          ),
          _field('iban', 'IBAN'),
        ],
        if (widget.kind == 'creditnotes')
          SwitchListTile(
            title: const Text('E-posta ile gönder'),
            value: _sendEmail,
            onChanged: (value) => setState(() => _sendEmail = value),
          ),
        if (widget.kind == 'despatches') ...[
          SwitchListTile(
            title: const Text('Teslim adresi alıcı adresiyle aynı'),
            value: _sameAddress,
            onChanged: (value) => setState(() => _sameAddress = value),
          ),
          if (!_sameAddress) ...[
            _field('delivery_street', 'Teslim adresi'),
            _field('delivery_building_no', 'Teslim bina no'),
            _field('delivery_district', 'Teslim ilçesi'),
            _field('delivery_city', 'Teslim ili'),
            _field('delivery_postal_code', 'Teslim posta kodu'),
          ],
          _field('vehicle_plate', 'Araç plakası'),
          _field('driver_first_name', 'Şoför adı'),
          _field('driver_last_name', 'Şoför soyadı'),
          _field('driver_tckn', 'Şoför TCKN', numeric: true),
          _field('actual_despatch_date', 'Fiili sevk tarihi'),
          _field('actual_despatch_time', 'Fiili sevk saati (SS:DD)'),
          SwitchListTile(
            title: const Text('Taşıyıcı firma var'),
            value: _hasCarrier,
            onChanged: (value) => setState(() => _hasCarrier = value),
          ),
          if (_hasCarrier) ...[
            _field('carrier_name', 'Taşıyıcı ünvanı'),
            _field('carrier_identifier', 'Taşıyıcı VKN/TCKN', numeric: true),
            _field('carrier_tax_office', 'Taşıyıcı vergi dairesi'),
          ],
        ],
        _field('note', 'Not'),
        const SectionHeader(title: 'Kalemler'),
        for (var index = 0; index < _lines.length; index++)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text('Kalem ${index + 1}'),
                  TextField(
                    controller: _lines[index].name,
                    decoration: const InputDecoration(
                      labelText: 'Ürün / Hizmet',
                    ),
                  ),
                  if (widget.kind != 'esmm')
                    TextField(
                      controller: _lines[index].quantity,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Miktar'),
                    ),
                  if (widget.kind != 'esmm')
                    DropdownButtonFormField<String>(
                      initialValue: _lines[index].unit,
                      decoration: const InputDecoration(labelText: 'Birim'),
                      items: const [
                        DropdownMenuItem(value: 'C62', child: Text('Adet')),
                        DropdownMenuItem(value: 'KGM', child: Text('Kilogram')),
                        DropdownMenuItem(value: 'TNE', child: Text('Ton')),
                        DropdownMenuItem(value: 'LTR', child: Text('Litre')),
                        DropdownMenuItem(value: 'MTR', child: Text('Metre')),
                      ],
                      onChanged: (value) =>
                          setState(() => _lines[index].unit = value ?? 'C62'),
                    ),
                  TextField(
                    controller: _lines[index].price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: widget.kind == 'despatches'
                          ? 'Birim fiyat (opsiyonel)'
                          : 'Birim fiyat',
                    ),
                  ),
                  if (widget.kind == 'esmm')
                    TextField(
                      controller: _lines[index].vat,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'KDV %'),
                    ),
                  if (widget.kind != 'despatches')
                    TextField(
                      controller: _lines[index].stopaj,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Stopaj %'),
                    ),
                  if (_lines.length > 1)
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _lines.removeAt(index).dispose()),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Kalemi Sil'),
                    ),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            final line = _ExtraLine();
            if (widget.kind == 'esmm') line.stopaj.text = '20';
            _lines.add(line);
          }),
          icon: const Icon(Icons.add),
          label: const Text('Kalem Ekle'),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _send,
          icon: const Icon(Icons.send_outlined),
          label: Text(_busy ? 'Gönderiliyor…' : 'Gönder'),
        ),
      ],
    ),
  );
}
