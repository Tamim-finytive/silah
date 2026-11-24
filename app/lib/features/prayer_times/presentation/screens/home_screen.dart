import 'package:masjid_namaz_app/core/constants/app_colors.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:masjid_namaz_app/core/network/api_service.dart';
import 'package:masjid_namaz_app/core/l10n/language_provider.dart';
import 'package:masjid_namaz_app/core/services/notification_service.dart';
import 'package:masjid_namaz_app/core/utils/prayer_time_format.dart';
import 'package:masjid_namaz_app/features/prayer_times/data/prayer_times_provider.dart';
import 'package:masjid_namaz_app/features/qibla/presentation/screens/qibla_screen.dart';
import 'package:masjid_namaz_app/features/quran/presentation/screens/quran_screen.dart';
import 'package:masjid_namaz_app/features/sandha/presentation/screens/sandha_screen.dart';
import 'package:masjid_namaz_app/features/masjid/presentation/screens/connect_masjid_screen.dart';
import 'package:masjid_namaz_app/features/announcements/presentation/screens/announcements_screen.dart';
import 'package:masjid_namaz_app/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:masjid_namaz_app/features/admin/presentation/screens/super_admin_dashboard_screen.dart';
import 'package:masjid_namaz_app/features/auth/presentation/screens/otp_login_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedTabIndex = 0;
  int _noticeRefreshVersion = 0;
  String? _openedAnnouncementId;
  String? _openedNotificationMasjidId;
  List<dynamic> _announcements = [];
  String _calcMethod = 'Hanafi';
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;
  bool _prayerAlarmsEnabled = false;
  bool _prayerAlarmBusy = false;
  String? _prayerAlarmTimesSignature;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _loadPrayerAlarmState();
    _notificationSubscription =
        NotificationService.instance.notificationEvents.listen((event) {
      if (event['opened'] == true && mounted) {
        _handleOpenedNotification(event);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending =
          NotificationService.instance.takePendingNotificationEvent();
      if (pending != null && mounted && pending['opened'] == true) {
        _handleOpenedNotification(pending);
      }
    });
  }

  Future<void> _loadPrayerAlarmState() async {
    final enabled = await NotificationService.instance.prayerAlarmsEnabled();
    if (!mounted) return;
    setState(() => _prayerAlarmsEnabled = enabled);
    if (enabled) {
      final times = ref.read(prayerTimesProvider).times;
      if (times != null) await _syncEnabledPrayerAlarms(times);
    }
  }

  String _timesSignature(Map<String, dynamic>? times) => [
        'fajrAdhan',
        'dhuhrAdhan',
        'asrAdhan',
        'maghribAdhan',
        'ishaAdhan'
      ].map((key) => times?[key]?.toString() ?? '').join('|');

  Future<void> _syncEnabledPrayerAlarms(Map<String, dynamic> times) async {
    final signature = _timesSignature(times);
    if (signature == _prayerAlarmTimesSignature) return;
    try {
      await NotificationService.instance.setPrayerAlarmsEnabled(
        enabled: true,
        prayerTimes: times,
      );
      _prayerAlarmTimesSignature = signature;
    } catch (error) {
      debugPrint('Unable to refresh prayer alarm schedule: $error');
    }
  }

  Future<void> _togglePrayerAlarms() async {
    if (_prayerAlarmBusy) return;
    setState(() => _prayerAlarmBusy = true);
    final enable = !_prayerAlarmsEnabled;
    try {
      await NotificationService.instance.setPrayerAlarmsEnabled(
        enabled: enable,
        prayerTimes: ref.read(prayerTimesProvider).times,
      );
      if (!mounted) return;
      setState(() {
        _prayerAlarmsEnabled = enable;
        _prayerAlarmTimesSignature = enable
            ? _timesSignature(ref.read(prayerTimesProvider).times)
            : null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(enable
            ? 'Daily Adhan alarms are on.'
            : 'Daily Adhan alarms are off.'),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not update prayer alarms: $error'),
      ));
    } finally {
      if (mounted) setState(() => _prayerAlarmBusy = false);
    }
  }

  void _showOpenedAnnouncement(Map<String, dynamic> event) {
    setState(() {
      _selectedTabIndex = 3;
      _noticeRefreshVersion++;
      _openedAnnouncementId = event['id']?.toString();
      _openedNotificationMasjidId = event['masjidId']?.toString();
    });
  }

  Future<void> _handleOpenedNotification(Map<String, dynamic> event) async {
    if (event['type'] != 'MASJID_ADMIN_APPROVED') {
      _showOpenedAnnouncement(event);
      return;
    }

    final profile = await ApiService.instance.getProfile();
    if (!mounted) return;
    final roles = profile?['adminRoles'] as List<dynamic>? ??
        ApiService.instance.currentUser?['adminRoles'] as List<dynamic>? ??
        const [];
    final masjidId = event['masjidId']?.toString();
    Map<String, dynamic>? approvedRole;
    for (final role in roles) {
      if (role is Map<String, dynamic> &&
          (masjidId == null || role['masjidId']?.toString() == masjidId)) {
        approvedRole = role;
        break;
      }
    }

    if (approvedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Approval is being updated. Please reopen Silah in a moment.'),
      ));
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AdminDashboardScreen(
          masjidId: approvedRole?['masjidId']?.toString(),
          masjidName: approvedRole?['masjidName']?.toString(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final profile = await ApiService.instance.getProfile();
    if (mounted) {
      final memberships = profile?['memberships'] as List<dynamic>?;
      final primary = memberships?.firstWhere(
        (m) => m['isPrimary'] == true,
        orElse: () => memberships.isNotEmpty ? memberships.first : null,
      );
      if (primary != null) {
        final activeId = primary['masjidId'];
        final notices = await ApiService.instance.getAnnouncements(activeId);
        if (mounted) {
          setState(() => _announcements = notices);
        }
      } else {
        setState(() => _announcements = []);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(prayerTimesProvider, (previous, next) {
      if (_prayerAlarmsEnabled &&
          _timesSignature(previous?.times) != _timesSignature(next.times) &&
          next.times != null) {
        _syncEnabledPrayerAlarms(next.times!);
      }
    });
    return PopScope(
      canPop: _selectedTabIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedTabIndex != 0) {
          setState(() => _selectedTabIndex = 0);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        drawer: _buildDrawer(),
        body: IndexedStack(
          index: _selectedTabIndex,
          children: [
            _buildHomeTab(),
            const ConnectMasjidScreen(),
            QiblaScreen(onBack: () => setState(() => _selectedTabIndex = 0)),
            AnnouncementsScreen(
              key: ValueKey('notices-$_noticeRefreshVersion'),
              onBack: () => setState(() => _selectedTabIndex = 0),
              masjidId: _openedNotificationMasjidId,
              focusAnnouncementId: _openedAnnouncementId,
            ),
            _buildProfileTab(),
          ],
        ),
        bottomNavigationBar: _buildCustomBottomNav(),
      ),
    );
  }

  // Use the platform navigation component for consistent touch and focus states.
  Widget _buildCustomBottomNav() {
    ref.watch(languageProvider);
    final language = ref.read(languageProvider.notifier);
    return NavigationBar(
      selectedIndex: _selectedTabIndex,
      onDestinationSelected: (index) {
        if (index == 3 && _selectedTabIndex != 3) {
          _noticeRefreshVersion++;
        }
        setState(() => _selectedTabIndex = index);
      },
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: language.text('Home'),
        ),
        NavigationDestination(
          icon: Icon(Icons.mosque_outlined),
          selectedIcon: Icon(Icons.mosque_rounded),
          label: language.text('Masjids'),
        ),
        NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore_rounded),
          label: language.text('Qibla'),
        ),
        NavigationDestination(
          icon: Icon(Icons.campaign_outlined),
          selectedIcon: Icon(Icons.campaign_rounded),
          label: language.text('Notices'),
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person_rounded),
          label: language.text('Profile'),
        ),
      ],
    );
  }

  // MAIN HOME VIEW: Reactive from Provider & Backend Only
  Widget _buildHomeTab() {
    final prayerState = ref.watch(prayerTimesProvider);

    if (prayerState.isLoading && prayerState.times == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        drawer: _buildDrawer(),
        appBar: _buildTopAppBar(),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'Loading prayer times...',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final times = prayerState.times;
    final activeMasjid = prayerState.activeMasjid;
    final nextPrayer = prayerState.nextPrayer;
    final isLocalTimes = prayerState.isLocalTimes;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: _buildDrawer(),
      appBar: _buildTopAppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              await ref.read(prayerTimesProvider.notifier).refreshFromBackend();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Row: Prayer timings & Hanafi selector
                  _buildPrayerTimingsHeader(),
                  const SizedBox(height: 16),

                  // Active Masjid Card
                  _buildActiveMasjidCard(activeMasjid, isLocalTimes),
                  const SizedBox(height: 16),

                  if (activeMasjid == null &&
                      isLocalTimes &&
                      times != null) ...[
                    if (nextPrayer != null)
                      _buildHeroUpNextCard(
                          nextPrayer, {'name': 'Local Prayer Times'}),
                    const SizedBox(height: 20),
                    _buildTodayTimetableCard(times, nextPrayer?.name),
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Local calculated prayer times. Jamaah times are shown only when supplied by a masjid.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSunAndFastingCard(times),
                    const SizedBox(height: 20),
                    _buildNoMasjidConnectedPrompt(),
                  ] else if (activeMasjid == null) ...[
                    _buildNoMasjidConnectedPrompt(),
                    if (prayerState.error != null) ...[
                      const SizedBox(height: 10),
                      Text(prayerState.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 20),
                  ] else ...[
                    // Hero "UP NEXT" Prayer Card
                    if (nextPrayer != null)
                      _buildHeroUpNextCard(nextPrayer, activeMasjid),
                    const SizedBox(height: 20),

                    // Today's Timetable Table (strictly from backend / maintained state)
                    _buildTodayTimetableCard(times, nextPrayer?.name),
                    const SizedBox(height: 20),

                    // Sun & Fasting Card
                    _buildSunAndFastingCard(times),
                    const SizedBox(height: 20),
                  ],

                  // Announcements Card
                  _buildAnnouncementsCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Top App Bar
  PreferredSizeWidget _buildTopAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Builder(
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 0.8),
            ),
            child: IconButton(
              icon: const Icon(Icons.menu, color: Colors.black87, size: 20),
              padding: EdgeInsets.zero,
              onPressed: () {
                if (_scaffoldKey.currentState != null) {
                  _scaffoldKey.currentState!.openDrawer();
                } else {
                  Scaffold.of(ctx).openDrawer();
                }
              },
            ),
          ),
        ),
      ),
      centerTitle: true,
      title: Column(
        children: [
          Text(
            'Silah',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'COMMUNITY ADHAN',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
      actions: [
        // Compass / Qibla Icon
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300, width: 0.8),
            ),
            child: IconButton(
              icon: const Icon(Icons.explore_outlined,
                  color: Colors.black87, size: 19),
              tooltip: 'Open Qibla direction',
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _selectedTabIndex = 2),
            ),
          ),
        ),
      ],
    );
  }

  // 1. Prayer Timings Header & Date Row
  Widget _buildPrayerTimingsHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 2),
        Row(
          children: [
            Flexible(
              child: Text(
                DateFormat('EEEE, d MMM yyyy').format(DateTime.now()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          ],
        ),
      ],
    );
  }

  // 2. Active Masjid Card
  Widget _buildActiveMasjidCard(
      Map<String, dynamic>? activeMasjid, bool isLocalTimes) {
    final masjidName = isLocalTimes
        ? 'Local Prayer Times'
        : (activeMasjid?['name'] ?? 'Select Masjid');
    final masjidAddress = isLocalTimes
        ? 'Calculated for your current location'
        : (activeMasjid?['address'] ?? 'Tap to select a masjid or local times');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wrap(
        //   alignment: WrapAlignment.spaceBetween,
        //   crossAxisAlignment: WrapCrossAlignment.center,
        //   spacing: 8,
        //   runSpacing: 4,
        //   children: [
        //     // Row(
        //     //   mainAxisSize: MainAxisSize.min,
        //     //   children: [
        //     //     const Icon(Icons.mosque, size: 14, color: AppColors.success),
        //     //     const SizedBox(width: 5),
        //     //     Text(
        //     //       isLocalTimes ? 'LOCAL PRAYER TIMES' : 'ACTIVE MASJID',
        //     //       maxLines: 1,
        //     //       overflow: TextOverflow.ellipsis,
        //     //       style: TextStyle(
        //     //         fontSize: 11,
        //     //         fontWeight: FontWeight.bold,
        //     //         letterSpacing: 0.8,
        //     //         color: AppColors.success,
        //     //       ),
        //     //     ),
        //     //   ],
        //     // ),
        //     if (!isLocalTimes &&
        //         activeMasjid != null &&
        //         activeMasjid['city'] != null)
        //       ConstrainedBox(
        //         constraints: const BoxConstraints(maxWidth: 200),
        //         child: Row(
        //           mainAxisSize: MainAxisSize.min,
        //           children: [
        //             const Icon(Icons.location_city,
        //                 size: 12, color: Colors.grey),
        //             const SizedBox(width: 3),
        //             Flexible(
        //               child: Text(
        //                 activeMasjid['city'] ?? '',
        //                 maxLines: 1,
        //                 overflow: TextOverflow.ellipsis,
        //                 style: const TextStyle(
        //                     fontSize: 11,
        //                     color: Colors.grey,
        //                     fontWeight: FontWeight.w500),
        //               ),
        //             ),
        //           ],
        //         ),
        //       ),
        //   ],
        // ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _showMasjidSelector,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.location_on,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              masjidName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (activeMasjid != null && !isLocalTimes) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    activeMasjid['approvalStatus'] == 'APPROVED'
                                        ? AppColors.primaryContainer
                                        : const Color(0xFFFFF3CD),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                activeMasjid['approvalStatus'] == 'APPROVED'
                                    ? 'VERIFIED'
                                    : 'PENDING',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: activeMasjid['approvalStatus'] ==
                                          'APPROVED'
                                      ? AppColors.success
                                      : const Color(0xFF856404),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        masjidAddress,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (activeMasjid != null && !isLocalTimes)
                  IconButton(
                    icon: const Icon(Icons.directions,
                        color: AppColors.primary, size: 22),
                    tooltip: 'Open in Google Maps',
                    onPressed: () => _openMasjidLocation(activeMasjid),
                  ),
                const Icon(Icons.unfold_more, color: Colors.grey, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoMasjidConnectedPrompt() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.mosque, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            const Text(
              'No Masjid Connected',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'You are not linked to any masjid yet. Connect to a masjid via Search or QR Code scan to view verified Namaz & Jamaah times and community notices.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Search Masjid',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    onPressed: () => setState(() => _selectedTabIndex = 1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text('Scan QR Code',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      setState(() => _selectedTabIndex = 1);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 3. Hero "UP NEXT" Prayer Card - EXACT MATCH TO DESIGN
  Widget _buildHeroUpNextCard(
      NextPrayerInfo next, Map<String, dynamic>? activeMasjid) {
    final isLocalTimes = activeMasjid?['id'] == null;
    final hours = next.timeUntilAdhan.inHours.toString().padLeft(2, '0');
    final minutes =
        (next.timeUntilAdhan.inMinutes % 60).toString().padLeft(2, '0');
    final seconds =
        (next.timeUntilAdhan.inSeconds % 60).toString().padLeft(2, '0');

    final iqamahHours = next.timeUntilIqamah.inHours;
    final iqamahMins = next.timeUntilIqamah.inMinutes % 60;
    final iqamahTimeStr =
        iqamahHours > 0 ? '${iqamahHours}h ${iqamahMins}m' : '${iqamahMins}m';
    final prayerTimeStr = next.timeUntilAdhan.inHours > 0
        ? '${next.timeUntilAdhan.inHours}h ${next.timeUntilAdhan.inMinutes % 60}m'
        : '${next.timeUntilAdhan.inMinutes}m';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background Mosque Architecture Silhouette
          Positioned.fill(
            child: CustomPaint(
              painter: MosqueSilhouettePainter(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: [ ● UP NEXT ] and [ ⌛ Iqamah in 1h 44m ]
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //   children: [
                //     Container(
                //       padding: const EdgeInsets.symmetric(
                //           horizontal: 14, vertical: 7),
                //       decoration: BoxDecoration(
                //         color: AppColors.primaryDark,
                //         borderRadius: BorderRadius.circular(20),
                //         border:
                //             Border.all(color: AppColors.primaryMid, width: 1.2),
                //       ),
                //       child: Row(
                //         mainAxisSize: MainAxisSize.min,
                //         children: [
                //           Container(
                //             width: 8,
                //             height: 8,
                //             decoration: const BoxDecoration(
                //               color: Color(0xFF48D38A),
                //               shape: BoxShape.circle,
                //             ),
                //           ),
                //           const SizedBox(width: 8),
                //           const Text(
                //             'UP NEXT',
                //             style: TextStyle(
                //               color: Colors.white,
                //               fontSize: 11,
                //               fontWeight: FontWeight.w800,
                //               letterSpacing: 1.2,
                //             ),
                //           ),
                //         ],
                //       ),
                //     ),
                //     Container(
                //       padding: const EdgeInsets.symmetric(
                //           horizontal: 14, vertical: 7),
                //       decoration: BoxDecoration(
                //         color: AppColors.primaryDark,
                //         borderRadius: BorderRadius.circular(20),
                //         border: Border.all(
                //             color: const Color(0xFF1D5A3A), width: 1),
                //       ),
                //       child: Row(
                //         mainAxisSize: MainAxisSize.min,
                //         children: [
                //           const Text('⌛', style: TextStyle(fontSize: 12)),
                //           const SizedBox(width: 6),
                //           Text(
                //             isLocalTimes
                //                 ? 'Prayer in $prayerTimeStr'
                //                 : 'Iqamah in $iqamahTimeStr',
                //             style: const TextStyle(
                //               color: AppColors.primaryContainer,
                //               fontSize: 12,
                //               fontWeight: FontWeight.bold,
                //             ),
                //           ),
                //         ],
                //       ),
                //     ),
                //   ],
                // ),
                const SizedBox(height: 18),

                // Main Prayer Name & Congregation Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      next.name,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.05,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF1D5A3A), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('⌛', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 6),
                          Text(
                            isLocalTimes
                                ? 'Prayer in $prayerTimeStr'
                                : 'Iqamah in $iqamahTimeStr',
                            style: const TextStyle(
                              color: AppColors.primaryContainer,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Timings Row: ADHAN 12:30 PM  •  IQAMAH 12:45 PM
                Row(
                  children: [
                    const Text(
                      'ADHAN ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF82B89A),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      formatPrayerTime(next.adhan),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!isLocalTimes) ...[
                      const SizedBox(width: 12),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3B8259),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'IQAMAH ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF82B89A),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        formatPrayerTime(next.iqamah),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF4ADE80),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Horizontal Divider
                Divider(
                  color: Colors.white.withValues(alpha: 0.12),
                  height: 1,
                  thickness: 1,
                ),
                const SizedBox(height: 16),

                // Bottom Row: [TIME REMAINING TO ADHAN / CLOCK] and [Map / Alert]
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TIME REMAINING TO ADHAN',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF82B89A),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '$hours:$minutes:$seconds',
                              style: GoogleFonts.spaceMono(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Padding(
                            padding: EdgeInsets.only(left: 2),
                            child: Text(
                              'HRS      MIN      SEC',
                              style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFF82B89A),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Map & Alert Buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Map Button
                        InkWell(
                          onTap: () => _openMasjidMap(activeMasjid),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppColors.primaryMid, width: 1.2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.turn_right,
                                    color: Colors.white, size: 15),
                                SizedBox(width: 4),
                                Text(
                                  'Map',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Alert Button
                        InkWell(
                          onTap: _prayerAlarmBusy ? null : _togglePrayerAlarms,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppColors.primaryMid, width: 1.2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                    _prayerAlarmsEnabled
                                        ? Icons.notifications_active
                                        : Icons.notifications_active_outlined,
                                    color: const Color(0xFF6EE7B7),
                                    size: 15),
                                const SizedBox(width: 4),
                                Text(
                                  _prayerAlarmsEnabled ? 'Adhan On' : 'Alert',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMasjidMap(Map<String, dynamic>? masjid) async {
    final lat = masjid?['latitude'];
    final lng = masjid?['longitude'];
    final name = masjid?['name'] ?? 'Masjid';
    final city = masjid?['city'] ?? '';

    final mapUrl = masjid?['mapUrl'];

    Uri url;
    if (mapUrl != null && mapUrl.toString().trim().isNotEmpty) {
      url = Uri.parse(mapUrl.toString().trim());
    } else if (lat != null && lng != null) {
      url = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    } else {
      url = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('$name $city')}');
    }

    try {
      final launched =
          await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open map: $e')),
        );
      }
    }
  }

  // 4. Today's Timetable Card - STRICTLY FROM BACKEND MAP
  Widget _buildTodayTimetableCard(
      Map<String, dynamic>? times, String? nextPrayerName) {
    if (times == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: const Center(
            child: Text('Loading timetable from Masjid database...')),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's timetable",
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  // const SizedBox(height: 2),
                  // Text(
                  //   'Auto-synced with masjid clock · $_calcMethod',
                  //   style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  // ),
                ],
              ),
              // Container(
              //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              //   decoration: BoxDecoration(
              //     color: AppColors.primaryContainer,
              //     borderRadius: BorderRadius.circular(12),
              //   ),
              //   child: Row(
              //     mainAxisSize: MainAxisSize.min,
              //     children: const [
              //       Icon(Icons.circle, color: AppColors.success, size: 6),
              //       SizedBox(width: 4),
              //       Text(
              //         'Official',
              //         style: TextStyle(
              //           fontSize: 10,
              //           fontWeight: FontWeight.bold,
              //           color: AppColors.success,
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
            ],
          ),
          const SizedBox(height: 16),

          // Table Header
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  'PRAYER',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.8),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'ADHAN / AZAAN',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.8),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'IQAMAH',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 6),

          // Dynamic Prayer Rows from Backend
          _buildPrayerTableRow(
            icon: Icons.wb_twilight_outlined,
            name: 'Fajr',
            adhan: times['fajrAdhan'] ?? '--',
            iqamah: times['fajrJamaah'] ?? '--',
            isNext: nextPrayerName == 'Fajr',
          ),
          _buildPrayerTableRow(
            icon: Icons.wb_sunny_outlined,
            name: DateTime.now().weekday == DateTime.friday
                ? 'Jumu\'ah'
                : 'Dhuhr',
            adhan: times['dhuhrAdhan'] ?? '--',
            iqamah: times['dhuhrJamaah'] ?? '--',
            isNext: nextPrayerName == 'Dhuhr' || nextPrayerName == 'Jumu\'ah',
          ),
          _buildPrayerTableRow(
            icon: Icons.wb_sunny,
            name: 'Asr',
            adhan: times['asrAdhan'] ?? '--',
            iqamah: times['asrJamaah'] ?? '--',
            isNext: nextPrayerName == 'Asr',
          ),
          _buildPrayerTableRow(
            icon: Icons.wb_twilight,
            name: 'Maghrib',
            adhan: times['maghribAdhan'] ?? '--',
            iqamah: times['maghribJamaah'] ?? '--',
            isNext: nextPrayerName == 'Maghrib',
          ),
          _buildPrayerTableRow(
            icon: Icons.nightlight_round_outlined,
            name: 'Isha',
            adhan: times['ishaAdhan'] ?? '--',
            iqamah: times['ishaJamaah'] ?? '--',
            isNext: nextPrayerName == 'Isha',
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                  children: [
                    const TextSpan(
                        text: 'Jumu\'ah 1st Khutbah: ',
                        style: TextStyle(color: Colors.grey)),
                    TextSpan(
                      text: times['jummahKhutbah'] ?? '12:45 PM',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Opening Full Month Calendar from Database...')),
                  );
                },
                child: Row(
                  children: const [
                    Text('Full Month',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                    Icon(Icons.chevron_right,
                        size: 14, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerTableRow({
    required IconData icon,
    required String name,
    required String adhan,
    required String iqamah,
    required bool isNext,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isNext ? AppColors.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Icon(icon,
                    size: 16,
                    color: isNext ? AppColors.primary : Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isNext ? FontWeight.bold : FontWeight.w600,
                    color: isNext ? AppColors.primary : Colors.black87,
                  ),
                ),
                if (isNext) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'NEXT',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              formatPrayerTime(adhan),
              style: TextStyle(
                fontSize: 13,
                color: isNext ? Colors.black87 : Colors.grey.shade700,
                fontWeight: isNext ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              formatPrayerTime(iqamah),
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isNext ? AppColors.primary : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 5. Sun & Fasting Card
  Widget _buildSunAndFastingCard(Map<String, dynamic>? times) {
    final sunrise = times?['sunrise'] ?? times?['fajrJamaah'] ?? '--:--';
    final ishraq = times?['ishraq'] ?? '--:--';
    final sunset = times?['sunset'] ?? times?['maghribAdhan'] ?? '--:--';
    final sehri = times?['sehri'] ?? times?['fajrAdhan'] ?? '--:--';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sun & Fasting',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Sunrise\n(Shurooq)',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  height: 1.2)),
                          Icon(Icons.wb_sunny_outlined,
                              color: Colors.amber, size: 18),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formatPrayerTime(sunrise.toString()),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ishraq ${formatPrayerTime(ishraq.toString())}',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Sunset & Iftar\n ',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  height: 1.2)),
                          Icon(Icons.wb_twilight,
                              color: Colors.orange, size: 18),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formatPrayerTime(sunset.toString()),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Fast ${formatPrayerTime(sehri.toString())}',
                        style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 6. Announcements Card
  Widget _buildAnnouncementsCard() {
    final hasNotices = _announcements.isNotEmpty;
    final latestNotice = hasNotices ? _announcements.first : null;
    final noticeTitle =
        hasNotices ? (latestNotice?['title'] ?? 'Notice') : 'No Announcements';
    final noticeBody = hasNotices
        ? (latestNotice?['body'] ?? '')
        : 'Your masjid has not published any announcements at this time.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Announcements',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  if (hasNotices) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_announcements.length} New',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success),
                      ),
                    ),
                  ],
                ],
              ),
              InkWell(
                onTap: () => setState(() => _selectedTabIndex = 3),
                child: Row(
                  children: const [
                    Text('View all',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w600)),
                    Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Inner Announcement Tile
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9C4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.campaign,
                      color: Color(0xFFF57F17), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'JUMU\'AH NOTICE',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success),
                            ),
                          ),
                          const Text('Today',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        noticeTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        noticeBody,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            height: 1.3),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Masjid Admin',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade500)),
                          Row(
                            children: const [
                              Text('Read parking instructions',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary)),
                              Icon(Icons.chevron_right,
                                  size: 12, color: AppColors.primary),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Profile Tab (Tab 4)
  Widget _buildProfileTab() {
    final user = ApiService.instance.currentUser;
    final userName = user?['name'] ?? 'User';
    final userPhone = user?['phone'] ?? '';
    final isMasjidAdmin = ApiService.instance.isMasjidAdmin;
    final isSuperAdmin = ApiService.instance.isSuperAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const AppLanguageText('My Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primaryContainer,
              child: Icon(Icons.person, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(userName,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(userPhone, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),

            // ROLE SWITCHER BUTTON
            if (isMasjidAdmin || isSuperAdmin) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.admin_panel_settings,
                            color: Colors.amber, size: 24),
                        SizedBox(width: 10),
                        Text(
                          'Administrative Mode',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You are an authorized administrator. Switch modes to update prayer schedules, publish notices, or manage roles.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () {
                        final currentMasjid =
                            ref.read(prayerTimesProvider).activeMasjid;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => isSuperAdmin
                                ? const SuperAdminDashboardScreen()
                                : AdminDashboardScreen(
                                    masjidId: currentMasjid?['id'],
                                    masjidName: currentMasjid?['name'],
                                  ),
                          ),
                        ).then((_) => setState(() {}));
                      },
                      icon: const Icon(Icons.swap_horiz, color: Colors.black87),
                      label: Text(isSuperAdmin
                          ? 'Open Super Admin Portal'
                          : 'Switch to Masjid Admin Portal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            ListTile(
              leading: const Icon(Icons.mosque),
              title: const Text('Change Active Masjid'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showMasjidSelector,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Asr Calculation Method'),
              subtitle: Text(_calcMethod),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showCalculationMethodDialog,
            ),
            const Divider(),
            const AppLanguageSettingsTile(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign Out / Switch Account',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                await ApiService.instance.clearSession();
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const OtpLoginScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Drawer (Menu from top-left button)
  Widget _buildDrawer() {
    final isMasjidAdmin = ApiService.instance.isMasjidAdmin;
    final isSuperAdmin = ApiService.instance.isSuperAdmin;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Silah',
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text('Community Adhan & Masjid Sync',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          if (isMasjidAdmin || isSuperAdmin) ...[
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: Colors.amber),
              title: Text(
                isSuperAdmin
                    ? 'Switch to Super Admin Portal'
                    : 'Switch to Masjid Admin Portal',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                final currentMasjid =
                    ref.read(prayerTimesProvider).activeMasjid;
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => isSuperAdmin
                        ? const SuperAdminDashboardScreen()
                        : AdminDashboardScreen(
                            masjidId: currentMasjid?['id'],
                            masjidName: currentMasjid?['name'],
                          ),
                  ),
                ).then((_) => setState(() {}));
              },
            ),
            const Divider(),
          ],
          ListTile(
            leading: const Icon(Icons.mosque),
            title: const Text('Select Masjid'),
            onTap: () {
              Navigator.pop(context);
              _showMasjidSelector();
            },
          ),
          ListTile(
            leading: const Icon(Icons.explore),
            title: const Text('Qibla Compass'),
            onTap: () {
              Navigator.pop(context);
              setState(() => _selectedTabIndex = 2);
            },
          ),
          ListTile(
            leading: const Icon(Icons.campaign),
            title: const Text('Announcements'),
            onTap: () {
              Navigator.pop(context);
              setState(() => _selectedTabIndex = 3);
            },
          ),
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: const Text('Holy Quran'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const QuranScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.volunteer_activism),
            title: const Text('Sandha contributions'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SandhaScreen()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: const Text('Login / Account'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OtpLoginScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showCalculationMethodDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Asr Calculation Method'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              _setCalculationMethod('Hanafi', ctx);
            },
            child: Row(
              children: [
                Icon(
                    _calcMethod == 'Hanafi'
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: AppColors.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Hanafi (Shadow length 2x)',
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              _setCalculationMethod('Standard / Shafi', ctx);
            },
            child: Row(
              children: [
                Icon(
                    _calcMethod != 'Hanafi'
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: AppColors.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Standard / Shafi / Maliki (Shadow 1x)',
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _setCalculationMethod(String method, BuildContext dialogContext) {
    setState(() => _calcMethod = method);
    Navigator.pop(dialogContext);
    if (ref.read(prayerTimesProvider).isLocalTimes) {
      unawaited(ref
          .read(prayerTimesProvider.notifier)
          .selectLocalTimes(school: method == 'Hanafi' ? 1 : 0));
    }
  }

  Future<void> _openMasjidLocation(Map<String, dynamic> masjid) async {
    final mapUrl = masjid['mapUrl']?.toString();
    if (mapUrl != null &&
        mapUrl.trim().isNotEmpty &&
        mapUrl.startsWith('http')) {
      final uri = Uri.parse(mapUrl.trim());
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    final lat = masjid['latitude'];
    final lng = masjid['longitude'];
    String query;
    if (lat != null && lng != null) {
      query = '$lat,$lng';
    } else {
      query = Uri.encodeComponent(
          '${masjid['name'] ?? ''}, ${masjid['city'] ?? ''}');
    }
    final mapsUri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(mapsUri)) {
      await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
    }
  }

  void _showMasjidSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final activeMasjid = ref.read(prayerTimesProvider).activeMasjid;

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top handle
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: Text(
                          'My Masjids',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        tooltip: 'Close',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 44,
                          height: 44,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Joined Masjids List: Only masjids mapped/joined to this user
                Expanded(
                  child: FutureBuilder<List<dynamic>>(
                    future: ApiService.instance.getMyMasjids(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary));
                      }
                      final myMasjids = snapshot.data ?? [];
                      final localSelected =
                          ref.read(prayerTimesProvider).isLocalTimes;
                      final localIndex =
                          myMasjids.isEmpty ? 0 : myMasjids.length;
                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        itemCount:
                            myMasjids.length + (myMasjids.isEmpty ? 2 : 1),
                        separatorBuilder: (_, __) => const Divider(height: 8),
                        itemBuilder: (context, i) {
                          if (i == localIndex) {
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: localSelected
                                      ? AppColors.primary
                                      : AppColors.primary
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.my_location,
                                    color: localSelected
                                        ? Colors.white
                                        : AppColors.primary),
                              ),
                              title: const Text('Local Prayer Times',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: const Text('Use your current location',
                                  style: TextStyle(fontSize: 11)),
                              trailing: localSelected
                                  ? const Icon(Icons.check_circle,
                                      color: AppColors.primary)
                                  : null,
                              onTap: () async {
                                Navigator.pop(ctx);
                                await ref
                                    .read(prayerTimesProvider.notifier)
                                    .selectLocalTimes(
                                        school:
                                            _calcMethod == 'Hanafi' ? 1 : 0);
                              },
                            );
                          }
                          if (myMasjids.isEmpty && i == 1) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                  'No joined masjids yet. Local prayer times are available above; search or scan to connect to a masjid.',
                                  textAlign: TextAlign.center),
                            );
                          }
                          final m = myMasjids[i];
                          if (m is! Map<String, dynamic>)
                            return const SizedBox.shrink();
                          final isSelected = m['id'] == activeMasjid?['id'];

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.mosque,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.primary,
                                size: 22,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${m['name']} (${m['city'] ?? ''})',
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      fontSize: 14,
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: AppColors.primary, width: 0.8),
                                    ),
                                    child: const Text('ACTIVE',
                                        style: TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              m['address'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Location Redirect Button
                                IconButton(
                                  icon: const Icon(Icons.directions,
                                      size: 20, color: AppColors.primary),
                                  tooltip: 'Open in Google Maps',
                                  onPressed: () => _openMasjidLocation(m),
                                ),
                                // Exit / Leave Masjid Option
                                IconButton(
                                  icon: const Icon(Icons.logout,
                                      size: 20, color: Colors.redAccent),
                                  tooltip: 'Exit / Leave Masjid',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16)),
                                        title: const Text('Exit Masjid?'),
                                        content: Text(
                                            'Are you sure you want to remove "${m['name']}" from your joined masjids list?'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(c, false),
                                              child: const Text('Cancel')),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                foregroundColor: Colors.white),
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            child: const Text('Exit'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      await ApiService.instance
                                          .leaveMasjid(m['id']);
                                      setSheetState(() {});
                                      if (isSelected) {
                                        // Switch to another joined masjid if available
                                        final remaining = await ApiService
                                            .instance
                                            .getMyMasjids();
                                        if (remaining.isNotEmpty) {
                                          await ref
                                              .read(
                                                  prayerTimesProvider.notifier)
                                              .switchMasjid(remaining.first
                                                  as Map<String, dynamic>);
                                        }
                                      }
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content:
                                                  Text('Left "${m['name']}"')),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                            onTap: () async {
                              Navigator.pop(ctx);
                              await ref
                                  .read(prayerTimesProvider.notifier)
                                  .switchMasjid(m);
                              final notices = await ApiService.instance
                                  .getAnnouncements(m['id']);
                              if (mounted) {
                                setState(() => _announcements = notices);
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),

                // Bottom: Search & Add Another Masjid Button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, -2)),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text(
                        ' Search & Add',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ConnectMasjidScreen()),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class MosqueSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF165C3A).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Dome (center-right)
    final path = Path();
    final cx1 = w * 0.62;
    final r1 = w * 0.20;
    path.moveTo(cx1 - r1, h);
    path.quadraticBezierTo(cx1 - r1, h * 0.40, cx1, h * 0.28);
    path.quadraticBezierTo(cx1 + r1, h * 0.40, cx1 + r1, h);
    path.close();

    // Minaret 1 (right side)
    final mx1 = w * 0.86;
    path.moveTo(mx1 - 10, h);
    path.lineTo(mx1 - 8, h * 0.48);
    path.lineTo(mx1, h * 0.40);
    path.lineTo(mx1 + 8, h * 0.48);
    path.lineTo(mx1 + 10, h);
    path.close();

    // Minaret 2 (center-left)
    final mx2 = w * 0.44;
    path.moveTo(mx2 - 8, h);
    path.lineTo(mx2 - 6, h * 0.52);
    path.lineTo(mx2, h * 0.45);
    path.lineTo(mx2 + 6, h * 0.52);
    path.lineTo(mx2 + 8, h);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
