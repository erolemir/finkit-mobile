import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../api_client.dart';
import '../theme.dart';
import 'invoice_detail_page.dart';

class ElectronicInvoicePage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final id = incoming
        ? invoice['provider_id'] ?? invoice['id']
        : invoice['uuid'];
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('E-Fatura Detayı')),
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
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: id == null
              ? const Text('Orijinal belge kimliği sağlanmadı.')
              : FilledButton.icon(
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Orijinal Faturayı Görüntüle'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _InvoicePreview(
                        loader: () => api.electronicInvoiceHtml(
                          '$id',
                          isClient: isClient,
                          incoming: incoming,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _InvoicePreview extends StatefulWidget {
  const _InvoicePreview({required this.loader});
  final Future<String> Function() loader;
  @override
  State<_InvoicePreview> createState() => _InvoicePreviewState();
}

class _InvoicePreviewState extends State<_InvoicePreview> {
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
