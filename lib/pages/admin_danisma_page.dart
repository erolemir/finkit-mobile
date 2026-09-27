import 'package:flutter/material.dart';

import '../api_client.dart';
import '../widgets.dart';

class AdminDanismaPage extends StatefulWidget {
  const AdminDanismaPage({super.key, required this.api});

  final FinkitApi api;

  @override
  State<AdminDanismaPage> createState() => _AdminDanismaPageState();
}

class _AdminDanismaPageState extends State<AdminDanismaPage> {
  final _search = TextEditingController();
  late Future<Map<String, dynamic>> _questions;
  late Future<Map<String, dynamic>> _feedback;
  late Future<Map<String, dynamic>> _stats;
  int _tab = 0;
  int _questionPage = 1;
  int _feedbackPage = 1;
  String _feedbackType = '';
  String _refundStatus = '';
  bool _deciding = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _loadAll() {
    _loadQuestions();
    _loadFeedback();
    _stats = widget.api.adminDanismaStats();
  }

  void _loadQuestions() {
    _questions = widget.api.adminDanismaQuestionPage(
      page: _questionPage,
      search: _search.text.trim(),
    );
  }

  void _loadFeedback() {
    _feedback = widget.api.adminDanismaFeedback(
      page: _feedbackPage,
      feedbackType: _feedbackType,
      refundStatus: _refundStatus,
    );
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic>? body) =>
      (body?['items'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

  void _showQuestion(Map<String, dynamic> question) {
    final answers = (question['answers'] as List? ?? const []).whereType<Map>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              '${question['title'] ?? 'Soru'}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${question['client_name'] ?? ''} · ${question['category_name'] ?? ''}',
            ),
            const SizedBox(height: 12),
            SelectableText('${question['content'] ?? ''}'),
            const Divider(),
            Text(
              'Yanıtlar (${question['answer_count'] ?? answers.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (answers.isEmpty) const Text('Henüz yanıt yok.'),
            for (final answer in answers)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${answer['advisor_name'] ?? 'Müşavir'} · ${moneyText(answer['price'])} · ${answer['is_paid'] == true ? 'Ödendi' : 'Ödenmedi'}',
                      ),
                      const SizedBox(height: 6),
                      SelectableText('${answer['content'] ?? ''}'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _decide(Map<String, dynamic> row, String decision) async {
    if (_deciding) return;
    var note = '';
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(decision == 'approved' ? 'İadeyi onayla' : 'İadeyi reddet'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${row['client_name'] ?? ''} · ${moneyText(row['amount'])}'),
              Text('${row['question_title'] ?? ''}'),
              if ('${row['comment'] ?? ''}'.isNotEmpty)
                Text('Geri bildirim: ${row['comment']}'),
              TextField(
                onChanged: (value) => note = value,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Yönetici notu (isteğe bağlı)',
                ),
              ),
            ],
          ),
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
    if (approved != true || !mounted) return;
    setState(() => _deciding = true);
    try {
      await widget.api.adminDanismaRefundDecision(
        (row['id'] as num).toInt(),
        decision: decision,
        note: note.trim(),
      );
      if (mounted) {
        setState(() {
          _loadFeedback();
          _stats = widget.api.adminDanismaStats();
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Karar kaydedilemedi: $error')));
      }
    } finally {
      if (mounted) setState(() => _deciding = false);
    }
  }

  Widget _paging(int page, int total, void Function(int) change, String unit) =>
      total > 20 || page > 1
      ? Row(
          children: [
            IconButton(
              tooltip: 'Önceki sayfa',
              onPressed: page <= 1 ? null : () => change(page - 1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text('$page · $total $unit', textAlign: TextAlign.center),
            ),
            IconButton(
              tooltip: 'Sonraki sayfa',
              onPressed: page * 20 >= total ? null : () => change(page + 1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        )
      : const SizedBox.shrink();

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async => setState(_loadAll),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        const PageTitle(
          title: 'Danışmanlık Yönetimi',
          subtitle: 'Soru, yanıt, istatistik ve geri bildirimler',
        ),
        Wrap(
          spacing: 6,
          children: [
            for (final pair in [
              ('Sorular', 0),
              ('İstatistikler', 1),
              ('Geri bildirimler', 2),
            ])
              ChoiceChip(
                label: Text(pair.$1),
                selected: _tab == pair.$2,
                onSelected: (_) => setState(() => _tab = pair.$2),
              ),
          ],
        ),
        if (_tab == 0) ...[
          TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: 'Soru ara',
              suffixIcon: IconButton(
                tooltip: 'Ara',
                icon: const Icon(Icons.search),
                onPressed: () => setState(() {
                  _questionPage = 1;
                  _loadQuestions();
                }),
              ),
            ),
            onSubmitted: (_) => setState(() {
              _questionPage = 1;
              _loadQuestions();
            }),
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: _questions,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return TextButton(
                  onPressed: () => setState(_loadQuestions),
                  child: Text('Sorular alınamadı: ${snapshot.error}'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = _items(snapshot.data);
              final total =
                  int.tryParse('${snapshot.data?['total']}') ?? items.length;
              return Column(
                children: [
                  if (items.isEmpty)
                    const EmptyState(
                      icon: Icons.question_answer_outlined,
                      title: 'Soru yok',
                      description: 'Bu aramada soru bulunamadı.',
                    ),
                  for (final question in items)
                    Card(
                      child: ListTile(
                        title: Text('${question['title'] ?? 'Soru'}'),
                        subtitle: Text(
                          '${question['client_name'] ?? ''} · ${question['answer_count'] ?? 0} yanıt · ${question['view_count'] ?? 0} görüntüleme',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showQuestion(question),
                      ),
                    ),
                  _paging(
                    _questionPage,
                    total,
                    (value) => setState(() {
                      _questionPage = value;
                      _loadQuestions();
                    }),
                    'soru',
                  ),
                ],
              );
            },
          ),
        ],
        if (_tab == 1)
          FutureBuilder<Map<String, dynamic>>(
            future: _stats,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return TextButton(
                  onPressed: () =>
                      setState(() => _stats = widget.api.adminDanismaStats()),
                  child: Text('İstatistikler alınamadı: ${snapshot.error}'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data!;
              final questions = num.tryParse('${data['total_questions']}') ?? 0;
              final answers = num.tryParse('${data['total_answers']}') ?? 0;
              final paid = num.tryParse('${data['paid_answers']}') ?? 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final pair in [
                    ('Toplam soru', 'total_questions'),
                    ('Toplam yanıt', 'total_answers'),
                    ('Ödenen yanıt', 'paid_answers'),
                    ('Toplam gelir', 'total_revenue'),
                    ('Bekleyen iade', 'pending_refunds'),
                  ])
                    Card(
                      child: ListTile(
                        title: Text(pair.$1),
                        trailing: Text('${data[pair.$2] ?? 0}'),
                      ),
                    ),
                  Card(
                    child: ListTile(
                      title: const Text('Yanıt oranı'),
                      trailing: Text(
                        questions == 0
                            ? '%0'
                            : '%${(answers / questions * 100).toStringAsFixed(1)}',
                      ),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      title: const Text('Ödeme oranı'),
                      trailing: Text(
                        answers == 0
                            ? '%0'
                            : '%${(paid / answers * 100).toStringAsFixed(1)}',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        if (_tab == 2) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _feedbackType,
            decoration: const InputDecoration(labelText: 'Geri bildirim türü'),
            items: const [
              DropdownMenuItem(value: '', child: Text('Tümü')),
              DropdownMenuItem(value: 'helpful', child: Text('İşe yaradı')),
              DropdownMenuItem(value: 'irrelevant', child: Text('Alakasız')),
              DropdownMenuItem(value: 'incomplete', child: Text('Eksik')),
              DropdownMenuItem(value: 'wrong', child: Text('Yanlış')),
            ],
            onChanged: (value) => setState(() {
              _feedbackType = value ?? '';
              _feedbackPage = 1;
              _loadFeedback();
            }),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _refundStatus,
            decoration: const InputDecoration(labelText: 'İade durumu'),
            items: const [
              DropdownMenuItem(value: '', child: Text('Tümü')),
              DropdownMenuItem(value: 'none', child: Text('Yok')),
              DropdownMenuItem(value: 'pending', child: Text('Bekliyor')),
              DropdownMenuItem(value: 'approved', child: Text('Onaylandı')),
              DropdownMenuItem(value: 'rejected', child: Text('Reddedildi')),
            ],
            onChanged: (value) => setState(() {
              _refundStatus = value ?? '';
              _feedbackPage = 1;
              _loadFeedback();
            }),
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: _feedback,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return TextButton(
                  onPressed: () => setState(_loadFeedback),
                  child: Text('Geri bildirimler alınamadı: ${snapshot.error}'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = _items(snapshot.data);
              final total =
                  int.tryParse('${snapshot.data?['total']}') ?? items.length;
              return Column(
                children: [
                  if (items.isEmpty)
                    const EmptyState(
                      icon: Icons.feedback_outlined,
                      title: 'Geri bildirim yok',
                      description: 'Seçili filtrelerde kayıt bulunamadı.',
                    ),
                  for (final row in items)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${row['question_title'] ?? 'Soru'}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${row['client_name'] ?? ''} · ${row['feedback_type'] ?? ''} · ${row['refund_status'] ?? ''}',
                            ),
                            Text(moneyText(row['amount'])),
                            if ('${row['comment'] ?? ''}'.isNotEmpty)
                              Text('${row['comment']}'),
                            if (row['refund_status'] == 'pending')
                              Wrap(
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: _deciding
                                        ? null
                                        : () => _decide(row, 'approved'),
                                    child: const Text('İadeyi onayla'),
                                  ),
                                  TextButton(
                                    onPressed: _deciding
                                        ? null
                                        : () => _decide(row, 'rejected'),
                                    child: const Text('İadeyi reddet'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  _paging(
                    _feedbackPage,
                    total,
                    (value) => setState(() {
                      _feedbackPage = value;
                      _loadFeedback();
                    }),
                    'geri bildirim',
                  ),
                ],
              );
            },
          ),
        ],
      ],
    ),
  );
}
