import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/otp_login_screen.dart';

class MasjidApp extends ConsumerWidget {
  const MasjidApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Masjid Namaz',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const OtpLoginScreen(),
    );
  }
}
