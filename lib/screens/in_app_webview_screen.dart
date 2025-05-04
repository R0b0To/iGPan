import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart' as webview_flutter; // Add prefix back
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart' as dio_cookie_manager; // Keep prefix

class InAppWebViewScreen extends StatefulWidget {
  final String initialUrl;
  final Dio dioInstance;
  final String accountNickname;

  const InAppWebViewScreen({
    super.key,
    required this.initialUrl,
    required this.dioInstance,
    required this.accountNickname,
  });

  @override
  State<InAppWebViewScreen> createState() => _InAppWebViewScreenState();
}

class _InAppWebViewScreenState extends State<InAppWebViewScreen> {
  late final webview_flutter.WebViewController _controller;

  @override
  void initState() {
    super.initState();



    _controller = webview_flutter.WebViewController()
      ..setJavaScriptMode(webview_flutter.JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        webview_flutter.NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onWebResourceError: (webview_flutter.WebResourceError error) {},
          onNavigationRequest: (webview_flutter.NavigationRequest request) {
            return webview_flutter.NavigationDecision.navigate;
          },
        ),
      );

    _loadUrlWithCookies();
  }

  Future<void> _loadUrlWithCookies() async {
    try {
      // Get the CookieJar from the Dio instance's interceptors
      CookieJar? cookieJar;
      for (var interceptor in widget.dioInstance.interceptors) {
        if (interceptor is dio_cookie_manager.CookieManager) { // Use the correct type
          cookieJar = interceptor.cookieJar;
          break;
        }
      }

      if (cookieJar != null) {
        final uri = Uri.parse(widget.initialUrl);
        final cookies = await cookieJar.loadForRequest(uri);

        final webviewCookieManager = webview_flutter.WebViewCookieManager();
        for (var cookie in cookies) {
          await webviewCookieManager.setCookie(
            webview_flutter.WebViewCookie(
              name:cookie.name,
              value: cookie.value,
              domain: cookie.domain??'',
            ),
          );
        }
      }

      _controller.loadRequest(Uri.parse(widget.initialUrl));
    } catch (e) {
      debugPrint('Error loading URL with cookies: $e');

    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.accountNickname)),
      body: webview_flutter.WebViewWidget(controller: _controller),
    );
  }
}