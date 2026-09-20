String _code(Object? value) => (value is String ? value : '')
    .trim()
    .toUpperCase()
    .replaceAll('İ', 'I')
    .replaceAll('Ş', 'S')
    .replaceAll('Ü', 'U')
    .replaceAll('Ğ', 'G')
    .replaceAll('Ö', 'O')
    .replaceAll('Ç', 'C')
    .replaceAll(RegExp(r'[\s_-]'), '');

const _documentLabels = {
  'EINVOICE': 'E-Fatura',
  'EFATURA': 'E-Fatura',
  'EARCHIVE': 'E-Arşiv',
  'EARSIV': 'E-Arşiv',
  'EARSIVFATURA': 'E-Arşiv',
  'ESMM': 'E-SMM',
  'SERBESTMESLEKMAKBUZU': 'E-SMM',
  'MM': 'E-Müstahsil',
  'EMM': 'E-Müstahsil',
  'CREDITNOTE': 'E-Müstahsil',
  'MUSTAHSILMAKBUZU': 'E-Müstahsil',
  'EDESPATCH': 'E-İrsaliye',
  'EIRSALIYE': 'E-İrsaliye',
  'DESPATCHADVICE': 'E-İrsaliye',
};

String documentTypeLabel(Map<String, dynamic> document) {
  for (final field in ['document_type', 'documentType']) {
    final label = _documentLabels[_code(document[field])];
    if (label != null) return label;
  }
  final profile = _code(
    document['profile'] ?? document['profile_id'] ?? document['profileId'],
  );
  if (profile == 'EARSIVFATURA') return 'E-Arşiv';
  if (profile == 'TEMELFATURA' || profile == 'TICARIFATURA') return 'E-Fatura';
  if (profile == 'TEMELIRSALIYE') return 'E-İrsaliye';
  final source = _code(document['source_type']);
  if (_documentLabels.containsKey(source)) return _documentLabels[source]!;
  if (_code(document['document_type'] ?? document['documentType']) == 'AUTO') {
    return 'Belge türü bekleniyor';
  }
  if (source == 'MANUAL' && document['e_document_uuid'] == null) {
    return 'Manuel kayıt';
  }
  return 'Belge türü belirtilmemiş';
}

String? invoiceKindLabel(Map<String, dynamic> document) =>
    const {
      'SATIS': 'Satış',
      'ALIS': 'Alış',
      'IADE': 'İade',
      'TEVKIFAT': 'Tevkifat',
      'ISTISNA': 'İstisna',
      'IHRACKAYITLI': 'İhraç kayıtlı',
      'OZELMATRAH': 'Özel matrah',
    }[_code(
      document['invoice_type'] ??
          document['invoiceType'] ??
          document['documentTypeCode'],
    )];

String? invoiceProfileLabel(Map<String, dynamic> document) =>
    const {
      'TEMELFATURA': 'Temel fatura',
      'TICARIFATURA': 'Ticari fatura',
      'EARSIVFATURA': 'E-Arşiv fatura',
      'TEMELIRSALIYE': 'Temel irsaliye',
    }[_code(
      document['profile'] ?? document['profile_id'] ?? document['profileId'],
    )];
