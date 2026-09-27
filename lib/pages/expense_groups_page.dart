import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';
import 'accounting_attachments_page.dart';
import 'accounting_pages.dart';
import 'invoice_detail_page.dart';

/// Invoice based income/expense grouping uses the same endpoint as the web UI.
class ExpenseGroupsPage extends StatefulWidget {
  const ExpenseGroupsPage({
    super.key,
    required this.api,
    required this.refreshKey,
  });

  final FinkitApi api;
  final int refreshKey;

  @override
  State<ExpenseGroupsPage> createState() => _ExpenseGroupsPageState();
}

class _ExpenseGroupsPageState extends State<ExpenseGroupsPage> {
  final _search = TextEditingController();
  late Future<Map<String, dynamic>> _groups;
  late Future<Map<String, dynamic>> _income;
  late Future<Map<String, dynamic>> _summary;
  late Future<List<Map<String, dynamic>>> _categories;
  late Future<List<Map<String, dynamic>>> _accounts;
  String _status = '';
  int? _categoryId;
  DateTime? _start;
  DateTime? _end;
  int _page = 1;
  int _incomePage = 1;
  String _basis = 'accrual';

  @override
  void initState() {
    super.initState();
    _categories = widget.api.expenseCategories();
    _accounts = widget.api.accounts();
    _load();
  }

  @override
  void didUpdateWidget(covariant ExpenseGroupsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _date(DateTime? value) => value == null
      ? ''
      : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  List<({int id, String label})> _attachmentRecords(
    List<Map<String, dynamic>> groups,
  ) {
    final records = <({int id, String label})>[];
    for (final group in groups) {
      for (final raw in (group['items'] as List? ?? const [])) {
        if (raw is! Map) continue;
        final id = int.tryParse('${raw['id']}');
        if (id == null) continue;
        records.add((
          id: id,
          label:
              '${dateText(raw['expense_date'])} · ${raw['description'] ?? 'Gider'}',
        ));
      }
    }
    return records;
  }

  void _load() {
    final today = DateTime.now();
    final startDate = _start == null ? null : _date(_start);
    final endDate = _end == null ? null : _date(_end);
    _groups = widget.api.groupedExpenses(
      page: _page,
      search: _search.text.trim(),
      paymentStatus: _status,
      startDate: startDate,
      endDate: endDate,
      categoryId: _categoryId,
    );
    _income = widget.api.incomeInvoiceGroups(
      page: _incomePage,
      search: _search.text.trim(),
      paymentStatus: _status,
      startDate: startDate,
      endDate: endDate,
    );
    _summary = widget.api.report(
      'income-expense',
      basis: _basis,
      startDate: startDate ?? _date(DateTime(today.year, today.month)),
      endDate: endDate ?? _date(today),
    );
  }

  void _reload({bool firstPage = false}) => setState(() {
    if (firstPage) {
      _page = 1;
      _incomePage = 1;
    }
    _load();
  });

  Future<void> _chooseDate(bool start) async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: (start ? _start : _end) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (chosen == null) return;
    setState(() {
      if (start) {
        _start = chosen;
      } else {
        _end = chosen;
      }
      _page = 1;
      _incomePage = 1;
      _load();
    });
  }

  Future<void> _delete(Map<String, dynamic> expense) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gideri Sil'),
        content: const Text(
          'Gider ve bağlı kasa/banka hareketi geri alınacak. Devam edilsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    try {
      await widget.api.deleteExpenseRecord(int.parse('${expense['id']}'));
      _reload();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _openForm([Map<String, dynamic>? expense]) async {
    final categories = await _categories;
    final accounts = await _accounts;
    if (!mounted) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ExpenseForm(
        api: widget.api,
        expense: expense,
        categories: categories,
        accounts: accounts,
      ),
    );
    if (saved == true && mounted) _reload();
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<List<Map<String, dynamic>>>>(
    future: Future.wait([_categories, _accounts]),
    builder: (context, lookups) => FutureBuilder<Map<String, dynamic>>(
      future: _groups,
      builder: (context, snapshot) {
        final groups = (snapshot.data?['items'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        final categories =
            lookups.data?.first ?? const <Map<String, dynamic>>[];
        final total = int.tryParse('${snapshot.data?['total']}') ?? 0;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              const SectionHeader(title: 'Gelir ve Gider Özeti'),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Tahakkuk'),
                    selected: _basis == 'accrual',
                    onSelected: (_) => setState(() {
                      _basis = 'accrual';
                      _load();
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Nakit'),
                    selected: _basis == 'cash',
                    onSelected: (_) => setState(() {
                      _basis = 'cash';
                      _load();
                    }),
                  ),
                ],
              ),
              FutureBuilder<Map<String, dynamic>>(
                future: _summary,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LoadingState();
                  }
                  if (snapshot.hasError) {
                    return TextButton(
                      onPressed: _reload,
                      child: Text(
                        'Özet alınamadı: ${snapshot.error} · Tekrar dene',
                      ),
                    );
                  }
                  final summary = snapshot.data?['summary'];
                  if (summary is! Map) return const SizedBox.shrink();
                  final labels = _basis == 'cash'
                      ? const {
                          'cash_in': 'Nakit girişi',
                          'cash_out': 'Nakit çıkışı',
                          'net_cash_result': 'Net nakit sonucu',
                        }
                      : const {
                          'sales_gross': 'Satış toplamı',
                          'expense_total': 'Gider toplamı',
                          'net_result': 'Net sonuç',
                        };
                  return Column(
                    children: [
                      for (final entry in labels.entries)
                        Card(
                          child: ListTile(
                            title: Text(entry.value),
                            trailing: Text(moneyText(summary[entry.key])),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SectionHeader(title: 'Gider Listesi'),
              PageTitle(
                title: 'Gelir ve Giderler',
                subtitle: 'Fatura kalemleri, manuel giderler ve ödeme durumu',
                trailing: IconButton.filled(
                  tooltip: 'Yeni Gider',
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'Açıklama veya belge numarası ara',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onSubmitted: (_) => _reload(firstPage: true),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  DropdownButton<String>(
                    value: _status,
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Tüm ödemeler')),
                      DropdownMenuItem(
                        value: 'UNPAID',
                        child: Text('Ödenmedi'),
                      ),
                      DropdownMenuItem(value: 'PARTIAL', child: Text('Kısmi')),
                      DropdownMenuItem(value: 'PAID', child: Text('Ödendi')),
                      DropdownMenuItem(
                        value: 'OVERDUE',
                        child: Text('Gecikti'),
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      _status = value ?? '';
                      _page = 1;
                      _incomePage = 1;
                      _load();
                    }),
                  ),
                  DropdownButton<int?>(
                    value: _categoryId,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Tüm kategoriler'),
                      ),
                      for (final category in categories)
                        DropdownMenuItem(
                          value: int.tryParse('${category['id']}'),
                          child: Text('${category['name']}'),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _categoryId = value;
                      _page = 1;
                      _incomePage = 1;
                      _load();
                    }),
                  ),
                  TextButton(
                    onPressed: () => _chooseDate(true),
                    child: Text(_start == null ? 'Başlangıç' : _date(_start)),
                  ),
                  TextButton(
                    onPressed: () => _chooseDate(false),
                    child: Text(_end == null ? 'Bitiş' : _date(_end)),
                  ),
                  if (_start != null || _end != null)
                    IconButton(
                      tooltip: 'Tarihleri temizle',
                      onPressed: () => setState(() {
                        _start = null;
                        _end = null;
                        _page = 1;
                        _incomePage = 1;
                        _load();
                      }),
                      icon: const Icon(Icons.clear_rounded),
                    ),
                ],
              ),
              if (snapshot.connectionState != ConnectionState.done)
                const LoadingState()
              else if (snapshot.hasError)
                Center(
                  child: TextButton(
                    onPressed: _reload,
                    child: Text('Yüklenemedi: ${snapshot.error} · Tekrar dene'),
                  ),
                )
              else if (groups.isEmpty)
                const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Gider kaydı yok',
                  description: 'Bu filtrelerde kayıt bulunamadı.',
                )
              else
                for (final group in groups) _groupCard(group, categories),
              if (total > 50)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$total kayıt · Sayfa $_page'),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _page > 1
                              ? () => setState(() {
                                  _page--;
                                  _load();
                                })
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        IconButton(
                          onPressed: _page < (total / 50).ceil()
                              ? () => setState(() {
                                  _page++;
                                  _load();
                                })
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              const SectionHeader(title: 'Gelir Faturaları'),
              FutureBuilder<Map<String, dynamic>>(
                future: _income,
                builder: (context, incomeSnapshot) {
                  if (incomeSnapshot.connectionState != ConnectionState.done) {
                    return const LoadingState();
                  }
                  if (incomeSnapshot.hasError) {
                    return TextButton(
                      onPressed: _reload,
                      child: Text(
                        'Gelir faturaları alınamadı: ${incomeSnapshot.error} · Tekrar dene',
                      ),
                    );
                  }
                  final invoices =
                      (incomeSnapshot.data?['items'] as List? ?? const [])
                          .whereType<Map>()
                          .map((item) => Map<String, dynamic>.from(item))
                          .toList();
                  final incomeTotal =
                      int.tryParse('${incomeSnapshot.data?['total']}') ??
                      invoices.length;
                  return Column(
                    children: [
                      if (invoices.isEmpty)
                        const EmptyState(
                          icon: Icons.receipt_outlined,
                          title: 'Gelir faturası yok',
                          description: 'Seçilen filtrelerde kesinleşmiş satış faturası bulunamadı.',
                        ),
                      for (final invoice in invoices) _incomeCard(invoice),
                      if (incomeTotal > 50)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('$incomeTotal fatura · Sayfa $_incomePage'),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: _incomePage > 1
                                      ? () => setState(() {
                                          _incomePage--;
                                          _load();
                                        })
                                      : null,
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                IconButton(
                                  onPressed:
                                      _incomePage < (incomeTotal / 50).ceil()
                                      ? () => setState(() {
                                          _incomePage++;
                                          _load();
                                        })
                                      : null,
                                  icon: const Icon(Icons.chevron_right),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              AccountingAttachmentsPanel(
                api: widget.api,
                relatedType: 'expense',
                records: _attachmentRecords(groups),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _groupCard(
    Map<String, dynamic> group,
    List<Map<String, dynamic>> categories,
  ) {
    final invoiceId = int.tryParse('${group['purchase_invoice_id']}');
    final lines = (group['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final paid = double.tryParse('${group['paid_amount']}') ?? 0;
    final status = '${group['payment_status'] ?? 'UNPAID'}';
    final paymentLabel = invoiceId != null
        ? status == 'PAID'
              ? 'Fatura ödendi'
              : paid > 0
              ? 'Kısmi ödendi'
              : 'Fatura ödenmedi'
        : statusLabel(status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SurfaceCard(
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            invoiceId != null
                ? 'Fatura ${group['document_no'] ?? '#$invoiceId'}'
                : group['document_no'] == null
                ? 'Manuel gider'
                : 'Manuel · ${group['document_no']}',
          ),
          subtitle: Text(
            '${dateText(group['expense_date'])} · ${lines.length} kalem · $paymentLabel',
          ),
          trailing: Text(
            moneyText(group['total_amount']),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          children: [
            for (final line in lines)
              ListTile(
                dense: true,
                title: Text('${line['description']}'),
                subtitle: Text(
                  '${categories.where((category) => category['id'] == line['category_id']).firstOrNull?['name'] ?? 'Genel'} · KDV ${moneyText(line['vat_amount'])}',
                ),
                trailing: Text(moneyText(line['total_amount'])),
              ),
            if (invoiceId != null)
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () async {
                      final invoice = await widget.api.purchaseInvoice(
                        invoiceId,
                      );
                      if (mounted)
                        await openInvoiceDetail(
                          context,
                          widget.api,
                          invoice,
                          purchase: true,
                        );
                      if (mounted) _reload();
                    },
                    child: const Text('Faturayı Aç'),
                  ),
                  if (status != 'PAID')
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: const Text('Ödemeler')),
                            body: SupplierPaymentsPage(
                              api: widget.api,
                              refreshKey: widget.refreshKey,
                            ),
                          ),
                        ),
                      ),
                      child: const Text('Ödeme Gir'),
                    ),
                ],
              )
            else if (lines.isNotEmpty && lines.first['source_type'] == 'MANUAL') ...[
              TextButton(
                onPressed: () => _openForm(lines.first),
                child: const Text('Düzenle'),
              ),
              TextButton(
                onPressed: () => _delete(lines.first),
                child: const Text('Sil'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _incomeCard(Map<String, dynamic> invoice) {
    final id = int.tryParse('${invoice['id']}');
    final isReturn = '${invoice['invoice_type']}'.toUpperCase() == 'IADE';
    final gross = double.tryParse('${invoice['gross_amount']}') ?? 0;
    final paid = double.tryParse('${invoice['paid_amount']}') ?? 0;
    final status = '${invoice['payment_status'] ?? 'UNPAID'}';
    final lines = (invoice['lines'] as List? ?? const [])
        .whereType<Map>()
        .map((line) => Map<String, dynamic>.from(line))
        .toList();
    return Card(
      child: ExpansionTile(
        title: Text(
          '${invoice['number'] ?? 'Fatura #${id ?? ''}'}${isReturn ? ' · İade' : ''}',
        ),
        subtitle: Text(
          '${dateText(invoice['issue_date'])} · ${lines.length} kalem · '
          '${status == 'PAID'
              ? 'Tahsil edildi'
              : paid > 0
              ? 'Kısmi tahsilat'
              : 'Tahsil edilmedi'}',
        ),
        trailing: Text(
          moneyText(isReturn ? -gross : gross),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        children: [
          for (final line in lines)
            ListTile(
              dense: true,
              title: Text('${line['description'] ?? 'Kalem'}'),
              subtitle: Text(
                '${line['quantity'] ?? ''} ${line['unit'] ?? ''} · '
                'KDV ${moneyText((double.tryParse('${line['line_vat']}') ?? 0) * (isReturn ? -1 : 1))}',
              ),
              trailing: Text(
                moneyText(
                  (double.tryParse('${line['line_total']}') ?? 0) *
                      (isReturn ? -1 : 1),
                ),
              ),
            ),
          if (id != null)
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () async {
                    try {
                      final full = await widget.api.salesInvoice(id);
                      if (mounted) {
                        await openInvoiceDetail(context, widget.api, full);
                      }
                    } catch (error) {
                      if (mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('$error')));
                      }
                    }
                  },
                  child: const Text('Faturayı Aç'),
                ),
                if (status != 'PAID')
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Tahsilatlar')),
                          body: CollectionsPage(
                            api: widget.api,
                            refreshKey: widget.refreshKey,
                          ),
                        ),
                      ),
                    ),
                    child: const Text('Tahsilat Gir'),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm({
    required this.api,
    required this.categories,
    required this.accounts,
    this.expense,
  });

  final FinkitApi api;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> accounts;
  final Map<String, dynamic>? expense;

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _documentNo;
  late final TextEditingController _gross;
  late final TextEditingController _vatRate;
  late DateTime _date;
  DateTime? _dueDate;
  int? _categoryId;
  int? _accountId;
  String _status = 'UNPAID';
  String _method = 'HAVALE';
  bool _saving = false;

  bool get _locked => widget.expense?['payment_status'] == 'PAID';

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _description = TextEditingController(
      text: '${expense?['description'] ?? ''}',
    );
    _documentNo = TextEditingController(
      text: '${expense?['document_no'] ?? ''}',
    );
    _gross = TextEditingController(text: '${expense?['total_amount'] ?? ''}');
    _vatRate = TextEditingController(text: '${expense?['vat_rate'] ?? 20}');
    _date =
        DateTime.tryParse('${expense?['expense_date'] ?? ''}') ??
        DateTime.now();
    _dueDate = DateTime.tryParse('${expense?['due_date'] ?? ''}');
    _categoryId = int.tryParse('${expense?['category_id']}');
  }

  @override
  void dispose() {
    _description.dispose();
    _documentNo.dispose();
    _gross.dispose();
    _vatRate.dispose();
    super.dispose();
  }

  String _dateString(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool due) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: due ? _dueDate ?? DateTime.now() : _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null)
      setState(() {
        if (due) {
          _dueDate = selected;
        } else {
          _date = selected;
        }
      });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final gross = double.parse(_gross.text.replaceAll(',', '.'));
    final rate = double.parse(_vatRate.text.replaceAll(',', '.'));
    final net = (gross / (1 + rate / 100) * 100).round() / 100;
    setState(() => _saving = true);
    try {
      final common = <String, dynamic>{
        'description': _description.text.trim(),
        'category_id': _categoryId,
      };
      final financial = <String, dynamic>{
        'expense_date': _dateString(_date),
        'document_no': _documentNo.text.trim().isEmpty
            ? null
            : _documentNo.text.trim(),
        'gross_amount': gross,
        'net_amount': net,
        'vat_rate': rate,
        'due_date': _dueDate == null ? null : _dateString(_dueDate!),
      };
      if (widget.expense case final expense?) {
        await widget.api.updateExpenseRecord(int.parse('${expense['id']}'), {
          ...common,
          if (!_locked) ...financial,
        });
      } else {
        await widget.api.createExpenseRecord({
          ...common,
          ...financial,
          'currency': 'TRY',
          'exchange_rate': 1,
          'payment_status': _status,
          if (_status == 'PAID') ...{
            'payment_method': _method,
            'financial_account_id': _accountId,
          },
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gross = double.tryParse(_gross.text.replaceAll(',', '.')) ?? 0;
    final rate = double.tryParse(_vatRate.text.replaceAll(',', '.')) ?? 0;
    final net = (gross / (1 + rate / 100) * 100).round() / 100;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.expense == null ? 'Yeni Gider' : 'Gideri Düzenle',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Açıklama'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Açıklama gerekli'
                      : null,
                ),
                TextFormField(
                  controller: _documentNo,
                  enabled: !_locked,
                  decoration: const InputDecoration(labelText: 'Belge No'),
                ),
                DropdownButtonFormField<int?>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Genel')),
                    for (final item in widget.categories)
                      DropdownMenuItem(
                        value: int.tryParse('${item['id']}'),
                        child: Text('${item['name']}'),
                      ),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
                TextButton(
                  onPressed: _locked ? null : () => _pickDate(false),
                  child: Text('Tarih: ${_dateString(_date)}'),
                ),
                TextFormField(
                  controller: _gross,
                  enabled: !_locked,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'KDV Dahil Tutar',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) =>
                      (double.tryParse((value ?? '').replaceAll(',', '.')) ??
                              -1) <
                          0
                      ? 'Geçerli tutar girin'
                      : null,
                ),
                TextFormField(
                  controller: _vatRate,
                  enabled: !_locked,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'KDV Oranı %'),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    final n = double.tryParse(
                      (value ?? '').replaceAll(',', '.'),
                    );
                    return n == null || n < 0 || n > 100
                        ? '0–100 arası oran girin'
                        : null;
                  },
                ),
                Text(
                  'Net ${moneyText(net)} · KDV ${moneyText(gross - net)} · Toplam ${moneyText(gross)}',
                ),
                TextButton(
                  onPressed: _locked ? null : () => _pickDate(true),
                  child: Text(
                    _dueDate == null
                        ? 'Vade seç'
                        : 'Vade: ${_dateString(_dueDate!)}',
                  ),
                ),
                if (widget.expense == null) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Ödeme Durumu',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'UNPAID',
                        child: Text('Ödenmedi'),
                      ),
                      DropdownMenuItem(value: 'PAID', child: Text('Ödendi')),
                    ],
                    onChanged: (value) =>
                        setState(() => _status = value ?? 'UNPAID'),
                  ),
                  if (_status == 'PAID') ...[
                    DropdownButtonFormField<String>(
                      initialValue: _method,
                      decoration: const InputDecoration(
                        labelText: 'Ödeme Yöntemi',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'HAVALE',
                          child: Text('Havale / EFT'),
                        ),
                        DropdownMenuItem(value: 'NAKIT', child: Text('Nakit')),
                        DropdownMenuItem(
                          value: 'KREDI_KARTI',
                          child: Text('Kredi Kartı'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _method = value ?? 'HAVALE'),
                    ),
                    DropdownButtonFormField<int?>(
                      initialValue: _accountId,
                      decoration: const InputDecoration(
                        labelText: 'Kasa / Banka',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Seçin'),
                        ),
                        for (final account in widget.accounts)
                          DropdownMenuItem(
                            value: int.tryParse('${account['id']}'),
                            child: Text('${account['name']}'),
                          ),
                      ],
                      onChanged: (value) => setState(() => _accountId = value),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
