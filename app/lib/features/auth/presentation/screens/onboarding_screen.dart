import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masjid_namaz_app/core/constants/app_colors.dart';
import 'package:masjid_namaz_app/core/constants/app_spacing.dart';
import 'package:masjid_namaz_app/core/l10n/language_provider.dart';
import 'package:masjid_namaz_app/core/network/api_service.dart';
import 'package:masjid_namaz_app/core/services/notification_service.dart';
import 'package:masjid_namaz_app/features/prayer_times/presentation/screens/home_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final String phone;

  const OnboardingScreen({super.key, required this.phone});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchExistingUser();
  }

  Future<void> _fetchExistingUser() async {
    try {
      final user = await ApiService.instance.checkUser(widget.phone);
      if (!mounted) return;
      setState(() => _nameController.text = user['name']?.toString() ?? '');
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _registerAndContinue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your full name.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ApiService.instance.register(
        phone: widget.phone,
        name: name,
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
      );
      await ApiService.instance.getProfile();
      unawaited(NotificationService.instance.configureAfterLogin());
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiService.getErrorMessage(
          error,
          fallback: 'Could not save your profile. Please try again.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final language = ref.read(languageProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(language.tr(en: 'Create your profile', ta: 'சுயவிவரம்')),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: AppSpacing.screenPadding,
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.person_add_alt_1,
                    size: 48, color: AppColors.primary),
                const SizedBox(height: 18),
                Text(
                  language.tr(en: 'Welcome to Silah', ta: 'சிலாஹ் வரவேற்கிறது'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  language.tr(
                    en: 'Add your name and, if you like, your address. You can start using the app right away.',
                    ta: 'உங்கள் பெயரையும் விருப்பமிருந்தால் முகவரியையும் சேர்த்து உடனே செயலியைப் பயன்படுத்துங்கள்.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Full name *',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _addressController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Address (optional)',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(_errorMessage!,
                      style: const TextStyle(color: AppColors.emergency)),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _registerAndContinue,
                  icon: _isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.arrow_forward),
                  label: Text(language.tr(
                      en: 'Save and open Silah', ta: 'சேமித்து தொடர்க')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
