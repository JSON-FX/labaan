import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/links/payment_link.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

enum CheckoutNavigationKind { web, appReturn, externalApp, blocked }

class CheckoutNavigation {
  const CheckoutNavigation._(this.kind, {this.appLocation});

  const CheckoutNavigation.web() : this._(CheckoutNavigationKind.web);

  const CheckoutNavigation.appReturn(String location)
    : this._(CheckoutNavigationKind.appReturn, appLocation: location);

  const CheckoutNavigation.externalApp()
    : this._(CheckoutNavigationKind.externalApp);

  const CheckoutNavigation.blocked() : this._(CheckoutNavigationKind.blocked);

  final CheckoutNavigationKind kind;
  final String? appLocation;
}

/// Keeps browser navigation in the checkout while handling payment returns and
/// native wallet handoffs explicitly. Malformed Labaan links are blocked so a
/// checkout page cannot navigate to an arbitrary location in the app.
CheckoutNavigation classifyCheckoutNavigation(Uri uri) {
  final appLocation = paymentLocationFromUri(uri);
  if (appLocation != null) {
    return CheckoutNavigation.appReturn(appLocation);
  }

  return switch (uri.scheme.toLowerCase()) {
    'http' || 'https' || 'about' => const CheckoutNavigation.web(),
    'labaan' => const CheckoutNavigation.blocked(),
    _ => const CheckoutNavigation.externalApp(),
  };
}

class PaymentCheckoutScreen extends StatefulWidget {
  const PaymentCheckoutScreen({required this.checkoutUrl, super.key});

  final Uri checkoutUrl;

  @override
  State<PaymentCheckoutScreen> createState() => _PaymentCheckoutScreenState();
}

class _PaymentCheckoutScreenState extends State<PaymentCheckoutScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  String? _mainFrameError;
  bool _handledReturn = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(LbColors.bg)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageStarted: (_) {
            if (mounted && _mainFrameError != null) {
              setState(() => _mainFrameError = null);
            }
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame != true || !mounted) return;
            setState(() => _mainFrameError = error.description);
          },
          onNavigationRequest: _handleNavigation,
        ),
      )
      ..loadRequest(widget.checkoutUrl);
  }

  Future<NavigationDecision> _handleNavigation(
    NavigationRequest request,
  ) async {
    if (!request.isMainFrame) return NavigationDecision.navigate;

    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    final navigation = classifyCheckoutNavigation(uri);

    switch (navigation.kind) {
      case CheckoutNavigationKind.web:
        return NavigationDecision.navigate;
      case CheckoutNavigationKind.appReturn:
        if (!_handledReturn) {
          _handledReturn = true;
          final location = navigation.appLocation!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go(location);
          });
        }
        return NavigationDecision.prevent;
      case CheckoutNavigationKind.externalApp:
        final opened = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!opened && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No app can open this payment link.')),
          );
        }
        return NavigationDecision.prevent;
      case CheckoutNavigationKind.blocked:
        return NavigationDecision.prevent;
    }
  }

  Future<void> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openExternally() async {
    final currentUrl = await _controller.currentUrl();
    final uri = currentUrl == null
        ? widget.checkoutUrl
        : Uri.tryParse(currentUrl);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the checkout browser.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _handleBack,
          icon: const Icon(Icons.chevron_left, size: 24),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Secure checkout'),
            Text(
              'PAYMONGO',
              style: LbType.metaSm.copyWith(
                color: LbColors.textMuted,
                fontSize: 8.5,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Open in browser',
            onPressed: _openExternally,
            icon: const Icon(Icons.open_in_browser_rounded, size: 20),
          ),
          IconButton(
            tooltip: 'Close checkout',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  value: _progress == 0 ? null : _progress / 100,
                  color: LbColors.lime,
                  backgroundColor: LbColors.borderMuted,
                ),
              )
            : null,
      ),
      body: _mainFrameError == null
          ? WebViewWidget(controller: _controller)
          : _CheckoutError(
              message: _mainFrameError!,
              onRetry: () => unawaited(_controller.reload()),
              onOpenBrowser: _openExternally,
            ),
    );
  }
}

class _CheckoutError extends StatelessWidget {
  const _CheckoutError({
    required this.message,
    required this.onRetry,
    required this.onOpenBrowser,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onOpenBrowser;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: LbColors.textMuted,
              size: 40,
            ),
            const SizedBox(height: 14),
            Text('Checkout could not load', style: LbType.cardTitle),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: LbType.bodySm.copyWith(color: LbColors.textMuted),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
            TextButton(
              onPressed: onOpenBrowser,
              child: const Text('Open in browser'),
            ),
          ],
        ),
      ),
    );
  }
}
