import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
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
  String? _loadError;

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
        // A gateway page that fails to load used to leave a blank white screen with no hint —
        // the customer just backs out, our record sits `pending` forever and the gateway never
        // sees a transaction. Moamalat's Lightbox in particular is served from a NON-STANDARD
        // port (npg.moamalat.net:6006), which carrier networks are known to block.
        onWebResourceError: (err) {
          if (!mounted || err.isForMainFrame != true) return;
          setState(() {
            _pageLoading = false;
            _loadError = context.tr('تعذّر تحميل صفحة الدفع', 'Could not load the payment page');
          });
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

    // Android's WebView ignores <input type="file"> unless the app supplies a chooser, so
    // "Choose file" on the bank-transfer top-up page did nothing and almost no top-up ever
    // arrived with a slip (1 of ~25, 2026-10-31). iOS's WKWebView has its own chooser.
    final platform = _ctrl.platform;
    if (platform is AndroidWebViewController) {
      platform.setOnShowFileSelector(_pickFile);
    }
  }

  Future<List<String>> _pickFile(FileSelectorParams params) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.col.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: ctx.col.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(ctx.tr('اختيار من المعرض', 'Choose from gallery'),
              style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'])),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: Text(ctx.tr('التقاط صورة', 'Take photo'),
              style: const TextStyle(fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'])),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    // An empty list cancels the chooser; the page's input stays usable for another try.
    if (source == null) return [];
    final img = await ImagePicker().pickImage(
      source: source, maxWidth: 2000, maxHeight: 2000, imageQuality: 85);
    return img == null ? [] : [Uri.file(img.path).toString()];
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
                    fontFamily: 'Manrope', fontFamilyFallback: ['Tajawal'], fontWeight: FontWeight.w600,
                    fontSize: 15, color: context.col.ink2)),
              ]),
            ),
            Divider(height: 1, color: context.col.border),
          ]),
        ),
        Expanded(
          child: Stack(children: [
            // Directionality(ltr) fixes mirrored touch coordinates in RTL apps —
            // without it, taps register at the horizontally-flipped position.
            Directionality(
              textDirection: TextDirection.ltr,
              child: WebViewWidget(controller: _ctrl),
            ),
            if (_pageLoading && _loadError == null)
              const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2.5)),
            if (_loadError != null)
              Container(
                color: context.col.bg,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 44, color: AppColors.danger),
                    const SizedBox(height: 14),
                    Text(context.tr('تعذّر فتح صفحة الدفع',
                                    'Payment page could not be opened'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(context.tr(
                        'قد تكون شبكتك تمنع الاتصال ببوابة الدفع. جرّب شبكة أخرى (Wi-Fi أو بيانات) أو اختر طريقة دفع مختلفة.',
                        'Your network may be blocking the payment gateway. Try another network (Wi-Fi or mobile data) or a different payment method.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, height: 1.6, color: context.col.ink3)),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: () {
                        setState(() { _loadError = null; _pageLoading = true; });
                        _ctrl.loadRequest(Uri.parse(widget.url));
                      },
                      child: Text(context.tr('إعادة المحاولة', 'Try again')),
                    ),
                  ],
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}
