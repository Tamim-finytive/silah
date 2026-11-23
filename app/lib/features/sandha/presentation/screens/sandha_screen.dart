import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/l10n/language_provider.dart';
import '../../../../core/network/api_service.dart';
import '../../../masjid/presentation/screens/connect_masjid_screen.dart';
import '../../../prayer_times/data/prayer_times_provider.dart';

class SandhaScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const SandhaScreen({super.key, this.onBack});

  @override
  ConsumerState<SandhaScreen> createState() => _SandhaScreenState();
}

class _SandhaScreenState extends ConsumerState<SandhaScreen> {
  bool _isLoading = true;
  List<dynamic> _enrollments = [];
  List<dynamic> _plans = [];

  @override
  void initState() {
    super.initState();
    _fetchSandhaData();
  }

  Future<void> _fetchSandhaData() async {
    setState(() => _isLoading = true);
    final masjid = ref.read(prayerTimesProvider).activeMasjid;
    final masjidId = masjid?['id'];

    if (masjidId != null) {
      final enrollments =
          await ApiService.instance.getUserSandhaStatus(masjidId);
      final plans = await ApiService.instance.getMasjidSandhaPlans(masjidId);
      if (mounted) {
        setState(() {
          _enrollments = enrollments;
          _plans = plans;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _enrollments = [];
          _plans = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final lang = ref.read(languageProvider.notifier);
    final activeMasjid = ref.watch(prayerTimesProvider).activeMasjid;
    final masjidName = activeMasjid?['name'] ?? 'Masjid';

    return Scaffold(
      appBar: AppBar(
        leading: (widget.onBack != null || Navigator.canPop(context))
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: () {
                  if (widget.onBack != null) {
                    widget.onBack!();
                  } else if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              )
            : null,
        title: Text(lang.tr(en: 'Sandha', ta: 'சந்தா விவரம்')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSandhaData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _enrollments.isEmpty && _plans.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.volunteer_activism_outlined,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              lang.tr(
                                en: activeMasjid == null
                                    ? 'Connect a masjid to view Sandha'
                                    : 'No contribution plans yet',
                                ta: activeMasjid == null
                                    ? 'சந்தா விவரங்களைப் பார்க்க பள்ளிவாசலுடன் இணையுங்கள்'
                                    : 'சந்தா திட்டம் எதுவும் இல்லை',
                              ),
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              lang.tr(
                                en: activeMasjid == null
                                    ? 'Connect to a masjid to view its Sandha updates.'
                                    : 'No Sandha plans are active for $masjidName yet. Your masjid administration will post contribution details here.',
                                ta: activeMasjid == null
                                    ? 'சந்தா விவரங்களைப் பார்க்க ஒரு பள்ளிவாசலுடன் இணையுங்கள்.'
                                    : '$masjidName பள்ளிவாசலில் சந்தா திட்டங்கள் இன்னும் இல்லை. நிர்வாகம் திட்டத்தை வெளியிட்டதும் இங்கே காணலாம்.',
                              ),
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),
                            if (activeMasjid == null)
                              FilledButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ConnectMasjidScreen(),
                                  ),
                                ),
                                icon: const Icon(Icons.mosque_outlined),
                                label: Text(lang.tr(
                                  en: 'Find a masjid',
                                  ta: 'பள்ளிவாசலைத் தேடு',
                                )),
                              )
                            else
                              OutlinedButton.icon(
                                onPressed: _fetchSandhaData,
                                icon: const Icon(Icons.refresh),
                                label: Text(lang.tr(
                                  en: 'Refresh plans',
                                  ta: 'திட்டங்களை மீண்டும் ஏற்று',
                                )),
                              ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchSandhaData,
                      child: SingleChildScrollView(
                        padding: AppSpacing.screenPadding,
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Current Plan Card
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.outline),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        lang.tr(
                                          en: 'Monthly contribution',
                                          ta: 'மாதாந்திர சந்தா',
                                        ),
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _enrollments.isNotEmpty
                                              ? AppColors.primaryContainer
                                              : Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _enrollments.isNotEmpty
                                              ? lang.tr(
                                                  en: 'Active',
                                                  ta: 'செயலில் உள்ளது',
                                                )
                                              : lang.tr(
                                                  en: 'Not enrolled',
                                                  ta: 'பதிவு செய்யப்படவில்லை',
                                                ),
                                          style: TextStyle(
                                            color: _enrollments.isNotEmpty
                                                ? AppColors.primary
                                                : Colors.grey.shade700,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _enrollments.isNotEmpty
                                        ? '${_enrollments.first['plan']?['name'] ?? lang.tr(en: 'General Fund', ta: 'பொது நிதி')} • ₹${_enrollments.first['plan']?['amount'] ?? _enrollments.first['plan']?['monthlyAmount'] ?? '0'} / ${lang.tr(en: 'month', ta: 'மாதம்')}'
                                        : lang.tr(
                                            en: '$masjidName Community Fund',
                                            ta: '$masjidName சமூக நிதி',
                                          ),
                                    style: const TextStyle(
                                        color: AppColors.textSecondary),
                                  ),
                                  const Divider(height: 24),
                                  Text(
                                    lang.tr(
                                      en: 'Your monthly contribution supports masjid care and community services.',
                                      ta: 'பள்ளிவாசல் பராமரிப்பு மற்றும் சமூக நலத்திற்கான உங்கள் மாதாந்திர பங்களிப்பு.',
                                    ),
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Active Plans in Masjid
                            if (_plans.isNotEmpty) ...[
                              Text(
                                lang.tr(
                                    en: 'Available plans',
                                    ta: 'கிடைக்கும் திட்டங்கள்'),
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 10),
                              ..._plans.map((p) {
                                final planAmount =
                                    p['amount'] ?? p['monthlyAmount'] ?? '0';
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor:
                                          AppColors.primaryContainer,
                                      child: Icon(Icons.currency_rupee,
                                          color: AppColors.primary, size: 20),
                                    ),
                                    title: Text(
                                        p['name'] ??
                                            lang.tr(
                                              en: 'Sandha plan',
                                              ta: 'சந்தா திட்டம்',
                                            ),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    subtitle: Text(p['description'] ??
                                        lang.tr(
                                          en: 'Monthly contribution',
                                          ta: 'மாதாந்திர பங்களிப்பு',
                                        )),
                                    trailing: Text(
                                      lang.tr(
                                        en: '₹$planAmount/mo',
                                        ta: '₹$planAmount/மாதம்',
                                      ),
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ),
        ),
      ),
    );
  }
}
