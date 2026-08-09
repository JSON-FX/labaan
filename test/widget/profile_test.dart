import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:labaan/core/data/mock_repos.dart';
import 'package:labaan/core/data/models.dart';
import 'package:labaan/core/domain/ranks.dart';
import 'package:labaan/features/identity/profile_screen.dart';

import '_helpers.dart';

void main() {
  testWidgets('renders team name and tag instead of its database id', (
    tester,
  ) async {
    setPhoneViewport(tester);
    await tester.pumpWidget(hostRoute(const ProfileScreen()));
    await pumpAndSettleForData(tester);

    await tester.ensureVisible(find.text('Team MNL'));
    await tester.pump();

    expect(find.text('Team MNL'), findsOneWidget);
    expect(find.text('MNL'), findsOneWidget);
    expect(find.text('t_mnl'), findsNothing);
  });

  testWidgets('renders the authenticated player profile, not the fixture', (
    tester,
  ) async {
    setPhoneViewport(tester);
    final user = LbUser(
      id: 'firebase-user',
      username: '@actualplayer',
      email: '',
      region: 'Cebu',
      games: const ['MLBB'],
      createdAt: DateTime(2026),
    );
    final profile = LbPlayerProfile(
      user: user,
      rank: LbUserRank(
        userId: user.id,
        totalWins: 0,
        rank: Rank.recruit,
        rankUpdatedAt: DateTime(2026),
      ),
      badges: const [],
      gamesPlayed: const ['MLBB'],
      totalMatches: 0,
      totalWins: 0,
      totalLosses: 0,
      totalPayoutPhp: 0,
      teamIds: const [],
      recentTournaments: const [],
    );

    await tester.pumpWidget(
      hostRoute(
        const ProfileScreen(),
        authRepo: MockAuthRepo(initialUser: user),
        profileRepo: MockProfileRepo(profiles: {user.id: profile}),
      ),
    );
    await pumpAndSettleForData(tester);

    expect(find.text('@actualplayer'), findsOneWidget);
    expect(find.text('@tonton26'), findsNothing);
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('picks and uploads a supported profile avatar', (tester) async {
    setPhoneViewport(tester);
    final repo = MockProfileRepo();
    final imageBytes = Uint8List.fromList(<int>[137, 80, 78, 71]);

    await tester.pumpWidget(
      hostRoute(
        ProfileScreen(
          pickAvatar: () async => XFile.fromData(
            imageBytes,
            mimeType: 'image/png',
            name: 'avatar.png',
          ),
        ),
        profileRepo: repo,
      ),
    );
    await pumpAndSettleForData(tester);

    await tester.tap(find.byKey(const Key('profile-avatar-picker')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(repo.lastAvatarBytes, imageBytes);
    expect(repo.lastAvatarContentType, 'image/png');
  });
}
