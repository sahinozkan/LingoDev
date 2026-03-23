import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'ui/views/login_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Status bar'ı şeffaf yap (premium dark tema için)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const LingoDev());
}

class LingoDev extends StatelessWidget {
  const LingoDev({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LingoDev',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const LoginView(),
    );
  }
}
