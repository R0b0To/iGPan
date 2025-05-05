import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart' as dio_cookie_manager;
import 'dart:io' show Platform; // Import Platform

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
  InAppWebViewController? _webViewController;
  final CookieManager _cookieManager = CookieManager.instance();
  final GlobalKey webViewKey = GlobalKey();

  InAppWebViewSettings settings = InAppWebViewSettings(
      useShouldOverrideUrlLoading: true,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      iframeAllow: "camera; microphone",
      iframeAllowFullscreen: true);

  PullToRefreshController? pullToRefreshController;
  double progress = 0;


  @override
  void initState() {
    super.initState();

    // Initialize pullToRefreshController only if not on Windows
    if (!Platform.isWindows) {
      pullToRefreshController = PullToRefreshController(
        settings: PullToRefreshSettings(
          color: Colors.blue, // Or your preferred color
        ),
        onRefresh: () async {
          // Standard refresh logic for Android/iOS
          if (Platform.isAndroid) {
            _webViewController?.reload();
          } else if (Platform.isIOS) {
            _webViewController?.loadUrl(
                urlRequest: URLRequest(url: await _webViewController?.getUrl()));
          }
        },
      );
    }

  }

  Future<void> _setCookiesFromDio() async {
    try {
      CookieJar? cookieJar;
      for (var interceptor in widget.dioInstance.interceptors) {
        if (interceptor is dio_cookie_manager.CookieManager) {
          cookieJar = interceptor.cookieJar;
          break;
        }
      }

      if (cookieJar != null) {
        final uri = Uri.parse(widget.initialUrl);
        final cookies = await cookieJar.loadForRequest(uri);

        for (var cookie in cookies) {
          await _cookieManager.setCookie(
            url: WebUri.uri(uri), // Convert Uri to WebUri
            name: cookie.name,
            value: cookie.value,
            domain: cookie.domain,
            path: cookie.path ?? '/', // Provide default path if null
            expiresDate: cookie.expires?.millisecondsSinceEpoch,
            isSecure: cookie.secure,
            isHttpOnly: cookie.httpOnly,
            sameSite: HTTPCookieSameSitePolicy.LAX, // Use correct enum
          );
        }
         debugPrint('Cookies set successfully for ${uri.host}');
      } else {
         debugPrint('CookieJar not found in Dio instance.');
      }
    } catch (e) {
      debugPrint('Error setting cookies: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.accountNickname)),
      body: Column(
        children: [
           progress < 1.0
              ? LinearProgressIndicator(value: progress)
              : Container(),
          Expanded(
            child: InAppWebView(
              key: webViewKey,
              initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
              initialSettings: settings,
              pullToRefreshController: pullToRefreshController,
              onWebViewCreated: (controller) async {
                _webViewController = controller;
                // Set cookies *before* loading the initial URL
                 await _setCookiesFromDio(); // Temporarily comment out for debugging

                // No need to call loadRequest here, initialUrlRequest handles it
              },
              onLoadStart: (controller, url) {
                 debugPrint('Page started loading: $url');
              },
              onLoadStop: (controller, url) async {
                 debugPrint('Page finished loading: $url');
                pullToRefreshController?.endRefreshing();
              },
               onReceivedError: (controller, request, error) {
                pullToRefreshController?.endRefreshing();
                debugPrint('WebView error: ${error.description}');
              },
              onProgressChanged: (controller, progress) {
                if (progress == 100) {
                  pullToRefreshController?.endRefreshing();
                }
                setState(() {
                  this.progress = progress / 100;
                });
              },
              onUpdateVisitedHistory: (controller, url, androidIsReload) {
                 debugPrint('Visited history updated: $url');
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                // Allow all navigation requests
                return NavigationActionPolicy.ALLOW;
              },
              onConsoleMessage: (controller, consoleMessage) {
                debugPrint('Console Message: ${consoleMessage.message}');
              },
              // Add explicit permission handling for debugging
              onPermissionRequest: (controller, request) async {
                 debugPrint('Permission requested for origin: ${request.origin}, resources: ${request.resources}');
                // Grant the permission explicitly
                return PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.GRANT);
              },
            ),
          ),
        ],
      ),
    );
  }
}