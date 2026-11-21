import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masjid_namaz_app/core/constants/app_colors.dart';
import 'package:masjid_namaz_app/core/constants/app_spacing.dart';
import 'package:masjid_namaz_app/core/network/api_service.dart';
import 'package:masjid_namaz_app/core/services/notification_service.dart';
import 'package:masjid_namaz_app/core/l10n/language_provider.dart';
import 'package:masjid_namaz_app/features/prayer_times/presentation/screens/home_screen.dart';
import 'package:masjid_namaz_app/features/admin/presentation/screens/super_admin_dashboard_screen.dart';
import 'package:masjid_namaz_app/features/masjid/presentation/screens/connect_masjid_screen.dart';
import 'package:masjid_namaz_app/features/auth/presentation/screens/onboarding_screen.dart';

class OtpLoginScreen extends ConsumerStatefulWidget {
  const OtpLoginScreen({super.key});

  @override
  ConsumerState<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends ConsumerState<OtpLoginScreen> {
  final TextEditingController _phoneController = TextEditingController(text: '1234567890');
  final TextEditingController _otpController = TextEditingController();
  bool _isSuperAdminFlow = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 1. Check if Super Admin
    if (phone.contains('1234567890')) {
      setState(() {
        _isLoading = false;
        _isSuperAdminFlow = true;
      });
      return;
    }

    // 2. Regular User: Check with backend database
    try {
      final checkRes = await ApiService.instance.checkUser(phone);
      final exists = checkRes['exists'] == true;
      final isOnboarded = checkRes['isOnboarded'] == true;

      if (exists && isOnboarded) {
        // Existing onboarded user -> Login directly with 120-day database session
        final loginRes = await ApiService.instance.loginDirect(phone);
        if (!mounted) return;

        // Configure FCM Push Notifications in background
        NotificationService.instance.configureAfterLogin();

        final hasMasjid = loginRes['hasMasjid'] == true;
        setState(() => _isLoading = false);

        if (hasMasjid) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ConnectMasjidScreen()),
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
          _errorMessage = 'Connection error: $e';
        });
      }
    }
  }

  Future<void> _handleSuperAdminVerify() async {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();

    if (otp != '123456') {
      setState(() => _errorMessage = 'Invalid Super Admin OTP. Use 123456');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.instance.verifyOtp(phone, otp);
      if (!mounted) return;

      NotificationService.instance.configureAfterLogin();
      setState(() => _isLoading = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SuperAdminDashboardScreen()),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Authentication failed: $e';
        });
      }
    }
  }

  void _showRegisterDialog(String phone) {
    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final lang = ref.read(languageProvider.notifier);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lang.tr(en: 'New User Registration', ta: 'புதிய பயனர் பதிவு'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  lang.tr(
                    en: 'Welcome! Please fill in your details to get started.',
                    ta: 'வரவேற்கிறோம்! தொடங்குவதற்கு உங்கள் விவரங்களை உள்ளிடவும்.',
                  ),
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),

                // Name
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: lang.tr(en: 'Full Name *', ta: 'முழு பெயர் *'),
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),

                // Age
                TextField(
                  controller: ageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: lang.tr(en: 'Age *', ta: 'வயது *'),
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),

                // Address
                TextField(
                  controller: addressCtrl,
                  decoration: InputDecoration(
                    labelText: lang.tr(en: 'Address (Optional)', ta: 'முகவரி (விருப்பத்தேர்வு)'),
                    prefixIcon: const Icon(Icons.location_city),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),

                // Submit Button
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final ageStr = ageCtrl.text.trim();
                    final address = addressCtrl.text.trim();

                    if (name.isEmpty || ageStr.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter name and age')),
                      );
                      return;
                    }

                    final age = int.tryParse(ageStr) ?? 25;
                    Navigator.pop(ctx);

                    setState(() => _isLoading = true);

                    try {
                      await ApiService.instance.register(
                        phone: phone,
                        name: name,
                        age: age,
                        address: address.isEmpty ? null : address,
                      );

                      if (!mounted) return;
                      NotificationService.instance.configureAfterLogin();
                      setState(() => _isLoading = false);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.green.shade800,
                          content: Text('Welcome, $name! Please connect to your Masjid.'),
                        ),
                      );

                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const ConnectMasjidScreen()),
                      );
                    } catch (e) {
                      if (mounted) {
                        setState(() {
                          _isLoading = false;
                          _errorMessage = 'Registration failed: $e';
                        });
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(lang.tr(en: 'Register & Continue', ta: 'பதிவு செய்து தொடர்க')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = ref.watch(languageProvider);
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
        actions: [
          TextButton(
            onPressed: () => lang.toggleLanguage(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                isEn ? 'தமிழ்' : 'English',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Logo
              const Center(
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primaryContainer,
                  child: Icon(Icons.mosque, size: 42, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                lang.tr(en: 'Welcome', ta: 'வணக்கம்'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                lang.tr(
                  en: 'Enter your mobile number to continue',
                  ta: 'தொடர உங்கள் மொபைல் எண்ணை உள்ளிடவும்',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),

              // Super Admin Quick Credentials Hint Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars, color: Colors.amber, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Super Admin Login: 1234567890',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            'Fixed OTP: 123456 (Full Control)',
                            style: TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.emergency, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Phone Input
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Row(
                  children: [
                    const Text('🇮🇳 +91', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    const Text('|', style: TextStyle(color: Colors.grey, fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontSize: 18, letterSpacing: 1.1),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: lang.tr(en: 'Mobile number', ta: 'மொபைல் எண்'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (_isSuperAdminFlow) ...[
                // Super Admin OTP Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                    maxLength: 6,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      hintText: lang.tr(en: 'Enter 123456', ta: '123456 ஐ உள்ளிடவும்'),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSuperAdminVerify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(lang.tr(en: 'Verify Super Admin', ta: 'உள்நுழைக')),
                ),
              ] else ...[
                // Direct Login Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(lang.tr(en: 'Login / Continue', ta: 'உள்நுழைக / தொடர்க')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
