import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/models.dart';
import '../../core/data/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/lb_card.dart';
import '../../core/widgets/slant_button.dart';

enum AccountSettingField { username, email, region, games }

class AccountSettingScreen extends ConsumerStatefulWidget {
  const AccountSettingScreen({required this.field, super.key});

  final AccountSettingField field;

  @override
  ConsumerState<AccountSettingScreen> createState() =>
      _AccountSettingScreenState();
}

class _AccountSettingScreenState extends ConsumerState<AccountSettingScreen> {
  final _controller = TextEditingController();
  final _games = <String>{};
  String? _region;
  bool _initialized = false;
  bool _saving = false;

  static const regions = [
    'Manila',
    'Cebu',
    'Cavite',
    'Davao',
    'Iloilo',
    'Baguio',
    'CDO',
    'Zamboanga',
  ];
  static const availableGames = [
    'MLBB',
    'VALORANT',
    'COD Mobile',
    'PUBG',
    'TEKKEN 8',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initialize(LbUser user) {
    if (_initialized) return;
    _initialized = true;
    _controller.text = switch (widget.field) {
      AccountSettingField.username => user.username.replaceFirst('@', ''),
      AccountSettingField.email => user.email,
      _ => '',
    };
    _region = user.region;
    _games.addAll(user.games);
  }

  bool get _valid => switch (widget.field) {
    AccountSettingField.username => RegExp(
      r'^[A-Za-z0-9_]{3,20}$',
    ).hasMatch(_controller.text.trim()),
    AccountSettingField.email => RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(_controller.text.trim()),
    AccountSettingField.region => _region != null,
    AccountSettingField.games => _games.isNotEmpty,
  };

  Future<void> _save(LbUser user) async {
    setState(() => _saving = true);
    try {
      if (widget.field == AccountSettingField.email) {
        await ref
            .read(authRepoProvider)
            .requestEmailChange(_controller.text.trim());
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Check your inbox'),
            content: Text(
              'Firebase sent a verification link to ${_controller.text.trim()}. Your email changes after you confirm it.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        await ref
            .read(profileRepoProvider)
            .updateIdentity(
              userId: user.id,
              username: widget.field == AccountSettingField.username
                  ? '@${_controller.text.trim()}'
                  : user.username,
              region: widget.field == AccountSettingField.region
                  ? _region!
                  : (user.region ?? 'Manila'),
              games: widget.field == AccountSettingField.games
                  ? _games.toList()
                  : user.games,
            );
      }
      ref.invalidate(currentUserProvider);
      ref.invalidate(profileByIdProvider(user.id));
      if (mounted) context.pop();
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().contains('23505')
          ? 'That username is already taken.'
          : 'Could not save this setting. Please try again.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _initialize(user);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.chevron_left),
        ),
        title: Text(_title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          Text(_description, style: LbType.bodySm),
          const SizedBox(height: 18),
          _editor(),
          const SizedBox(height: 24),
          SlantButton(
            label: _saving ? 'Saving…' : _buttonLabel,
            onPressed: _valid && !_saving ? () => _save(user) : null,
          ),
        ],
      ),
    );
  }

  String get _title => switch (widget.field) {
    AccountSettingField.username => 'Change username',
    AccountSettingField.email => 'Change email',
    AccountSettingField.region => 'Change region',
    AccountSettingField.games => 'Your games',
  };

  String get _description => switch (widget.field) {
    AccountSettingField.username =>
      'This is your public Labaan handle. Use 3–20 letters, numbers, or underscores.',
    AccountSettingField.email =>
      'We will send a verification link before changing your Firebase account email.',
    AccountSettingField.region =>
      'Your region helps personalize tournaments and local rankings.',
    AccountSettingField.games =>
      'Choose at least one game to improve tournament recommendations.',
  };

  String get _buttonLabel =>
      widget.field == AccountSettingField.email ? 'Send verification' : 'Save';

  Widget _editor() => switch (widget.field) {
    AccountSettingField.username => TextField(
      controller: _controller,
      autofocus: true,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(prefixText: '@', labelText: 'Username'),
    ),
    AccountSettingField.email => TextField(
      controller: _controller,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(labelText: 'Email address'),
    ),
    AccountSettingField.region => Column(
      children: [
        for (final region in regions) ...[
          LbCard(
            onTap: () => setState(() => _region = region),
            child: Row(
              children: [
                Expanded(child: Text(region, style: LbType.cardTitleSm)),
                if (_region == region)
                  const Icon(Icons.check_circle, color: LbColors.lime),
              ],
            ),
          ),
          const SizedBox(height: 7),
        ],
      ],
    ),
    AccountSettingField.games => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final game in availableGames)
          FilterChip(
            label: Text(game),
            selected: _games.contains(game),
            onSelected: (_) => setState(() {
              _games.contains(game) ? _games.remove(game) : _games.add(game);
            }),
          ),
      ],
    ),
  };
}
