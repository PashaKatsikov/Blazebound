import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../look.dart';

class WebDocScreen extends StatefulWidget {
  const WebDocScreen({
    super.key,
    required this.title,
    required this.url,
    this.bleach = false,
  });

  final String title;
  final String url;
  final bool bleach;

  @override
  State<WebDocScreen> createState() => _WebDocScreenState();
}

class _WebDocScreenState extends State<WebDocScreen> {
  late final WebViewController _c;
  bool _busy = true;

  static const _whitewash = '''
    (function(){
      var s = document.createElement('style');
      s.textContent = 'html,body,#app,#root,main,.wrapper,.container{background:#ffffff !important;background-color:#ffffff !important;}';
      document.documentElement.style.backgroundColor = '#ffffff';
      if (document.body) {
        document.body.style.backgroundColor = '#ffffff';
        document.body.style.backgroundImage = 'none';
        document.head && document.head.appendChild(s);
      }
    })();
  ''';

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.bleach ? const Color(0xFFFFFFFF) : Dye.abyss)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _busy = true);
        },
        onPageFinished: (_) async {
          if (widget.bleach) {
            try {
              await _c.runJavaScript(_whitewash);
              await Future<void>.delayed(const Duration(milliseconds: 240));
              await _c.runJavaScript(_whitewash);
            } catch (_) {}
          }
          if (mounted) setState(() => _busy = false);
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _busy = false);
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.bleach ? Colors.white : Dye.abyss,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  const BackChip(),
                  const SizedBox(width: 12),
                  Text(widget.title, style: titleStyle(16, color: widget.bleach ? Dye.ink : Dye.cream)),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  ColoredBox(
                    color: widget.bleach ? Colors.white : Dye.abyss,
                    child: WebViewWidget(controller: _c),
                  ),
                  if (_busy)
                    const Center(child: CircularProgressIndicator(color: Dye.ember)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
