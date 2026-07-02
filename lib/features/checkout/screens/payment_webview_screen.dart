import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../core/utils/l10n.dart';

/// Full-screen in-app payment WebView.
/// Intercepts any `baahy://` deep link and pops with that [Uri].
/// Pops with null when user presses the back arrow (cancelled).
class PaymentWebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const PaymentWebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _ctrl;
  bool _pageLoading = true;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) { if (mounted) setState(() => _pageLoading = true); },
        onPageFinished: (_) async {
          if (mounted) setState(() => _pageLoading = false);
          // Force card/number inputs to LTR — Flutter WebView inherits RTL from
          // the app locale which causes card numbers to be submitted in reverse.
          await _ctrl.runJavaScript(r"""
            (function() {
              function fixInputs() {
                document.querySelectorAll('input[type="tel"],input[type="number"],input[type="text"],input:not([type])').forEach(function(el) {
                  el.style.direction = 'ltr';
                  el.style.textAlign = 'left';
                });
              }
              fixInputs();
              var obs = new MutationObserver(fixInputs);
              obs.observe(document.body, { childList: true, subtree: true });
            })();
          """);
        },
        onNavigationRequest: (req) {
          final uri = Uri.tryParse(req.url);
          if (uri != null && uri.scheme == 'baahy') {
            Navigator.of(context).pop(uri);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final accent = AppColors.adaptive(context);
    return Scaffold(
      backgroundColor: context.col.bg,
      body: Column(children: [
        Container(
          color: context.col.surface,
          child: Column(children: [
            SizedBox(height: topPad),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: accent, size: 20),
                ),
                Text(widget.title,
                  style: TextStyle(
                    fontFamily: 'Cairo', fontWeight: FontWeight.w600,
                    fontSize: 15, color: context.col.ink2)),
              ]),
            ),
            Divider(height: 1, color: context.col.border),
          ]),
        ),
        Expanded(
          child: Stack(children: [
            WebViewWidget(controller: _ctrl),
            if (_pageLoading)
              const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2.5)),
          ]),
        ),
      ]),
    );
  }
}
