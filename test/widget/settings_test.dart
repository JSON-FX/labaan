import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/features/system/account_setting_screen.dart';
import 'package:labaan/features/system/account_deletion_screen.dart';
import 'package:labaan/features/system/notification_prefs_screen.dart';
import 'package:labaan/features/system/payout_account_screen.dart';
import 'package:labaan/features/system/settings_screen.dart';

import '_helpers.dart';

void main() {
  testWidgets('settings shows live account values and editable sections', (
    tester,
  ) async {
    setPhoneViewport(tester, height: 1200);
    await tester.pumpWidget(hostRoute(const SettingsScreen()));
    await pumpAndSettleForData(tester);

    expect(find.text('@tonton26'), findsOneWidget);
    expect(find.text('Manila'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
    expect(find.text('Not set'), findsWidgets);
    expect(find.text('Connected'), findsOneWidget);
  });

  testWidgets('username editor validates and normalizes a public handle', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      hostRoute(
        const AccountSettingScreen(field: AccountSettingField.username),
      ),
    );
    await tester.pump();

    expect(find.text('Change username'), findsOneWidget);
    expect(find.text('SAVE'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'new_player');
    await tester.pump();
    expect(find.text('SAVE'), findsOneWidget);
  });

  testWidgets('notification preferences load persisted channel controls', (
    tester,
  ) async {
    setPhoneViewport(tester, height: 1100);
    await tester.pumpWidget(hostRoute(const NotificationPrefsScreen()));
    await pumpAndSettleForData(tester);

    expect(find.text('Match ready'), findsOneWidget);
    expect(find.text('Victory Points earned'), findsOneWidget);
    expect(find.text('PUSH'), findsWidgets);
    expect(find.text('EMAIL'), findsWidgets);
  });

  testWidgets('payout editor supports GCash and Maya details', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(hostRoute(const PayoutAccountScreen()));
    await pumpAndSettleForData(tester);

    expect(find.text('GCash'), findsOneWidget);
    expect(find.text('Maya'), findsOneWidget);
    expect(find.text('Account holder name'), findsOneWidget);
    expect(find.text('Mobile number'), findsOneWidget);
  });

  testWidgets(
    'account deletion requires exact confirmation and schedules grace period',
    (tester) async {
      setPhoneViewport(tester, height: 1200);
      await tester.pumpWidget(hostRoute(const AccountDeletionScreen()));
      await pumpAndSettleForData(tester);

      expect(find.text('Permanent account closure'), findsOneWidget);
      final button = find.text('SCHEDULE ACCOUNT DELETION');
      expect(button, findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'delete');
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      expect(find.text('Permanent account closure'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'DELETE');
      await tester.pump();
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Deletion scheduled'), findsOneWidget);
      expect(find.text('CANCEL DELETION REQUEST'), findsOneWidget);
    },
  );
}
