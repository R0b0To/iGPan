import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/app_config.dart';
import '../../network/http_client.dart';
import '../theme/app_theme.dart';

class AccountWebViewScreen extends StatefulWidget {
  final String accountEmail;
  final String title;

  const AccountWebViewScreen({
    super.key,
    required this.accountEmail,
    required this.title,
  });

  @override
  State<AccountWebViewScreen> createState() => _AccountWebViewScreenState();
}

class _AccountWebViewScreenState extends State<AccountWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;
  
  // Flag to ensure we only inject Windows cookies once to prevent infinite reloads
  bool _needsWindowsCookieInjection = false;

  @override
  void initState() {
    super.initState();
    
    _needsWindowsCookieInjection = Platform.isWindows;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppTheme.surface)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (url) async {
          // ✨ WINDOWS WORKAROUND: Inject cookies via JavaScript ✨
          if (_needsWindowsCookieInjection && Platform.isWindows) {
            _needsWindowsCookieInjection = false; // Only do this once
            
            try {
              final uri = Uri.parse(AppConfig.baseUrl);
              final jar = HttpClient().jarFor(widget.accountEmail);
              final cookies = await jar.loadForRequest(uri);

              debugPrint('=== INJECTING ${cookies.length} COOKIES VIA JS ===');
              
              for (final cookie in cookies) {
                // Inject each cookie directly into the webpage's DOM
                final script = "document.cookie = '${cookie.name}=${cookie.value}; path=${cookie.path ?? '/'}; domain=${cookie.domain ?? uri.host};';";
                await _controller.runJavaScript(script);
              }
              
              debugPrint('=== COOKIES INJECTED. RELOADING PAGE. ===');
              // Reload the page so the website sees the newly injected cookies
              await _controller.reload();
            } catch (e) {
              debugPrint('Failed to inject Windows cookies: $e');
            }
          } else {
            // Normal page finish
            if (mounted) setState(() => _loading = false);
          }
        },
        onWebResourceError: (error) {
          if (mounted) {
            setState(() {
              _loading = false;
              _error = error.description;
            });
          }
        },
      ));
      
    _loadWithCookies();
  }

  Future<void> _loadWithCookies() async {
    try {
      // 1. Wipe previous browser data so different accounts don't overlap
      await _controller.clearCache();
      await _controller.clearLocalStorage();

      final uri = Uri.parse(AppConfig.homePage);
      final jar = HttpClient().jarFor(widget.accountEmail);
      final cookies = await jar.loadForRequest(uri);

      // --- DEBUG PRINT ---
      debugPrint('==== COOKIE DEBUG ====');
      debugPrint('Account: ${widget.accountEmail}');
      debugPrint('Target URL: $uri');
      debugPrint('Found ${cookies.length} cookies in Jar.');
      debugPrint('======================');

      // 2. Android / iOS Native Handling
      if (Platform.isAndroid || Platform.isIOS) {
        final cookieManager = WebViewCookieManager();
        await cookieManager.clearCookies();
        for (final cookie in cookies) {
          await cookieManager.setCookie(WebViewCookie(
            name:   cookie.name,
            value:  cookie.value,
            domain: cookie.domain ?? uri.host,
            path:   cookie.path ?? '/',
          ));
        }
      }

      // 3. Load the page
      // On Android: It will load perfectly logged in.
      // On Windows: It will load as guest -> trigger onPageFinished -> Inject JS cookies -> Reload logged in!
      await _controller.loadRequest(uri);

    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon:    const Icon(Icons.replay_rounded),
            tooltip: 'Reload',
            onPressed: () => _controller.reload(),
          ),
        ],
        // Progress bar sits in the AppBar so it's visible on Windows
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3.0),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 32, color: AppTheme.error),
                    const SizedBox(height: 12),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.onSurfaceDim, fontSize: 13)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() => _error = null);
                        _needsWindowsCookieInjection = Platform.isWindows; // Reset injection flag
                        _loadWithCookies();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : WebViewWidget(controller: _controller),
    );
  }
}