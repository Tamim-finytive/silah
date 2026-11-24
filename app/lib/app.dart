import 'package:masjid_namaz_app/core/constants/app_colors.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/l10n/language_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/network/api_service.dart';
import 'core/services/notification_service.dart';
import 'features/auth/presentation/screens/otp_login_screen.dart';
import 'features/auth/presentation/screens/onboarding_screen.dart';
import 'features/prayer_times/presentation/screens/home_screen.dart';
import 'features/admin/presentation/screens/super_admin_dashboard_screen.dart';
import 'features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'features/announcements/presentation/screens/announcements_screen.dart';

final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class MasjidApp extends ConsumerWidget {
  const MasjidApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageCode = ref.watch(languageProvider);
    return MaterialApp(
      title: 'Silah Community Adhan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      navigatorKey: appNavigatorKey,
      builder: (context, child) => Directionality(
        textDirection: languageCode == 'ar' || languageCode == 'ur'
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const _InAppNotificationBridge(child: AppStartupGate()),
    );
  }
}

class _InAppNotificationBridge extends StatefulWidget {
  final Widget child;

  const _InAppNotificationBridge({required this.child});

  @override
  State<_InAppNotificationBridge> createState() =>
      _InAppNotificationBridgeState();
}

class _InAppNotificationBridgeState extends State<_InAppNotificationBridge> {
  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription =
        NotificationService.instance.notificationEvents.listen((event) {
      if (event['opened'] == true) return;
      final title = event['title']?.toString().trim() ?? '';
      final body = event['body']?.toString().trim() ?? '';
      if (title.isEmpty && body.isEmpty) return;

      appScaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 7),
            backgroundColor: AppColors.primary,
            content: Row(
              children: [
                const Icon(Icons.notifications_active_outlined,
                    color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title.isNotEmpty)
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      if (body.isNotEmpty)
                        Text(body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'OPEN',
              textColor: const Color(0xFFD4E9D9),
              onPressed: () async {
                if (event['type'] == 'MASJID_ADMIN_APPROVED') {
                  final profile = await ApiService.instance.getProfile();
                  final roles = profile?['adminRoles'] as List<dynamic>? ??
                      ApiService.instance.currentUser?['adminRoles']
                          as List<dynamic>? ??
                      const [];
                  final masjidId = event['masjidId']?.toString();
                  Map<String, dynamic>? approvedRole;
                  for (final role in roles) {
                    if (role is Map<String, dynamic> &&
                        (masjidId == null ||
                            role['masjidId']?.toString() == masjidId)) {
                      approvedRole = role;
                      break;
                    }
                  }
                  if (approvedRole != null) {
                    appNavigatorKey.currentState?.pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => AdminDashboardScreen(
                          masjidId: approvedRole?['masjidId']?.toString(),
                          masjidName: approvedRole?['masjidName']?.toString(),
                        ),
                      ),
                    );
                    return;
                  }
                  appScaffoldMessengerKey.currentState?.showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Approval is being updated. Please reopen Silah in a moment.'),
                    ),
                  );
                  return;
                }
                appNavigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (_) => AnnouncementsScreen(
                      masjidId: event['masjidId']?.toString(),
                      focusAnnouncementId: event['id']?.toString(),
                    ),
                  ),
                );
              },
            ),
          ),
        );
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class AppStartupGate extends StatefulWidget {
  const AppStartupGate({super.key});

  @override
  State<AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends State<AppStartupGate> {
  @override
  void initState() {
    super.initState();
    _checkSessionAndNavigate();
  }

  Future<void> _checkSessionAndNavigate() async {
    final hasSession = await ApiService.instance.initSession();
    if (!mounted) return;

    if (hasSession && ApiService.instance.currentUser != null) {
      final user = ApiService.instance.currentUser!;
      final isSuperAdmin = ApiService.instance.isSuperAdmin;

      // 1. Super Admin route
      if (isSuperAdmin) {
        NotificationService.instance.configureAfterLogin();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SuperAdminDashboardScreen()),
        );
        return;
      }

      // 2. Check if user is Masjid Admin
      final adminRoles = user['adminRoles'] as List<dynamic>?;
      if (adminRoles != null && adminRoles.isNotEmpty) {
        NotificationService.instance.configureAfterLogin();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
        return;
      }

      // 3. Incomplete onboarding route
      final isOnboarded = user['isOnboarded'] == true ||
          (user['name'] != null &&
              user['name'].toString().trim().isNotEmpty &&
              user['name'].toString().trim() != 'User');
      if (!isOnboarded) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                OnboardingScreen(phone: user['phone']?.toString() ?? ''),
          ),
        );
        return;
      }

      // 4. Regular Musalli -> Home Screen (with bottom nav bar)
      NotificationService.instance.configureAfterLogin();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      // No active session -> OtpLoginScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OtpLoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
