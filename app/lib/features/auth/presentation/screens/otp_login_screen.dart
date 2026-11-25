import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masjid_namaz_app/core/constants/app_colors.dart';
import 'package:masjid_namaz_app/core/constants/app_spacing.dart';
import 'package:masjid_namaz_app/core/network/api_service.dart';
import 'package:masjid_namaz_app/core/services/notification_service.dart';
import 'package:masjid_namaz_app/core/l10n/language_provider.dart';
import 'package:masjid_namaz_app/features/prayer_times/presentation/screens/home_screen.dart';
import 'package:masjid_namaz_app/features/admin/presentation/screens/super_admin_dashboard_screen.dart';
import 'package:masjid_namaz_app/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:masjid_namaz_app/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:masjid_namaz_app/features/auth/presentation/screens/contact_us_screen.dart';

class OtpLoginScreen extends ConsumerStatefulWidget {
  const OtpLoginScreen({super.key});

  @override
  ConsumerState<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends ConsumerState<OtpLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      setState(
          () => _errorMessage = 'Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Resolve every account and role from the backend before choosing a login flow.
    try {
      final checkRes = await ApiService.instance.checkUser(phone);
      final exists = checkRes['exists'] == true;
      final isOnboarded = checkRes['isOnboarded'] == true;
      final isMasjidAdmin = checkRes['isMasjidAdmin'] == true;
      final isSuperAdmin = checkRes['isSuperAdmin'] == true;

      if (exists && (isOnboarded || isMasjidAdmin || isSuperAdmin)) {
        final login = await ApiService.instance.loginDirect(phone);
        if (login['success'] != true ||
            ApiService.instance.currentUser == null) {
          throw StateError(
              'The account could not be signed in. Please try again.');
        }
        final user = await ApiService.instance.getProfile() ??
            ApiService.instance.currentUser;
        if (!mounted) return;

        // Configure FCM Push Notifications in background
        NotificationService.instance.configureAfterLogin();
        setState(() => _isLoading = false);

        // Check user role privileges: Super Admin, Masjid Admin, or Musalli
        if (user?['isSuperAdmin'] == true) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const SuperAdminDashboardScreen()),
          );
        } else if ((user?['adminRoles'] as List<dynamic>?)?.isNotEmpty ==
            true) {
          final adminRoles = user!['adminRoles'] as List<dynamic>;
          final firstAdminRole =
              adminRoles.first is Map ? adminRoles.first as Map : null;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AdminDashboardScreen(
                masjidId: firstAdminRole?['masjidId']?.toString(),
                masjidName: firstAdminRole?['masjidName']?.toString(),
              ),
            ),
          );
        } else {
          // Direct to User Home Screen with complete bottom navigation bar
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        // New user or onboarding incomplete -> Open modern Onboarding flow
        setState(() => _isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OnboardingScreen(phone: phone)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ApiService.getErrorMessage(e,
              fallback: 'Connection error. Please try again.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final lang = ref.read(languageProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            }
          },
        ),
        title: Text(lang.tr(en: 'Sign In', ta: 'உள்நுழைவு')),
        actions: const [],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  // Logo
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'asset/logo.png',
                          width: 76,
                          height: 76,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    lang.tr(
                      en: 'Assalamu Alaikum wa Rahmatullah',
                      ta: 'அஸ்ஸலாமு அலைக்கும் வரஹ்மத்துல்லாஹ்',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lang.tr(
                      en: 'Enter your mobile number to continue',
                      ta: 'தொடர உங்கள் மொபைல் எண்ணை உள்ளிடவும்',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),

                  const SizedBox(height: 24),

                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: AppColors.emergency,
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Phone Input
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Row(
                      children: [
                        const Text('🇮🇳 +91',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        const Text('|',
                            style: TextStyle(color: Colors.grey, fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(
                                fontSize: 18, letterSpacing: 1.1),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: lang.tr(
                                  en: 'Mobile number', ta: 'மொபைல் எண்'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(lang.tr(
                            en: 'Login / Continue', ta: 'உள்நுழைக / தொடர்க')),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ContactUsScreen(
                                  initialPhone: _phoneController.text.trim(),
                                ),
                              ),
                            ),
                    icon: const Icon(Icons.support_agent_outlined),
                    label: Text(lang.tr(
                        en: 'Contact Us', ta: 'எங்களை தொடர்பு கொள்ளுங்கள்')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
