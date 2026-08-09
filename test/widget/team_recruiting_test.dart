import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labaan/features/team/player_search_screen.dart';
import 'package:labaan/features/team/team_management_screen.dart';

import '_helpers.dart';

void main() {
  testWidgets('team shortcut resolves the signed-in player team', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(hostRoute(const TeamManagementScreen()));
    await pumpAndSettleForData(tester);
    await pumpAndSettleForData(tester);

    expect(find.text('Team MNL'), findsWidgets);
    expect(find.byKey(const Key('edit-team')), findsOneWidget);
  });

  testWidgets('captain can edit team identity', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      hostRoute(const TeamManagementScreen(teamId: 't_mnl')),
    );
    await pumpAndSettleForData(tester);

    await tester.tap(find.byKey(const Key('edit-team')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('team-name-field')),
      'Manila Prime',
    );
    await tester.enterText(find.byKey(const Key('team-tag-field')), 'mpr');
    await tester.tap(find.byKey(const Key('save-team')));
    await tester.pump(const Duration(milliseconds: 600));
    await pumpAndSettleForData(tester);

    expect(find.text('Manila Prime'), findsWidgets);
    expect(find.text('Team identity updated.'), findsOneWidget);
  });

  testWidgets('captain can remove a roster member', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      hostRoute(const TeamManagementScreen(teamId: 't_mnl')),
    );
    await pumpAndSettleForData(tester);

    await tester.tap(find.byKey(const Key('member-actions-u_sage')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove member'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-team-action')));
    await tester.pump(const Duration(milliseconds: 600));
    await pumpAndSettleForData(tester);

    expect(find.text('@sagemaster'), findsNothing);
    expect(find.text('// ROSTER · 4 OF 5'), findsOneWidget);
    expect(find.text('@sagemaster was removed from the team.'), findsOneWidget);
  });

  testWidgets('captain transfer immediately removes old captain controls', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      hostRoute(const TeamManagementScreen(teamId: 't_mnl')),
    );
    await pumpAndSettleForData(tester);

    await tester.tap(find.byKey(const Key('member-actions-u_sage')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make captain'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-team-action')));
    await tester.pump(const Duration(milliseconds: 600));
    await pumpAndSettleForData(tester);

    expect(find.byKey(const Key('edit-team')), findsNothing);
    expect(find.text('INVITE BY USERNAME'), findsNothing);
    expect(find.text('@sagemaster is now team captain.'), findsOneWidget);
    expect(
      find.text('Transfer captaincy to another member before leaving.'),
      findsNothing,
    );
  });

  testWidgets('captain can invite a player by username', (tester) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      hostRoute(const TeamManagementScreen(teamId: 't_mnl')),
    );
    await pumpAndSettleForData(tester);

    await tester.tap(find.text('INVITE BY USERNAME'));
    await tester.pump();

    expect(find.text('Invite by username'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('team-invite-username')),
      'sagemaster',
    );
    await tester.tap(find.byKey(const Key('team-invite-submit')));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Team invitation sent.'), findsOneWidget);
    expect(find.text('Invite by username'), findsNothing);
  });

  testWidgets('player search filters usernames and sends an invite', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(
      hostRoute(const PlayerSearchScreen(teamId: 't_mnl')),
    );
    await pumpAndSettleForData(tester);

    await tester.enterText(
      find.byKey(const Key('player-username-search')),
      'sage',
    );
    await pumpAndSettleForData(tester);

    expect(find.text('@sagemaster'), findsOneWidget);
    expect(find.text('@midlaner'), findsNothing);

    await tester.tap(find.text('INVITE'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('INVITED'), findsOneWidget);
    expect(find.text('Invitation sent to @sagemaster.'), findsOneWidget);
  });
}
