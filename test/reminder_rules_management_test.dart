import 'package:finkit_mobile/api_client.dart';
import 'package:finkit_mobile/pages/accounting_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class RulesApi extends FinkitApi {
  int? updatedDays;
  String? updatedMessage;
  int? deletedId;
  int? selectedTemplateId;
  int reminderRuns = 0;

  @override
  Future<Map<String, dynamic>> runReminders() async {
    reminderRuns++;
    return {};
  }

  @override
  Future<Map<String, dynamic>> advisorProfile() async => {
    'payment_reminder_template_id': null,
  };

  @override
  Future<List<Map<String, dynamic>>> messageTemplates() async => [
    {'id': 4, 'name': 'Beyanname', 'content': 'Hatırlatma'},
  ];

  @override
  Future<Map<String, dynamic>> setAdvisorReminderTemplate(
    int? templateId,
  ) async {
    selectedTemplateId = templateId;
    return {};
  }

  @override
  Future<List<Map<String, dynamic>>> reminderRules() async => [
    {
      'id': 7,
      'channel': 'email',
      'days_before': updatedDays ?? 3,
      'message': updatedMessage ?? 'İlk metin',
      'is_active': true,
    },
  ];

  @override
  Future<Map<String, dynamic>> updateReminderRule(
    int ruleId, {
    int? daysBefore,
    String? message,
    bool? isActive,
  }) async {
    updatedDays = daysBefore;
    updatedMessage = message;
    return {};
  }

  @override
  Future<void> deleteReminderRule(int ruleId) async {
    deletedId = ruleId;
  }
}

void main() {
  testWidgets('client edits a rule without advisor send action on phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = RulesApi();
    await tester.pumpWidget(
      MaterialApp(
        home: ReminderRulesPage(api: api, refreshKey: 0, isClient: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Şimdi Gönder'), findsNothing);
    await tester.tap(find.byTooltip('Kural işlemleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Düzenle'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Vadeden kaç gün önce'),
      '5',
    );
    await tester.ensureVisible(find.text('Kuralı Kaydet'));
    await tester.tap(find.text('Kuralı Kaydet'));
    await tester.pumpAndSettle();
    expect(api.updatedDays, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('advisor selects email reminder template on phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = RulesApi();
    await tester.pumpWidget(
      MaterialApp(home: ReminderRulesPage(api: api, refreshKey: 0)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Varsayılan sistem mesajı'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beyanname').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Şablonu Kaydet'));
    await tester.pumpAndSettle();
    expect(api.selectedTemplateId, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('advisor confirms before sending due reminders', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = RulesApi();
    await tester.pumpWidget(
      MaterialApp(home: ReminderRulesPage(api: api, refreshKey: 0)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Şimdi Gönder'));
    await tester.tap(find.text('Şimdi Gönder'));
    await tester.pumpAndSettle();
    expect(api.reminderRuns, 0);
    expect(find.textContaining('e-posta hatırlatması'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(api.reminderRuns, 0);
    await tester.tap(find.text('Şimdi Gönder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gönder'));
    await tester.pumpAndSettle();
    expect(api.reminderRuns, 1);
    expect(tester.takeException(), isNull);
  });
}
