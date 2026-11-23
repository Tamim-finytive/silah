import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masjid_namaz_app/core/constants/app_colors.dart';
import 'package:masjid_namaz_app/core/constants/app_spacing.dart';
import 'package:masjid_namaz_app/core/network/api_service.dart';
import 'package:masjid_namaz_app/core/services/notification_service.dart';
import 'package:masjid_namaz_app/core/l10n/language_provider.dart';
import 'package:masjid_namaz_app/features/prayer_times/presentation/screens/home_screen.dart';
import 'package:masjid_namaz_app/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:masjid_namaz_app/features/masjid/presentation/widgets/location_input_widget.dart';

enum UserRoleChoice {
  regularUser,
  masjidAdmin,
}

class OnboardingScreen extends ConsumerStatefulWidget {
  final String phone;

  const OnboardingScreen({
    super.key,
    required this.phone,
  });

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentStep =
      0; // 0: Personal Info, 1: Role Selection, 2: Masjid Details
  bool _isLoading = false;
  String? _errorMessage;

  // Step 1: User Profile Form
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();

  // Step 2: Role
  UserRoleChoice _selectedRole = UserRoleChoice.regularUser;

  // Step 3: Masjid Form (for Masjid Admin)
  final _masjidNameController = TextEditingController();
  final _masjidNameTaController = TextEditingController();
  final _masjidCityController = TextEditingController(text: 'Chennai');
  final _masjidAddressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _mapUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchExistingUser();
  }

  Future<void> _fetchExistingUser() async {
    try {
      final res = await ApiService.instance.checkUser(widget.phone);
      if (res['exists'] == true &&
          res['name'] != null &&
          (res['name'] as String).isNotEmpty) {
        if (mounted) {
          setState(() {
            _nameController.text = res['name'] ?? '';
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _masjidNameController.dispose();
    _masjidNameTaController.dispose();
    _masjidCityController.dispose();
    _masjidAddressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _mapUrlController.dispose();
    super.dispose();
  }

  Future<void> _handleStep1Next() async {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your full name');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Persist to backend database directly on Step 1
      await ApiService.instance.register(
        phone: widget.phone,
        name: name,
        address: address.isEmpty ? null : address,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _currentStep = 1;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to save profile: $e';
        });
      }
    }
  }

  Future<void> _handleRoleSelectionSubmit() async {
    if (_selectedRole == UserRoleChoice.masjidAdmin) {
      // Move to Step 3 (Masjid Setup)
      setState(() {
        _errorMessage = null;
        _currentStep = 2;
      });
    } else {
      // User profile already stored in backend -> Route directly to HomeScreen with all nav bars!
      NotificationService.instance.configureAfterLogin();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  Future<void> _submitMasjidAdminRegistration() async {
    final masjidName = _masjidNameController.text.trim();
    final city = _masjidCityController.text.trim();
    final masjidAddress = _masjidAddressController.text.trim();
    final latStr = _latController.text.trim();
    final lngStr = _lngController.text.trim();

    if (masjidName.isEmpty) {
      setState(() => _errorMessage = 'Please enter the Masjid name');
      return;
    }
    if (city.isEmpty || masjidAddress.isEmpty) {
      setState(() => _errorMessage = 'Please enter city and address');
      return;
    }

    final lat = double.tryParse(latStr);
    final lng = double.tryParse(lngStr);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Register user profile
      final name = _nameController.text.trim();
      final address = _addressController.text.trim();

      await ApiService.instance.register(
        phone: widget.phone,
        name: name,
        address: address.isEmpty ? null : address,
      );

      // 2. Submit Masjid creation request with this user as designated Admin
      await ApiService.instance.createMasjid(
        name: masjidName,
        city: city,
        address: masjidAddress,
        nameTa: _masjidNameTaController.text.trim(),
        latitude: lat,
        longitude: lng,
        mapUrl: _mapUrlController.text.trim().isEmpty
            ? null
            : _mapUrlController.text.trim(),
        adminName: name,
        adminPhone: widget.phone,
      );

      // Hydrate profile so user is immediately assigned as Masjid Admin
      try {
        await ApiService.instance.getProfile();
      } catch (_) {}

      if (!mounted) return;
      NotificationService.instance.configureAfterLogin();
      setState(() => _isLoading = false);

      // Show Admin Confirmation Dialog
      _showRequestSubmittedDialog(masjidName);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().contains('Duplicate')
              ? 'Duplicate Detected: A masjid is already registered near these coordinates or name.'
              : 'Failed to submit masjid request: $e';
        });
      }
    }
  }

  void _showRequestSubmittedDialog(String masjidName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('Masjid Registered'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your masjid "$masjidName" is registered and active! You are authorized as administrator.',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F432B).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF0F432B).withValues(alpha: 0.3)),
              ),
              child: const Text(
                'You can now update prayer timings, generate member QR codes, post community announcements, and manage your congregation.',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Admin Dashboard'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final lang = ref.read(languageProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(lang.tr(en: 'Getting Started', ta: 'தொடங்குதல்')),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  // Step Progress Tracker
                  _buildProgressIndicator(),
                  const SizedBox(height: 24),

                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                  color: Colors.red.shade900, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Content based on step
                  if (_currentStep == 0) _buildStep1PersonalInfo(lang),
                  if (_currentStep == 1) _buildStep2RoleSelection(lang),
                  if (_currentStep == 2) _buildStep3MasjidDetails(lang),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final showMasjidStep = _selectedRole == UserRoleChoice.masjidAdmin;
    return Row(
      children: [
        _buildStepBadge(1, 'Profile', _currentStep >= 0),
        Expanded(
            child: Container(
                height: 2,
                color: _currentStep >= 1
                    ? AppColors.primary
                    : Colors.grey.shade300)),
        _buildStepBadge(2, 'Role', _currentStep >= 1),
        if (showMasjidStep) ...[
          Expanded(
              child: Container(
                  height: 2,
                  color: _currentStep >= 2
                      ? AppColors.primary
                      : Colors.grey.shade300)),
          _buildStepBadge(3, 'Masjid', _currentStep >= 2),
        ],
      ],
    );
  }

  Widget _buildStepBadge(int number, String label, bool isActive) {
    return Column(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: isActive ? AppColors.primary : Colors.grey.shade300,
          child: Text(
            '$number',
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? AppColors.primary : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // STEP 1: Personal Profile
  Widget _buildStep1PersonalInfo(LanguageNotifier lang) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.person, color: AppColors.primary, size: 28),
              SizedBox(width: 10),
              Text(
                'Tell us about yourself',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            lang.tr(
              en: 'Your mobile number is verified: ${widget.phone}',
              ta: 'உங்கள் மொபைல் எண் சரிபார்க்கப்பட்டது: ${widget.phone}',
            ),
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Name
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText:
                  lang.tr(en: 'Your Full Name *', ta: 'உங்கள் முழு பெயர் *'),
              hintText: 'e.g. Mohamed Riyaz',
              prefixIcon: const Icon(Icons.badge_outlined),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),

          // Address
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: lang.tr(
                  en: 'Address / Area (Optional)',
                  ta: 'முகவரி (விருப்பத்தேர்வு)'),
              hintText: 'e.g. Anna Nagar, Chennai',
              prefixIcon: const Icon(Icons.location_on_outlined),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isLoading ? null : _handleStep1Next,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                          lang.tr(en: 'Save & Continue', ta: 'சேமித்து தொடர்க'),
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // STEP 2: Role Selection
  Widget _buildStep2RoleSelection(LanguageNotifier lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'How will you be using this app?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Select your primary role. You can always change or request permissions later.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 20),

        // Choice A: Regular Devotee
        _buildRoleCard(
          role: UserRoleChoice.regularUser,
          icon: Icons.person_pin_circle_outlined,
          title: lang.tr(
              en: 'Regular Musalli / Devotee',
              ta: 'தொழுகையாளி (வழக்கமான பயனர்)'),
          subtitle: lang.tr(
            en: 'Follow your local masjid, see daily Namaz times, live notifications & pay monthly sandha.',
            ta: 'பள்ளிவாசலைப் பின்தொடரவும், தொழுகை நேரங்களை அறியவும், அறிவிப்புகள் பெறவும்.',
          ),
          isRecommended: true,
        ),
        const SizedBox(height: 14),

        // Choice B: Masjid Admin
        _buildRoleCard(
          role: UserRoleChoice.masjidAdmin,
          icon: Icons.mosque_outlined,
          title: lang.tr(
              en: 'Masjid Administrator / Trustee',
              ta: 'பள்ளிவாசல் நிர்வாகி / டிரஸ்டி'),
          subtitle: lang.tr(
            en: 'Register a new Masjid, set Adhan/Jamaah timings, pass announcements & manage members.',
            ta: 'புதிய பள்ளிவாசலை பதிவு செய்யவும், நேரங்களை அமைக்கவும், அறிவிப்புகளை வெளியிடவும்.',
          ),
          isRecommended: false,
        ),
        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _isLoading ? null : _handleRoleSelectionSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(
                  _selectedRole == UserRoleChoice.masjidAdmin
                      ? lang.tr(
                          en: 'Proceed to Register Masjid',
                          ta: 'பள்ளிவாசல் பதிவு செய்க')
                      : lang.tr(
                          en: 'Complete & Go to App',
                          ta: 'பதிவை முடித்து தொடர்க'),
                  style: const TextStyle(fontSize: 16),
                ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _currentStep = 0),
          child: Text(lang.tr(
              en: '← Back to Profile', ta: '← சுயவிவரத்திற்கு திரும்பு')),
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required UserRoleChoice role,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isRecommended,
  }) {
    final isSelected = _selectedRole == role;

    return InkWell(
      onTap: () => setState(() => _selectedRole = role),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryContainer.withOpacity(0.4)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor:
                  isSelected ? AppColors.primary : Colors.grey.shade100,
              child: Icon(icon,
                  color: isSelected ? Colors.white : AppColors.primary,
                  size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isRecommended)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('DEFAULT',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // STEP 3: Masjid Setup (For Masjid Admin)
  Widget _buildStep3MasjidDetails(LanguageNotifier lang) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.add_business, color: AppColors.primary, size: 26),
              SizedBox(width: 10),
              Text(
                'Register Masjid',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Provide accurate details and GPS location to prevent duplicate entries.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Masjid Name
          TextField(
            controller: _masjidNameController,
            decoration: InputDecoration(
              labelText: lang.tr(
                  en: 'Masjid Name (English) *',
                  ta: 'பள்ளிவாசல் பெயர் (English) *'),
              hintText: 'e.g. City Central Masjid',
              prefixIcon: const Icon(Icons.mosque),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),

          // Masjid Name Tamil (Optional)
          TextField(
            controller: _masjidNameTaController,
            decoration: InputDecoration(
              labelText: lang.tr(
                  en: 'Masjid Name (Tamil) - Optional',
                  ta: 'பள்ளிவாசல் பெயர் (தமிழ்)'),
              hintText: 'எ.கா: ஜாமியா பள்ளிவாசல்',
              prefixIcon: const Icon(Icons.translate),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),

          // City
          TextField(
            controller: _masjidCityController,
            decoration: InputDecoration(
              labelText: lang.tr(en: 'City *', ta: 'நகரம் *'),
              hintText: 'e.g. Chennai',
              prefixIcon: const Icon(Icons.location_city),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),

          // Address
          TextField(
            controller: _masjidAddressController,
            decoration: InputDecoration(
              labelText:
                  lang.tr(en: 'Full Detailed Address *', ta: 'முழு முகவரி *'),
              hintText: 'Door No, Street Name, Area, Pincode',
              prefixIcon: const Icon(Icons.signpost_outlined),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 18),

          // Location: Google Maps Link or Manual Lat & Lng
          LocationInputWidget(
            latController: _latController,
            lngController: _lngController,
            mapUrlController: _mapUrlController,
            masjidNameController: _masjidNameController,
            cityController: _masjidCityController,
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isLoading ? null : _submitMasjidAdminRegistration,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Submit Request to Super Admin',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => setState(() => _currentStep = 1),
            child: const Text('← Back to Role Selection'),
          ),
        ],
      ),
    );
  }
}
