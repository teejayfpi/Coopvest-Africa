import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/theme_config.dart';

/// Opens a full-fidelity in-app WebView for the Paystack checkout.
///
/// Keeps `https://checkout.paystack.com` inside the app's own WebView so that
/// the redirect to the mobile-money handler schema (`opay://` etc.) never
/// reaches Android's activity manager. That handoff was the source of:
/// `SecurityException: Permission Denial ... team.opay.pay.merchant.service/
/// com.opay.webview.WebFoundationActivity ... not exported`.
///
/// Returns `true` (user finished), `false` (canceled) or `null` (closed by
/// the system/back button), matching the previous launchUrl+AlertDialog
/// semantics found in the deposit/activation flows.
Future<bool?> showPaystackCheckoutDialog(
  BuildContext context, {
  required String url,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PaystackCheckoutDialog(url: url),
  );
}

class PaystackCheckoutDialog extends StatefulWidget {
  final String url;
  const PaystackCheckoutDialog({super.key, required this.url});
  @override
  State<PaystackCheckoutDialog> createState() => _PaystackCheckoutDialogState();
}

class _PaystackCheckoutDialogState extends State<PaystackCheckoutDialog> {
  late final WebViewController _controller;
  bool _loading = true;
  int _progress = 0;
  bool _loadFailed = false;
  bool _allowExternalHttp = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (!mounted) return;
            setState(() {
              _progress = p;
              _loading = p < 100;
            });
          },
          onWebResourceError: (WebResourceError err) {
            if (!mounted) return;
            setState(() => _loadFailed = true);
          },
          onNavigationRequest:
              (NavigationRequest request) async {
            // Allow the Paystack page itself. Block every non-http(s)
            // scheme — `opay://`, `intent://`, `tel:`, `mailto:` etc. —
            // so the OS never tries to start an external activity (the
            // SecurityException source). Also ignore same-document anchors,
            // which the WebView already navigates.
            final u = request.url;
            final isHttp = u.startsWith('https:') || u.startsWith('http:');
            final isPaystack = u.contains('checkout.paystack.com');
            if (!(isHttp && (isPaystack || _allowExternalHttp))) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _loading ? false : true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _loading) {
          // Don't let accidental back presses nuke the payment mid-way;
          // show a confirm instead..
          _confirmCancel();
        }
      },
      child: AlertDialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 8),
        contentPadding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        content: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.sizeOf(context).height * 0.75,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: WebViewWidget(controller: _controller),
                    ),
                    if (_loading)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          value: _progress/ 100,
                          minHeight: 2,
                          backgroundColor: CoopvestColors.primary.withOpacity(0.15),
                          color: CoopvestColors.primary,
                        ),
                      ),
                    if (_loadFailed)
                      Positioned.fill(
                        child: Container(
                          color: Colors.white,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off_rounded,
                                  size: 48, color: CoopvestColors.error),
                              const SizedBox(height: 12),
                              const Text('Couldn’t load the payment page.',
                                  style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('Check your connection and try again.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.tonalIcon(
                                onPressed: () {
                                  setState(() {
                                    _loadFailed = false;
                                    _loading = true;
                                  });
                                  _controller.loadRequest(Uri.parse(widget.url));
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: CoopvestColors.primary,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Coopvest — Secure Payment',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: _confirmCancel,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _confirmCancel,
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: const Text("I've Paid"),
          ),
        ],
      ),
    );
  }

  void _confirmCancel() {
    if (!mounted) return;
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel payment?'),
        content: Text(
          'If you cancel, the payment won\'t complete. Proceed anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep paying'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel'),
            style: TextButton.styleFrom(foregroundColor: CoopvestColors.error),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        Navigator.of(context).pop(false);
      }
    });
  }
}