/// 5-role system from spec §3.
///
/// The **Flutter mobile app is Player-only**. Super Admin, Tournament
/// Organizer, and Moderator surfaces live in the Next.js admin dashboard.
enum UserRole {
  superAdmin('Super Admin'),
  tournamentOrganizer('Tournament Organizer'),
  moderator('Moderator'),
  spectator('Spectator'),
  player('Player');

  const UserRole(this.displayName);
  final String displayName;
}

/// Moderator queue priorities from spec §3.1. This lives on the admin
/// dashboard, not the mobile app — kept here for shared type reference.
enum ModeratorAction {
  disputeResolution('Dispute resolution', 1, Duration(minutes: 15)),
  resultVerification('Result verification', 2, Duration(minutes: 30)),
  noShowWarning('No-show warning', 3, Duration(minutes: 45)),
  tournamentReview('Tournament review', 4, null);

  const ModeratorAction(this.displayName, this.priority, this.sla);
  final String displayName;
  final int priority;
  final Duration? sla;
}
