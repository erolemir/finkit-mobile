import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/platform_pages.dart';
import 'package:finkit_mobile/pages/calendar_templates_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class CalendarApi extends FinkitApi {
  int loads = 0;
  Map<String, dynamic>? created;
  bool failGib = false;
  String? lastStartDate;
  final templates = <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> calendarEvents() async {
    loads++;
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> eventTemplates() async => templates;

  @override
  Future<List<Map<String, dynamic>>> clients() async => [];

  @override
  Future<Map<String, dynamic>> clientProfile() async => {
    'company_title': 'Örnek Ltd.',
    'payment_due_day': 15,
    'payment_status': 'PENDING',
  };

  @override
  Future<Map<String, dynamic>> createEventTemplate({
    required String title,
    required int daysOffset,
    String? description,
    String eventType = 'CLIENT',
  }) async {
    final item = {
      'id': templates.length + 1,
      'title': title,
      'days_offset': daysOffset,
      'description': description,
      'event_type': eventType,
    };
    templates.add(item);
    return item;
  }

  @override
  Future<void> deleteEventTemplate(int templateId) async {
    templates.removeWhere((item) => item['id'] == templateId);
  }

  @override
  Future<List<Map<String, dynamic>>> gibTaxCalendar({
    required String startDate,
    required String endDate,
  }) async {
    lastStartDate = startDate;
    if (failGib) throw ApiException('GİB erişilemiyor');
    final now = DateTime.now();
    final stopDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-28';
    return [
      {
        'id': 19,
        'title': 'Vergi beyanı',
        'stopdate': stopDate,
        'description': 'Beyanname son günü',
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> createCalendarEvent({
    required String title,
    required String eventDate,
    String? description,
    String eventType = 'PERSONAL',
    int? targetClientId,
    int? targetExternalClientId,
    bool isNotificationActive = true,
  }) async {
    created = {
      'title': title,
      'event_date': eventDate,
      'event_type': eventType,
      'is_notification_active': isNotificationActive,
    };
    return {'id': 25};
  }
}

class AdvisorCalendarApi extends CalendarApi {
  Map<String, dynamic>? updated;

  @override
  Future<List<Map<String, dynamic>>> calendarEvents() async {
    final now = DateTime.now();
    return [
      // Olay 41. sırada: widget testinde yerel bildirim eklentisi çağrılmaz.
      for (var i = 0; i < 40; i++)
        {'title': 'Eski etkinlik', 'event_date': '2020-01-01'},
      {
        'id': 7,
        'title': 'Mükellef toplantısı',
        'description': 'Görüşme',
        'event_date': DateTime(now.year, now.month, 15, 9).toIso8601String(),
        'event_type': 'CLIENT',
        'target_client_id': 12,
        'is_notification_active': false,
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> clients() async => [
    {'user_id': 12, 'company_title': 'Örnek Ltd.'},
  ];

  @override
  Future<List<Map<String, dynamic>>> externalClients() async => [];

  @override
  Future<Map<String, dynamic>> updateCalendarEvent(
    int eventId, {
    required String title,
    required String eventDate,
    String? description,
    String eventType = 'PERSONAL',
    int? targetClientId,
    int? targetExternalClientId,
    bool isNotificationActive = true,
  }) async {
    updated = {
      'id': eventId,
      'title': title,
      'event_type': eventType,
      'target_client_id': targetClientId,
    };
    return {};
  }
}

void main() {
  testWidgets('client can add event and list refreshes on phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = CalendarApi();
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarListPage(
          api: api,
          refreshKey: 0,
          isClient: true,
          userId: 12,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calendar-day-15')));
    await tester.pumpAndSettle();
    expect(find.text('Ödeme vadesi'), findsOneWidget);
    await tester.tap(find.byType(ModalBarrier).last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -280));
    await tester.pumpAndSettle();
    expect(find.text('Vergi beyanı'), findsOneWidget);
    expect(find.text('Örnek Ltd. ödeme vadesi'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 280));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sonraki ay'));
    await tester.pumpAndSettle();
    expect(find.text('Vergi beyanı'), findsNothing);
    final nextMonth = DateTime(DateTime.now().year, DateTime.now().month + 1);
    expect(
      api.lastStartDate,
      '${nextMonth.year}-${nextMonth.month.toString().padLeft(2, '0')}-01',
    );
    await tester.tap(find.byTooltip('Önceki ay'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Etkinlik ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Başlık'),
      'Toplantı',
    );
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(api.created?['title'], 'Toplantı');
    expect(api.created?['event_type'], 'CLIENT');
    expect(api.loads, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GİB failure does not hide personal calendar', (tester) async {
    final api = CalendarApi()..failGib = true;
    await tester.pumpWidget(
      MaterialApp(home: CalendarListPage(api: api, refreshKey: 0)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('calendar-day-15')), findsOneWidget);
    expect(find.text('Vergi beyanı'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('advisor edit preserves targeted client event', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = AdvisorCalendarApi();
    await tester.pumpWidget(
      MaterialApp(home: CalendarListPage(api: api, refreshKey: 0)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Mükellef toplantısı'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Düzenle'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Örnek Ltd.'), findsOneWidget);
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(api.updated?['event_type'], 'CLIENT');
    expect(api.updated?['target_client_id'], 12);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar template can be created and used on phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = CalendarApi();
    await tester.pumpWidget(MaterialApp(home: CalendarTemplatesPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Şablon Oluştur'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Şablon Adı'),
      'Beyanname',
    );
    await tester.ensureVisible(find.text('Şablonu Kaydet'));
    await tester.tap(find.text('Şablonu Kaydet'));
    await tester.pumpAndSettle();
    expect(api.templates.single['title'], 'Beyanname');
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: CalendarListPage(api: api, refreshKey: 0, isClient: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Etkinlik ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Şablon seçiniz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beyanname').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(api.created?['title'], 'Beyanname');
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(MaterialApp(home: CalendarTemplatesPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Şablonu sil'));
    await tester.pumpAndSettle();
    expect(api.templates, isNotEmpty);
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    expect(api.templates, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
