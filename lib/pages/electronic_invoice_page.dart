import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../api_client.dart';
import '../theme.dart';
import '../document_types.dart';
import 'invoice_detail_page.dart';

class ElectronicInvoicePage extends StatefulWidget {
  const ElectronicInvoicePage({
    super.key,
    required this.api,
    required this.invoice,
    required this.isClient,
    required this.incoming,
  });
  final FinkitApi api;
  final Map<String, dynamic> invoice;
  final bool isClient;
  final bool incoming;

  @override
  State<ElectronicInvoicePage> createState() => _ElectronicInvoicePageState();
}

class _ElectronicInvoicePageState extends State<ElectronicInvoicePage> {
  late Map<String, dynamic> _invoice;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _invoice = Map<String, dynamic>.from(widget.invoice);
  }

  String? get _id {
    final value = widget.incoming
        ? _invoice['provider_id'] ?? _invoice['id']
        : _invoice['uuid'];
    final id = value?.toString().trim();
    return id == null || id.isEmpty ? null : id;
  }

  Future<void> _run(
    Future<Map<String, dynamic>> Function() action,
    String success,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => _invoice = {..._invoice, ...updated});
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(success)));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final id = _id;
    if (id == null) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Faturayı İptal Et'),
        content: const Text(
          'İptal işlemi sağlayıcıya iletilir ve bağlı muhasebe kaydı güncellenir. Devam edilsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    await _run(
      () => widget.api.cancelElectronicInvoice(id, isClient: widget.isClient),
      'İptal isteği işlendi',
    );
  }

  Future<void> _respond(String responseType) async {
    final id = _id;
    if (id == null) return;
    final reason = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          responseType == 'KABUL' ? 'Faturayı Kabul Et' : 'Faturayı Reddet',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              responseType == 'KABUL'
                  ? 'Ticari faturaya kabul yanıtı gönderilecek.'
                  : 'Ticari faturaya ret yanıtı gönderilecek.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Açıklama'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
    final description = reason.text.trim();
    reason.dispose();
    if (approved != true) return;
    await _run(
      () => widget.api.respondElectronicInvoice(
        id,
        isClient: widget.isClient,
        responseType: responseType,
        description: description,
      ),
      responseType == 'KABUL'
          ? 'Kabul yanıtı gönderildi'
          : 'Ret yanıtı gönderildi',
    );
  }

  Future<void> _saveContent(String format) async {
    final id = _id;
    if (id == null || _busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await widget.api.electronicInvoiceContent(
        id,
        isClient: widget.isClient,
        incoming: widget.incoming,
        format: format,
      );
      if (!mounted) return;
      final number =
          '${_invoice['document_no'] ?? _invoice['invoice_number'] ?? id}'
              .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final saved = await FilePicker.saveFile(
        fileName: '$number.${format == 'ubl' ? 'xml' : format}',
        bytes: bytes,
        mimeType: format == 'pdf' ? 'application/pdf' : 'application/xml',
      );
      if (saved != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${format.toUpperCase()} kaydedildi.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = _id;
    final incoming = widget.incoming;
    final invoice = _invoice;
    final canRespond =
        incoming &&
        '${invoice['profile'] ?? invoice['profile_id']}'.toUpperCase() ==
            'TICARIFATURA' &&
        !const {'KABUL', 'RED'}.contains(
          '${invoice['response_type'] ?? invoice['response_status']}'
              .toUpperCase(),
        );
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(
        title: Text(
          documentTypeLabel(invoice).startsWith('Belge türü')
              ? 'Belge Detayı'
              : '${documentTypeLabel(invoice)} Detayı',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InvoiceContent(
            purchase: incoming,
            partnerName:
                (incoming
                        ? invoice['sender_name'] ?? invoice['supplier_name']
                        : invoice['receiver_name'] ?? invoice['customer_name'])
                    ?.toString() ??
                'Firma bilgisi sağlanmadı',
            invoice: {
              ...invoice,
              'number':
                  invoice['invoice_number'] ??
                  invoice['document_no'] ??
                  invoice['number'],
              'gross_amount':
                  invoice['total'] ??
                  invoice['amount'] ??
                  invoice['payable_amount'] ??
                  invoice['gross_amount'],
              'issue_date': invoice['issue_date'] ?? invoice['created_at'],
              'e_document_uuid': invoice['uuid'],
            },
          ),
          if (id != null) ...[
            const SizedBox(height: 12),
            if (!incoming)
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => widget.api.refreshElectronicInvoiceStatus(
                          id,
                          isClient: widget.isClient,
                        ),
                        'Belge durumu yenilendi',
                      ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Durumu Yenile'),
              ),
            if (!incoming &&
                '${invoice['status']}'.toUpperCase() != 'CANCELLED')
              OutlinedButton.icon(
                onPressed: _busy ? null : _cancel,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Faturayı İptal Et'),
              ),
            if (canRespond)
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _busy ? null : () => _respond('KABUL'),
                    child: const Text('Kabul Et'),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _respond('RED'),
                    child: const Text('Reddet'),
                  ),
                ],
              ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: id == null
              ? const Text('Orijinal belge kimliği sağlanmadı.')
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('HTML Gör'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ElectronicDocumentPreview(
                            loader: () => widget.api.electronicInvoiceHtml(
                              id,
                              isClient: widget.isClient,
                              incoming: incoming,
                            ),
                          ),
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _saveContent('pdf'),
                      child: const Text('PDF Kaydet'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _saveContent('ubl'),
                      child: const Text('UBL Kaydet'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class ElectronicDocumentPreview extends StatefulWidget {
  const ElectronicDocumentPreview({super.key, required this.loader});
  final Future<String> Function() loader;
  @override
  State<ElectronicDocumentPreview> createState() =>
      _ElectronicDocumentPreviewState();
}

class _ElectronicDocumentPreviewState extends State<ElectronicDocumentPreview> {
  WebViewController? _controller;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _controller = null;
    });
    try {
      final html = await widget.loader();
      if (!mounted) return;
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.disabled);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              request.url.startsWith('about:') ||
                  request.url.startsWith('data:')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      );
      await controller.loadHtmlString(html);
      if (mounted) setState(() => _controller = controller);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Orijinal Fatura')),
    body: _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Belge görüntülenemedi',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: _load,
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            ),
          )
        : _controller == null
        ? const Center(child: CircularProgressIndicator())
        : WebViewWidget(controller: _controller!),
  );
}
