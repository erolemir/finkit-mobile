import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../theme.dart';
import '../widgets.dart';
import 'partner_form_page.dart';
import 'purchase_processing_page.dart';
import 'electronic_invoice_page.dart';

Future<void> openInvoiceDetail(
  BuildContext context,
  FinkitApi api,
  Map<String, dynamic> invoice, {
  bool purchase = false,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) =>
        InvoiceDetailPage(api: api, invoice: invoice, purchase: purchase),
  ),
);

class InvoiceDetailPage extends StatefulWidget {
  const InvoiceDetailPage({
    super.key,
    required this.api,
    required this.invoice,
    this.purchase = false,
  });
  final FinkitApi api;
  final Map<String, dynamic> invoice;
  final bool purchase;

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  Map<String, dynamic>? _invoice;
  String? _error;
  String? _actionError;
  bool _busy = false;
  String? _partnerName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _invoice = null;
    });
    try {
      final id = int.parse('${widget.invoice['id']}');
      final invoice = widget.purchase
          ? await widget.api.purchaseInvoice(id)
          : await widget.api.salesInvoice(id);
      if (!mounted) return;
      setState(() => _invoice = invoice);
      final partnerId = int.tryParse(
        '${invoice[widget.purchase ? 'supplier_id' : 'partner_id']}',
      );
      if (partnerId != null) {
        try {
          final partner = await widget.api.partner(partnerId);
          if (mounted) {
            setState(() => _partnerName = partner['name']?.toString());
          }
        } catch (_) {
          /* Fatura bilgileri cari servisi aksasa da erişilebilir. */
        }
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  bool get _editable {
    if (widget.purchase) {
      final lines = _invoice?['lines'];
      return lines is List &&
          lines.whereType<Map>().any(
            (line) => line['accounting_action'] == null,
          );
    }
    return const ['DRAFT', 'NEEDS_MATCH'].contains(_invoice?['status']);
  }

  Future<void> _matchSupplier() async {
    final supplier = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => SupplierPickerPage(api: widget.api)),
    );
    if (supplier == null || !mounted) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final updated = await widget.api.matchPurchaseSupplier(
        int.parse('${_invoice!['id']}'),
        int.parse('${supplier['id']}'),
      );
      if (mounted) {
        setState(() {
          _invoice = updated;
          _partnerName = supplier['name']?.toString();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _actionError =
              error is ApiException &&
                  (error.statusCode == 404 || error.statusCode == 405)
              ? 'Sunucuda tedarikçi eşleştirme güncellemesi henüz etkin değil. Güncellemeden sonra tekrar deneyin.'
              : error.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve() async {
    if (_busy) return;
    if (widget.purchase) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              PurchaseProcessingPage(api: widget.api, invoice: _invoice!),
        ),
      );
      if (mounted) await _load();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          const {'EINVOICE', 'EARCHIVE'}.contains(_invoice?['source_type'])
              ? 'Faturayı kesinleştir ve gönder'
              : 'Faturayı onayla',
        ),
        content: Text(
          const {'EINVOICE', 'EARCHIVE'}.contains(_invoice?['source_type'])
              ? 'Fatura muhasebe kayıtlarına işlenecek ve e-belge gönderim sırasına alınacak. Devam etmek istiyor musunuz?'
              : 'Fatura muhasebe kayıtlarınıza işlenecek. Devam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final id = int.parse('${_invoice!['id']}');
      final updated = await widget.api.finalizeSalesInvoice(id);
      if (mounted) {
        setState(() => _invoice = updated);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Fatura onaylandı')));
      }
    } catch (error) {
      if (mounted) setState(() => _actionError = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelSales() async {
    if (_busy || _invoice == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Faturayı iptal et'),
        content: const Text(
          'Kesinleşmiş faturanın cari ve stok hareketleri geri alınır. İptal etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('İptal et'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final updated = await widget.api.cancelSalesInvoice(
        (_invoice!['id'] as num).toInt(),
      );
      if (mounted) setState(() => _invoice = updated);
    } catch (error) {
      if (mounted) setState(() => _actionError = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copySales() async {
    if (_busy || _invoice == null) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final copy = await widget.api.copySalesInvoice(
        (_invoice!['id'] as num).toInt(),
      );
      if (mounted) {
        setState(() => _invoice = copy);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yeni taslak fatura oluşturuldu.')),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _actionError = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _linkDespatch() async {
    if (_busy || _invoice == null) return;
    String value = '';
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('E-İrsaliye bağla'),
        content: TextField(
          decoration: const InputDecoration(
            labelText: 'İrsaliye takip numarası',
          ),
          onChanged: (text) => value = text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, value.trim()),
            child: const Text('Bağla'),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    if (selected.isEmpty || selected.length > 36) {
      setState(
        () => _actionError = 'Geçerli bir irsaliye takip numarası girin.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final updated = await widget.api.linkSalesInvoiceDespatch(
        (_invoice!['id'] as num).toInt(),
        selected,
      );
      if (mounted) setState(() => _invoice = updated);
    } catch (error) {
      if (mounted) setState(() => _actionError = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openContent(String format) async {
    if (_busy || _invoice == null) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final bytes = await widget.api.accountingInvoiceContent(
        (_invoice!['id'] as num).toInt(),
        format,
        purchase: widget.purchase,
      );
      if (!mounted) return;
      if (format == 'html') {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => ElectronicDocumentPreview(
              loader: () async => utf8.decode(bytes),
            ),
          ),
        );
      } else {
        final name = '${_invoice!['number'] ?? _invoice!['id']}'.replaceAll(
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
      if (mounted) setState(() => _actionError = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoice = _invoice;
    final missingSupplier = widget.purchase && invoice?['supplier_id'] == null;
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(
        title: Text(widget.purchase ? 'Gelen Fatura' : 'Satış Faturası'),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      'Fatura detayı yüklenemedi',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              ),
            )
          : invoice == null
          ? const LoadingState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (missingSupplier && _editable) ...[
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.link_rounded,
                              color: FinkitColors.warning,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tedarikçi eşleştirmesi gerekli',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Onaylamadan önce bu faturayı bir tedarikçiye bağlayın. Yeni tedarikçi de ekleyebilirsiniz.',
                        ),
                        TextButton.icon(
                          onPressed: _busy ? null : _matchSupplier,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Tedarikçi Seç'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                InvoiceContent(
                  invoice: invoice,
                  purchase: widget.purchase,
                  partnerName:
                      _partnerName ??
                      (missingSupplier
                          ? 'Henüz seçilmedi'
                          : 'Cari bilgisi alınamadı'),
                ),
                if (widget.purchase
                    ? invoice['provider_id']?.toString().isNotEmpty == true
                    : invoice['e_document_uuid']?.toString().isNotEmpty ==
                          true) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _busy ? null : () => _openContent('html'),
                        child: const Text('HTML görüntüle'),
                      ),
                      OutlinedButton(
                        onPressed: _busy ? null : () => _openContent('pdf'),
                        child: const Text('PDF indir'),
                      ),
                      OutlinedButton(
                        onPressed: _busy ? null : () => _openContent('ubl'),
                        child: const Text('UBL indir'),
                      ),
                    ],
                  ),
                ],
                if (!widget.purchase) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _copySales,
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Faturayı kopyala'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _linkDespatch,
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('E-İrsaliye bağla'),
                  ),
                  if (invoice['status'] != 'CANCELLED')
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _cancelSales,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Faturayı iptal et'),
                    ),
                ],
                if (widget.purchase && _editable && !missingSupplier)
                  TextButton.icon(
                    onPressed: _busy ? null : _matchSupplier,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Tedarikçiyi Değiştir'),
                  ),
              ],
            ),
      bottomNavigationBar: invoice == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_actionError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _actionError!,
                          style: const TextStyle(color: FinkitColors.danger),
                        ),
                      ),
                    if (_editable)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : missingSupplier
                              ? _matchSupplier
                              : _approve,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  missingSupplier
                                      ? Icons.link_rounded
                                      : Icons.check_circle_outline_rounded,
                                ),
                          label: Text(
                            _busy
                                ? 'İşleniyor…'
                                : missingSupplier
                                ? 'Tedarikçi Seç ve Devam Et'
                                : widget.purchase
                                ? 'Kalemleri İşle'
                                : 'Faturayı Onayla',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Shared invoice presentation; unavailable amounts are never rendered as zero.
class InvoiceContent extends StatelessWidget {
  const InvoiceContent({
    super.key,
    required this.invoice,
    required this.partnerName,
    this.purchase = false,
  });
  final Map<String, dynamic> invoice;
  final String partnerName;
  final bool purchase;

  @override
  Widget build(BuildContext context) {
    final currency = invoice['currency']?.toString() ?? 'TRY';
    String amount(dynamic value) {
      final number = num.tryParse('$value');
      if (number == null) return '—';
      return NumberFormat.currency(
        locale: 'tr_TR',
        symbol: currency == 'TRY' ? '₺' : currency,
        decimalDigits: 2,
      ).format(number);
    }

    final total = num.tryParse('${invoice['gross_amount']}');
    final paid = num.tryParse('${invoice['paid_amount']}');
    final lines = (invoice['lines'] as List? ?? []).whereType<Map>().toList();
    final number = invoice['number']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurfaceCard(
          dark: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.receipt_long_rounded,
                color: Colors.white70,
                size: 28,
              ),
              const SizedBox(height: 16),
              Text(
                number?.isNotEmpty == true ? number! : 'Taslak Fatura',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                amount(invoice['gross_amount']),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Genel toplam',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              DocumentTypeBadges(document: invoice, dark: true),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (invoice['status'] != null)
                    StatusPill(
                      label: statusLabel('${invoice['status']}'),
                      value: '${invoice['status']}',
                    ),
                  if (invoice['payment_status'] != null)
                    StatusPill(
                      label: statusLabel('${invoice['payment_status']}'),
                      value: '${invoice['payment_status']}',
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                purchase ? 'TEDARİKÇİ' : 'MÜŞTERİ',
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 1,
                  color: FinkitColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                partnerName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Divider(height: 28),
              _InvoiceRow('Düzenleme tarihi', dateText(invoice['issue_date'])),
              _InvoiceRow('Vade tarihi', dateText(invoice['due_date'])),
              _InvoiceRow('Belge türü', documentTypeLabel(invoice)),
              if (invoiceKindLabel(invoice) != null)
                _InvoiceRow('Fatura işlemi', invoiceKindLabel(invoice)!),
              if (invoiceProfileLabel(invoice) != null)
                _InvoiceRow('Senaryo', invoiceProfileLabel(invoice)!),
              if (invoice['despatch_uuid']?.toString().isNotEmpty == true)
                _InvoiceRow('E-İrsaliye', '${invoice['despatch_uuid']}'),
              _InvoiceRow('Para birimi', currency),
            ],
          ),
        ),
        SectionHeader(
          title: 'Fatura Kalemleri',
          action: '${lines.length} kalem',
        ),
        if (lines.isEmpty)
          const SurfaceCard(
            child: Text(
              'Bu belge için kalem bilgisi sağlanmadı.',
              style: TextStyle(color: FinkitColors.muted),
            ),
          ),
        for (var i = 0; i < lines.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}. ${lines[i]['description'] ?? 'Fatura kalemi'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _InvoiceRow(
                    'Miktar × birim fiyat',
                    '${lines[i]['quantity'] ?? '—'} ${lines[i]['unit'] ?? ''} × ${amount(lines[i]['unit_price'])}',
                  ),
                  _InvoiceRow(
                    'KDV %${lines[i]['vat_rate'] ?? '—'}',
                    amount(lines[i]['line_vat']),
                  ),
                  if ((num.tryParse('${lines[i]['discount_rate']}') ?? 0) > 0)
                    _InvoiceRow('İskonto', '%${lines[i]['discount_rate']}'),
                  _InvoiceRow(
                    'Kalem toplamı',
                    amount(lines[i]['line_total']),
                    strong: true,
                  ),
                ],
              ),
            ),
          ),
        const SectionHeader(title: 'Tutar Özeti'),
        SurfaceCard(
          child: Column(
            children: [
              _InvoiceRow('Net tutar', amount(invoice['net_amount'])),
              if ((num.tryParse('${invoice['discount_amount']}') ?? 0) > 0)
                _InvoiceRow('İskonto', amount(invoice['discount_amount'])),
              _InvoiceRow('KDV', amount(invoice['vat_amount'])),
              if ((num.tryParse('${invoice['withholding_amount']}') ?? 0) > 0)
                _InvoiceRow('Tevkifat', amount(invoice['withholding_amount'])),
              _InvoiceRow(
                'Genel toplam',
                amount(invoice['gross_amount']),
                strong: true,
              ),
              const Divider(height: 24),
              _InvoiceRow(
                purchase ? 'Ödenen' : 'Tahsil edilen',
                amount(invoice['paid_amount']),
              ),
              _InvoiceRow(
                'Kalan tutar',
                total != null && paid != null
                    ? amount((total - paid).clamp(0, double.infinity))
                    : '—',
                strong: true,
              ),
            ],
          ),
        ),
        if (invoice['notes']?.toString().trim().isNotEmpty == true) ...[
          const SectionHeader(title: 'Notlar'),
          SurfaceCard(child: SelectableText('${invoice['notes']}')),
        ],
        if (invoice['e_document_uuid'] != null) ...[
          const SectionHeader(title: 'Belge Kimliği'),
          SurfaceCard(child: SelectableText('${invoice['e_document_uuid']}')),
        ],
      ],
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow(this.label, this.value, {this.strong = false});
  final String label;
  final String value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: FinkitColors.muted, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              fontSize: strong ? 15 : 13,
            ),
          ),
        ),
      ],
    ),
  );
}

class SupplierPickerPage extends StatefulWidget {
  const SupplierPickerPage({super.key, required this.api});
  final FinkitApi api;
  @override
  State<SupplierPickerPage> createState() => _SupplierPickerPageState();
}

class _SupplierPickerPageState extends State<SupplierPickerPage> {
  late Future<List<Map<String, dynamic>>> _future;
  String _query = '';
  @override
  void initState() {
    super.initState();
    _future = widget.api.partners();
  }

  Future<void> _create() async {
    final created = await showPartnerCreatePage(
      context,
      widget.api,
      defaultType: 'SUPPLIER',
    );
    if (created && mounted) setState(() => _future = widget.api.partners());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: FinkitColors.canvas,
    appBar: AppBar(title: const Text('Tedarikçi Seç')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Ad veya vergi numarası ara',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) => setState(
              () => _query = value.toLowerCase().replaceAll('ı', 'i'),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Tedarikçiler yüklenemedi'),
                      TextButton(
                        onPressed: () =>
                            setState(() => _future = widget.api.partners()),
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData) return const LoadingState();
              final suppliers = snapshot.data!
                  .where(
                    (p) =>
                        const [
                          'SUPPLIER',
                          'BOTH',
                        ].contains(p['partner_type']) &&
                        p['is_active'] != false &&
                        '${p['name']} ${p['tax_number']}'
                            .toLowerCase()
                            .replaceAll('ı', 'i')
                            .contains(_query),
                  )
                  .toList();
              if (suppliers.isEmpty) {
                return const EmptyState(
                  icon: Icons.local_shipping_outlined,
                  title: 'Tedarikçi bulunamadı',
                  description:
                      'Aramanızı değiştirin veya yeni bir tedarikçi ekleyin.',
                );
              }
              return ListView.builder(
                itemCount: suppliers.length,
                itemBuilder: (context, index) {
                  final supplier = suppliers[index];
                  return ListTile(
                    leading: const Icon(Icons.business_outlined),
                    title: Text('${supplier['name']}'),
                    subtitle: Text(
                      'Vergi no: ${supplier['tax_number'] ?? '—'}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.pop(context, supplier),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: OutlinedButton.icon(
          onPressed: _create,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Yeni Tedarikçi Ekle'),
        ),
      ),
    ),
  );
}
