import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network/http_client.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait — multi-account dashboard works best in portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI colours to match dark theme
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:                   Colors.transparent,
    statusBarIconBrightness:          Brightness.light,
    systemNavigationBarColor:         AppTheme.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Set up Dio + per-account cookie jars before any request fires
  await HttpClient().initialize();

  runApp(
    const ProviderScope(
      child: IgpanApp(),
    ),
  );
}

class IgpanApp extends StatelessWidget {
  const IgpanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                'iGPan',
      debugShowCheckedModeBanner: false,
      theme:                AppTheme.dark,
      home:                 const HomeScreen(),
    );
  }
}