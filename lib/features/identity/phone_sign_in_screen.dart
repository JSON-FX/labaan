import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/slant_button.dart';

class PhoneSignInScreen extends ConsumerStatefulWidget {
  const PhoneSignInScreen({super.key});

  @override
  ConsumerState<PhoneSignInScreen> createState() => _PhoneSignInScreenState();
}

class _PhoneSignInScreenState extends ConsumerState<PhoneSignInScreen> {
  final _phoneController = TextEditingController(text: '+63');
  final _otpController = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String get _phone => _phoneController.text.replaceAll(RegExp(r'\s+'), '');

  bool get _canSubmit => _codeSent
      ? RegExp(r'^\d{6}$').hasMatch(_otpController.text.trim())
      : RegExp(r'^\+63\d{10}$').hasMatch(_phone);

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final auth = ref.read(authRepoProvider);
      if (!_codeSent) {
        await auth.requestPhoneOtp(_phone);
        if (!mounted) return;
        setState(() => _codeSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification code sent.')),
        );
        return;
      }
      final user = await auth.verifyPhoneOtp(
        phoneE164: _phone,
        token: _otpController.text.trim(),
      );
      if (!mounted) return;
      context.go(user.hasCompletedSetup ? '/home' : '/setup');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _codeSent
                ? 'That code could not be verified.'
                : 'Could not send a verification code.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Continue with phone')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
          children: [
            Text(
              _codeSent ? 'Enter your code' : 'Your mobile number',
              style: LbType.sectionTitle.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 8),
            Text(
              _codeSent
                  ? 'We sent a 6-digit code to $_phone.'
                  : 'Use a Philippine number in international format.',
              style: LbType.bodySm.copyWith(color: LbColors.textMuted),
            ),
            const SizedBox(height: 24),
            if (!_codeSent)
              TextField(
                controller: _phoneController,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+639171234567',
                ),
              )
            else
              TextField(
                controller: _otpController,
                enabled: !_busy,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: 6,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Verification code',
                  hintText: '000000',
                  counterText: '',
                ),
              ),
            const SizedBox(height: 20),
            SlantButton(
              label: _busy
                  ? (_codeSent ? 'Verifying…' : 'Sending…')
                  : (_codeSent ? 'Verify code' : 'Send code'),
              onPressed: _canSubmit && !_busy ? _submit : null,
            ),
            if (_codeSent) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _codeSent = false;
                        _otpController.clear();
                      }),
                child: const Text('CHANGE PHONE NUMBER'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
