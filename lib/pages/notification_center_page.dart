import 'dart:async';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../services/app_notifications.dart';
import '../theme.dart';
import '../widgets.dart';
import 'api_list_page.dart';
import 'data_pages.dart';

/// Bildirim merkezi: sunucudaki tüm bildirimleri listeler, okundu işaretler.
class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({
    super.key,
    required this.api,
    required this.refreshKey,
  });

  final FinkitApi api;
  final int refreshKey;

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  int _localRefresh = 0;
  StreamSubscription<Map<String, dynamic>>? _events;

  @override
  void initState() {
    super.initState();
    _events = AppNotifications.instance.events.listen((_) {
      if (mounted) setState(() => _localRefresh++);
    });
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  Future<void> _markAllRead() async {
    try {
      await widget.api.markAllNotificationsRead();
      if (!mounted) return;
      setState(() => _localRefresh++);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tüm bildirimler okundu olarak işaretlendi'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FinkitColors.canvas,
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          IconButton(
            onPressed: _markAllRead,
            tooltip: 'Tümünü okundu işaretle',
            icon: const Icon(Icons.done_all_rounded),
          ),
        ],
      ),
      body: ApiListPage(
        title: 'Bildirimler',
        subtitle: 'Ödeme, tahsilat, hatırlatıcı ve belge olayları.',
        refreshKey: widget.refreshKey + _localRefresh,
        loader: widget.api.notifications,
        emptyIcon: Icons.notifications_none_rounded,
        emptyTitle: 'Bildirim yok',
        emptyDescription: 'Yeni bir olay olduğunda burada görünecek.',
        summaryBuilder: (items) {
          final unread = items.where((item) => item['is_read'] != true).length;
          return SummaryGrid(
            items: [
              SummaryItem(
                'Okunmamış',
                '$unread',
                Icons.mark_email_unread_outlined,
              ),
              SummaryItem('Toplam', '${items.length}', Icons.inbox_outlined),
            ],
          );
        },
        itemBuilder: (context, item) => _NotificationCard(
          item: item,
          onTap: () async {
            if (item['is_read'] == true) return;
            final id = int.tryParse('${item['id']}');
            if (id == null) return;
            try {
              await widget.api.markNotificationRead(id);
              if (mounted) setState(() => _localRefresh++);
            } catch (_) {
              // Okundu işaretlenemezse liste yenilenince tekrar denenir.
            }
          },
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRead = item['is_read'] == true;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isRead ? FinkitColors.surface : const Color(0xFFEFF4FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isRead ? FinkitColors.line : const Color(0xFFD6E2FF),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: FinkitColors.ink,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                _iconFor(item['type']?.toString()),
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['title']?.toString() ?? 'Bildirim',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: FinkitColors.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['message']?.toString() ?? '',
                    style: const TextStyle(
                      color: FinkitColors.muted,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dateText(item['created_at']),
                    style: const TextStyle(
                      color: FinkitColors.mutedLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String? type) {
    switch (type?.toUpperCase()) {
      case 'PAYMENT':
      case 'PAYMENT_RECEIVED':
      case 'TAHSILAT':
        return Icons.payments_outlined;
      case 'DOCUMENT':
      case 'DOCUMENT_UPLOADED':
        return Icons.description_outlined;
      case 'REMINDER':
      case 'CALENDAR':
        return Icons.alarm_rounded;
      case 'MESSAGE':
      case 'CHAT':
        return Icons.chat_bubble_outline_rounded;
      case 'SYSTEM':
      case 'ANNOUNCEMENT':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }
}
