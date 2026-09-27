import 'invoice_amounts.dart';

const withholdingRates = <String, int>{
  '601': 40,
  '602': 90,
  '603': 70,
  '604': 50,
  '605': 50,
  '606': 90,
  '607': 90,
  '608': 90,
  '609': 70,
  '610': 90,
  '611': 90,
  '612': 90,
  '613': 90,
  '614': 50,
  '615': 70,
  '616': 50,
  '617': 70,
  '618': 70,
  '619': 70,
  '620': 70,
  '621': 90,
  '622': 90,
  '623': 50,
  '624': 20,
  '625': 30,
  '626': 20,
  '627': 50,
  '801': 100,
  '802': 100,
  '803': 100,
  '804': 100,
  '805': 100,
  '806': 100,
  '807': 100,
  '808': 100,
  '809': 100,
  '810': 100,
  '811': 100,
  '812': 100,
  '813': 100,
  '814': 100,
  '815': 100,
  '816': 100,
  '817': 100,
  '818': 100,
  '819': 100,
  '820': 100,
  '821': 100,
  '822': 100,
  '823': 100,
  '824': 100,
  '825': 100,
};

double _n(dynamic value) {
  final number = double.tryParse('$value');
  return number != null && number.isFinite ? number : 0;
}

String _s(dynamic value) => '${value ?? ''}'.trim();

List<String> invoiceFiscalErrors(
  Map<String, dynamic> form,
  List<Map<String, dynamic>> lines,
) {
  final type = _s(form['invoice_type']);
  final errors = <String>[];
  if (type == 'KONAKLAMA' && _s(form['accommodation_service_date']).isEmpty) {
    errors.add('Konaklama hizmetinin tamamlanma tarihi seçilmeli');
  }
  if (type == 'IHRACKAYITLI') {
    if (!{
      '701',
      '702',
      '703',
      '704',
    }.contains(_s(form['export_registered_code']))) {
      errors.add('İhraç kayıtlı işlem kodu (701–704) seçilmeli');
    }
    if (!lines.any((line) => _n(line['vat_rate']) > 0)) {
      errors.add('İhraç kayıtlı faturada en az bir KDV’li satır olmalı');
    }
  }
  if (type.startsWith('YTB_')) {
    if (!RegExp(r'^\d{6}$').hasMatch(_s(form['investment_incentive_number'])) ||
        _s(form['investment_incentive_date']).isEmpty) {
      errors.add('Yatırım teşvik numarası 6 haneli ve tarihi dolu olmalı');
    }
  }
  if ({'IADE', 'TEVKIFATIADE'}.contains(type) &&
      !RegExp(r'^[A-Z0-9]{3}[0-9]{13}$')
          .hasMatch(_s(form['billing_reference']).toUpperCase())) {
    errors.add(
      'İade referansı 16 karakterlik fatura numarası olmalı; ETTN kullanmayın',
    );
  }
  if (type == 'YTB_IADE') {
    final references = form['billing_references'];
    if (references is! List ||
        references.isEmpty ||
        references.any(
          (reference) =>
              reference is! Map ||
              !RegExp(r'^[A-Z0-9]{3}[0-9]{13}$')
                  .hasMatch(_s(reference['number']).toUpperCase()) ||
              _s(reference['date']).isEmpty,
        )) {
      errors.add(
        'Yatırım teşvik iadesinde her fatura numarası ve tarihi geçerli olmalı',
      );
    }
  }
  if (_s(form['despatch_number']).isEmpty !=
      _s(form['despatch_date']).isEmpty) {
    errors.add('İrsaliye numarası ve tarihi birlikte girilmeli');
  }
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final i = index + 1;
    final vat = _n(line['vat_rate']);
    final bsmv = _n(line['bsmv_rate']);
    final withholdingCode = _s(line['withholding_code']);
    final withholdingRate = _s(line['withholding_rate']);
    if (bsmv > 0 &&
        (!{'SATIS', 'ISTISNA'}.contains(type) ||
            bsmv > 100 ||
            vat != 0 ||
            _s(line['exemption_code']) != '209')) {
      errors.add(
        '$i. satırda BSMV için SATIŞ/İSTİSNA, KDV %0 ve 209 istisna kodu gerekir',
      );
    }
    if (withholdingCode.isNotEmpty || withholdingRate.isNotEmpty) {
      if (!{'TEVKIFAT', 'YTB_TEVKIFAT', 'TEVKIFATIADE'}.contains(type)) {
        errors.add('$i. satırdaki tevkifat bu fatura tipiyle kullanılamaz');
      } else if (withholdingRates[withholdingCode] != _n(withholdingRate)) {
        errors.add('$i. satırda GİB tevkifat kodu ve oranı uyuşmuyor');
      }
      if (vat <= 0) errors.add('$i. satırda tevkifat için pozitif KDV gerekir');
    }
    if (type == 'TEVKIFATIADE') {
      final ratio = _n(line['return_ratio']);
      final originalVat = _n(line['original_unwithheld_vat']);
      final amounts = calculateInvoiceLineAmounts(line);
      if (ratio <= 0 ||
          ratio > 100 ||
          _s(line['return_ratio']).isEmpty ||
          originalVat < 0 ||
          _s(line['original_unwithheld_vat']).isEmpty) {
        errors.add(
          '$i. satırda iade oranı ve alıştaki tevkifatsız KDV gerekli',
        );
      } else if ((invoiceMoney(originalVat * ratio / 100) -
                  (amounts.vat - amounts.withholding))
              .abs() >
          0.01) {
        errors.add(
          '$i. satırda iadeye konu KDV alıştaki KDV ve iade oranıyla uyuşmuyor',
        );
      }
    }
    if (type == 'OZELMATRAH') {
      final base = _n(line['special_base_amount']);
      if (!RegExp(r'^8(0[1-9]|1[0-2])$')
              .hasMatch(_s(line['special_base_code'])) ||
          _s(line['special_base_amount']).isEmpty ||
          base < 0 ||
          base > calculateInvoiceLineAmounts(line).net ||
          vat <= 0) {
        errors.add(
          '$i. satırda 801-812 kodu, geçerli matrah ve pozitif KDV gerekli',
        );
      }
    }
    if (type.startsWith('YTB_')) {
      final expense = _s(line['incentive_expense_type']);
      if (!{'01', '02', '03', '04'}.contains(expense)) {
        errors.add('$i. satırda yatırım teşvik harcama tipi seçilmeli');
      }
      if (expense == '01' &&
          (_s(line['machine_id']).isEmpty ||
              _s(line['machine_sequence_no']).isEmpty)) {
        errors.add('$i. satırda makine ID ve sıra numarası girilmeli');
      }
      if (type == 'YTB_ISTISNA') {
        if (vat != 0 ||
            !{'308', '339'}.contains(_s(line['exemption_code'])) ||
            ((expense == '01'
                    ? '308'
                    : expense == '02'
                    ? '339'
                    : '') !=
                _s(line['exemption_code'])) ||
            _n(line['waived_vat_rate']) <= 0) {
          errors.add(
            '$i. satırda harcama tipine uygun 308/339 istisna ve vazgeçilen KDV gerekir',
          );
        }
      }
    }
  }
  if ({'TEVKIFAT', 'YTB_TEVKIFAT'}.contains(type)) {
    if (!lines.any(
      (line) =>
          _n(line['withholding_rate']) > 0 ||
          (type == 'TEVKIFAT' &&
              line['deduction_tax'] is Map &&
              _s((line['deduction_tax'] as Map)['code']) == '4171'),
    )) {
      errors.add('En az bir satırda tevkifat türü seçilmeli');
    }
    final partial = lines.where(
      (line) =>
          _n(line['withholding_rate']) > 0 &&
          _s(line['withholding_code']).startsWith('6'),
    );
    if (partial.isNotEmpty) {
      final date = _s(form['withholding_operation_date']).isNotEmpty
          ? _s(form['withholding_operation_date'])
          : _s(form['issue_date']);
      final thresholds = {'2024': 6900, '2025': 9900, '2026': 12000};
      final threshold = date.length >= 4
          ? thresholds[date.substring(0, 4)]
          : null;
      final amount = partial.fold<double>(0, (sum, line) {
        final value = calculateInvoiceLineAmounts(line);
        return sum + value.net + value.vat;
      });
      final operationTotal = _s(form['withholding_operation_total']).isEmpty
          ? amount
          : _n(form['withholding_operation_total']);
      if (threshold == null || date.compareTo('2024-03-01') < 0) {
        errors.add(
          'İşlem tarihi için doğrulanmış tevkifat sınırı tanımlı değil',
        );
      } else if (operationTotal <= threshold) {
        errors.add(
          'Kısmi tevkifatta işlem KDV dahil $threshold TL sınırını aşmalı',
        );
      }
      if (_s(form['withholding_operation_total']).isNotEmpty &&
          (operationTotal < amount ||
              _s(form['withholding_operation_reference']).isEmpty)) {
        errors.add(
          'İşlem toplamı faturadan az olamaz; işlem/sözleşme referansı girin',
        );
      }
    }
  }
  return errors.toSet().toList();
}
