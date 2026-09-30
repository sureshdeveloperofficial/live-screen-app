import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/app_theme.dart';
import 'core/constants.dart';
import 'screens/home_screen.dart';
import 'services/app_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fix orientation and set dark system overlays
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await AppController.instance.initialize();

  runApp(const ViziLinkApp());
}

class ViziLinkApp extends StatelessWidget {
  const ViziLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
