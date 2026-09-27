import 'dart:convert';

import 'package:finkit_mobile/pages/full_notes_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'notes stay on their account and tapping a note never deletes it',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'finkit_notes_advisor_12': jsonEncode([
          {
            'id': 'n1',
            'title': 'Müşavir notu',
            'content': 'Görüşme',
            'category': 'work',
            'color': 'blue',
            'isPinned': false,
            'todoList': [
              {'id': 't1', 'text': 'Ara', 'done': false},
            ],
            'created_at': '2026-09-01T10:00:00',
          },
        ]),
        'finkit_notes_client_12': jsonEncode([
          {
            'id': 'n2',
            'title': 'Mükellef notu',
            'content': '',
            'category': 'general',
            'color': 'yellow',
            'isPinned': false,
            'todoList': [],
            'created_at': '2026-09-01T10:00:00',
          },
        ]),
      });
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: FullNotesPage(userId: 12, role: 'ADVISOR')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Müşavir notu'), findsOneWidget);
      expect(find.text('Mükellef notu'), findsNothing);
      await tester.tap(find.text('Müşavir notu'));
      await tester.pumpAndSettle();
      expect(find.text('Müşavir notu'), findsOneWidget);
      await tester.tap(find.byTooltip('Sabitle'));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      final advisorNotes = jsonDecode(
        prefs.getString('finkit_notes_advisor_12')!,
      );
      expect(advisorNotes[0]['isPinned'], true);

      await tester.pumpWidget(
        const MaterialApp(home: FullNotesPage(userId: 12, role: 'CLIENT')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mükellef notu'), findsOneWidget);
      expect(find.text('Müşavir notu'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
