import 'dart:async';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../services/app_notifications.dart';
import '../theme.dart';
import '../widgets.dart';

/// Sohbet: müşavir mükellefleriyle, mükellef müşaviriyle yazışır.
class ChatListPage extends StatefulWidget {
  const ChatListPage({
    super.key,
    required this.api,
    required this.refreshKey,
    required this.isClient,
  });

  final FinkitApi api;
  final int refreshKey;
  final bool isClient;

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  Future<List<Map<String, dynamic>>>? _future;
  StreamSubscription<Map<String, dynamic>>? _events;

  @override
  void initState() {
    super.initState();
    _load();
    _events = AppNotifications.instance.events.listen((event) {
      if (mounted && event['type'] == 'NEW_MESSAGE') setState(_load);
    });
  }

  @override
  void didUpdateWidget(covariant ChatListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _load();
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  void _load() {
    _future = () async {
      final unread = <int, int>{};
      try {
        for (final item in await widget.api.chatUnreadCounts()) {
          final id = int.tryParse('${item['sender_id'] ?? item['user_id']}');
          final count = int.tryParse('${item['count'] ?? item['unread']}') ?? 0;
          if (id != null) unread[id] = count;
        }
      } catch (_) {
        // Okunmamış sayısı alınamazsa liste yine gösterilir.
      }
      if (widget.isClient) {
        final me = await widget.api.clientProfile();
        final advisorId = int.tryParse('${me['advisor_id']}');
        return [
          {
            'id': advisorId,
            'name': me['advisor_name'] ?? 'Müşavirim',
            'subtitle': 'Müşavir ofisi',
            'unread': unread[advisorId] ?? 0,
          },
        ];
      }
      final clients = await widget.api.clients();
      return clients
          .map(
            (client) => {
              'id': client['user_id'],
              'name': client['company_title'] ?? 'Mükellef',
              'subtitle': client['user']?['full_name'] ?? '',
              'unread': unread[client['user_id']] ?? 0,
            },
          )
          .toList();
    }();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: const Text('Sohbet')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingState();
          }
          if (snapshot.hasError) {
            return _ErrorBox(
              message: snapshot.error.toString(),
              onRetry: () => setState(_load),
            );
          }
          final items = snapshot.data ?? const <Map<String, dynamic>>[];
          return RefreshIndicator(
            color: FinkitColors.ink,
            onRefresh: () async => setState(_load),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                const PageTitle(
                  title: 'Sohbet',
                  subtitle: 'Mükellef ve müşavir yazışmalarınız.',
                ),
                if (items.isEmpty)
                  const EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Sohbet yok',
                    description: 'Yazışacak bir kişi bulunmuyor.',
                  )
                else
                  ...items.map((item) {
                    final unread = int.tryParse('${item['unread'] ?? 0}') ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DataRowCard(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: item['name']?.toString() ?? 'Kişi',
                        subtitle: item['subtitle']?.toString() ?? '',
                        value: unread > 0 ? '$unread yeni' : '',
                        valueSubtitle: unread > 0 ? 'okunmamış' : '',
                        onTap: () {
                          final id = int.tryParse('${item['id']}');
                          if (id == null) return;
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ChatThreadPage(
                                    api: widget.api,
                                    otherUserId: id,
                                    title: item['name']?.toString() ?? 'Sohbet',
                                  ),
                                ),
                              )
                              .then((_) => setState(_load));
                        },
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Tek bir kişiyle yazışma ekranı.
class ChatThreadPage extends StatefulWidget {
  const ChatThreadPage({
    super.key,
    required this.api,
    required this.otherUserId,
    required this.title,
  });

  final FinkitApi api;
  final int otherUserId;
  final String title;

  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<ChatThreadPage> {
  final TextEditingController _message = TextEditingController();
  final ScrollController _scroll = ScrollController();
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;
  StreamSubscription<Map<String, dynamic>>? _events;

  @override
  void initState() {
    super.initState();
    _load();
    _events = AppNotifications.instance.events.listen((event) {
      if (event['type'] == 'NEW_MESSAGE') _load(silent: true);
    });
  }

  @override
  void dispose() {
    _events?.cancel();
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final items = await widget.api.chatHistory(widget.otherUserId);
      await widget.api.markChatRead(widget.otherUserId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) _error = error.toString();
      });
    }
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    _message.clear();
    try {
      await widget.api.sendChatMessage(
        receiverId: widget.otherUserId,
        content: text,
      );
      await _load(silent: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = AppNotifications.instance.currentUserId;
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const LoadingState()
                : _error != null
                ? _ErrorBox(message: _error!, onRetry: _load)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final mine =
                          myId != null &&
                          int.tryParse('${item['sender_id']}') == myId;
                      return _MessageBubble(
                        mine: mine,
                        text: item['content']?.toString() ?? '',
                        time: dateText(item['created_at']),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _message,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Bir mesaj yazın…',
                        prefixIcon: Icon(Icons.edit_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    style: IconButton.styleFrom(
                      backgroundColor: FinkitColors.ink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(14),
                    ),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.mine,
    required this.text,
    required this.time,
  });

  final bool mine;
  final String text;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        decoration: BoxDecoration(
          color: mine ? FinkitColors.ink : FinkitColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: mine ? Colors.transparent : FinkitColors.line,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: mine ? Colors.white : FinkitColors.text,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                color: mine ? Colors.white70 : FinkitColors.mutedLight,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: FinkitColors.muted),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: FinkitColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      ),
    );
  }
}
