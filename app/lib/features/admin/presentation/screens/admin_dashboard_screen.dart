import 'package:masjid_namaz_app/core/constants/app_colors.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:masjid_namaz_app/core/network/api_service.dart';
import 'package:masjid_namaz_app/core/services/notification_service.dart';
import 'package:masjid_namaz_app/features/announcements/presentation/screens/announcements_screen.dart';
import 'package:masjid_namaz_app/features/prayer_times/presentation/screens/home_screen.dart';
import 'package:masjid_namaz_app/features/auth/presentation/screens/otp_login_screen.dart';
import 'package:masjid_namaz_app/features/masjid/presentation/widgets/location_input_widget.dart';
import 'package:masjid_namaz_app/features/admin/presentation/screens/notice_editor_screen.dart';
import 'package:masjid_namaz_app/features/admin/presentation/screens/masjid_qr_screen.dart';
import 'package:masjid_namaz_app/features/sandha/presentation/screens/sandha_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String? masjidId;
  final String? masjidName;
  const AdminDashboardScreen({super.key, this.masjidId, this.masjidName});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;

  String? _masjidId;
  String? _masjidName;
  Map<String, dynamic>? _masjidDetails;
  Map<String, dynamic>? _adminOverview;
  Map<String, dynamic>? _todayPrayerTimes;
  List<dynamic> _specialSchedules = [];
  List<dynamic> _announcements = [];
  Map<String, dynamic>? _membersData;
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _masjidId = widget.masjidId;
    _masjidName = widget.masjidName;
    _notificationSubscription =
        NotificationService.instance.notificationEvents.listen((event) {
      if (event['opened'] == true && event['type'] == 'BROADCAST' && mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AnnouncementsScreen(
            masjidId: _masjidId,
            focusAnnouncementId: event['id']?.toString(),
          ),
        ));
        return;
      }
      final isMasjidNotice = event['type'] == 'MASJID_NOTICE';
      final noticeMasjidId = event['masjidId']?.toString();
      if (event['opened'] == true &&
          isMasjidNotice &&
          (_masjidId == null || noticeMasjidId == _masjidId) &&
          mounted) {
        setState(() => _currentIndex = 2);
        _loadMasjidData();
      }
    });

    final cachedUser = ApiService.instance.currentUser;
    final cachedRoles = cachedUser?['adminRoles'] as List<dynamic>?;
    if (_masjidId == null && cachedRoles != null && cachedRoles.isNotEmpty) {
      final firstRole = cachedRoles.first;
      if (firstRole is Map<String, dynamic>) {
        _masjidId = firstRole['masjidId'];
        _masjidName = firstRole['masjidName'] ?? 'Masjid Admin';
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMasjidData();
      final pending =
          NotificationService.instance.takePendingNotificationEvent();
      if (pending != null && pending['opened'] == true && mounted) {
        if (pending['type'] == 'BROADCAST') {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AnnouncementsScreen(
              masjidId: _masjidId,
              focusAnnouncementId: pending['id']?.toString(),
            ),
          ));
        } else if (pending['type'] == 'MASJID_NOTICE') {
          setState(() => _currentIndex = 2);
          _loadMasjidData();
        }
      }
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadMasjidData() async {
    try {
      final user = await ApiService.instance.getProfile() ??
          ApiService.instance.currentUser;
      String? mId = _masjidId ?? widget.masjidId;
      String? mName = _masjidName ?? widget.masjidName;

      // 1. Check adminRoles
      if (mId == null) {
        final adminRoles = (user?['adminRoles'] as List<dynamic>?) ??
            (ApiService.instance.currentUser?['adminRoles'] as List<dynamic>?);
        if (adminRoles != null && adminRoles.isNotEmpty) {
          final primary = adminRoles.first;
          if (primary is Map<String, dynamic>) {
            mId = primary['masjidId']?.toString();
            mName = primary['masjidName']?.toString();
          }
        }
      }

      // 2. Check masjidAdmins in profile
      if (mId == null) {
        final masjidAdmins = user?['masjidAdmins'] as List<dynamic>?;
        if (masjidAdmins != null && masjidAdmins.isNotEmpty) {
          final first = masjidAdmins.first;
          if (first is Map<String, dynamic>) {
            mId = first['masjidId']?.toString();
            mName = first['masjid']?['name']?.toString();
          }
        }
      }

      if (mId != null) {
        _masjidId = mId;
        _masjidName = mName ?? _masjidName ?? 'Masjid Admin';

        final overview = await ApiService.instance.getMasjidAdminOverview(mId);
        final masjidInfo = await ApiService.instance.getMasjidById(mId);
        final todayTimes = await ApiService.instance.getTodayPrayerTimes(mId);
        final schedules = await ApiService.instance.getSpecialSchedules(mId);
        final notices = await ApiService.instance.getAnnouncements(mId);
        final members = await ApiService.instance.getMasjidMembers(mId);

        if (mounted) {
          setState(() {
            _adminOverview = overview;
            _masjidDetails = masjidInfo ?? overview?['masjid'];
            _todayPrayerTimes = todayTimes;
            _specialSchedules = schedules;
            _announcements = notices;
            _membersData = members;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _masjidId = null;
            _masjidName = null;
            _adminOverview = null;
            _masjidDetails = null;
            _todayPrayerTimes = null;
            _specialSchedules = [];
            _announcements = [];
            _membersData = null;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // -------------------------------------------------------------
  // TAB 1: Dashboard Overview
  // -------------------------------------------------------------
  Widget _buildDashboardTab() {
    final metrics = _adminOverview?['metrics'] ?? {};
    final memberCount = metrics['memberCount'] ?? 0;
    final noticesCount =
        metrics['activeAnnouncementsCount'] ?? _announcements.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_masjidName ?? 'Masjid Admin Dashboard',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _loadMasjidData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _masjidId == null
              ? _buildNoMasjidAdminCard()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Header Banner
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      color: AppColors.primary,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_masjidName ?? 'Masjid',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              '${_masjidDetails?['city'] ?? ''} • Admin Portal',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _statBadge('Members Connected', '$memberCount',
                                    Icons.people),
                                const SizedBox(width: 12),
                                _statBadge('Active Notices', '$noticesCount',
                                    Icons.campaign),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_todayPrayerTimes == null) ...[
                      Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.schedule,
                                  color: AppColors.primary, size: 30),
                              const SizedBox(height: 10),
                              const Text('Create Your Prayer Schedule',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              const Text(
                                  'Add this masjid’s prayer and jamaah times to make them available to connected members.'),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary),
                                  onPressed: _openCreatePrayerSchedule,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create Schedule'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Today Prayer Times Card
                    const Text("Today's Prayer Schedule",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _todayPrayerTimes == null
                            ? const Text(
                                'No prayer times configured for today.',
                                style: TextStyle(color: Colors.grey))
                            : Column(
                                children: [
                                  _prayerRow(
                                      'Fajr',
                                      _todayPrayerTimes?['fajrAdhan'],
                                      _todayPrayerTimes?['fajrJamaah']),
                                  const Divider(),
                                  _prayerRow(
                                      'Dhuhr',
                                      _todayPrayerTimes?['dhuhrAdhan'],
                                      _todayPrayerTimes?['dhuhrJamaah']),
                                  const Divider(),
                                  _prayerRow(
                                      'Asr',
                                      _todayPrayerTimes?['asrAdhan'],
                                      _todayPrayerTimes?['asrJamaah']),
                                  const Divider(),
                                  _prayerRow(
                                      'Maghrib',
                                      _todayPrayerTimes?['maghribAdhan'],
                                      _todayPrayerTimes?['maghribJamaah']),
                                  const Divider(),
                                  _prayerRow(
                                      'Isha',
                                      _todayPrayerTimes?['ishaAdhan'],
                                      _todayPrayerTimes?['ishaJamaah']),
                                  if (_todayPrayerTimes?['jummahJamaah'] !=
                                      null) ...[
                                    const Divider(),
                                    _prayerRow(
                                        'Jummah',
                                        _todayPrayerTimes?['jummahKhutbah'],
                                        _todayPrayerTimes?['jummahJamaah']),
                                  ],
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }

  void _openCreatePrayerSchedule() {
    setState(() => _currentIndex = 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _masjidId != null) _showFullPrayerTimesDialog();
    });
  }

  Widget _buildNoMasjidAdminCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_business,
                      size: 48, color: AppColors.primary),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Masjid Configured',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You are signed in as an administrator, but have not registered or been linked to a masjid yet. Tap below to register your masjid now.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                      onPressed: _loadMasjidData,
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Register Masjid',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _showCreateMasjidDialog,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateMasjidDialog() {
    final nameCtrl = TextEditingController();
    final nameTaCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    final mapUrlCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Register New Masjid'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Masjid Name *')),
              const SizedBox(height: 12),
              TextField(
                  controller: nameTaCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Tamil Name (Optional)')),
              const SizedBox(height: 12),
              TextField(
                  controller: cityCtrl,
                  decoration: const InputDecoration(labelText: 'City *')),
              const SizedBox(height: 12),
              TextField(
                  controller: addrCtrl,
                  decoration: const InputDecoration(labelText: 'Address *')),
              const SizedBox(height: 12),
              LocationInputWidget(
                latController: latCtrl,
                lngController: lngCtrl,
                mapUrlController: mapUrlCtrl,
                masjidNameController: nameCtrl,
                cityController: cityCtrl,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.isEmpty ||
                  cityCtrl.text.isEmpty ||
                  addrCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Please fill required fields')));
                return;
              }
              Navigator.pop(ctx);
              try {
                final response = await ApiService.instance.createMasjid(
                  name: nameCtrl.text.trim(),
                  city: cityCtrl.text.trim(),
                  address: addrCtrl.text.trim(),
                  nameTa: nameTaCtrl.text.trim().isEmpty
                      ? null
                      : nameTaCtrl.text.trim(),
                  latitude: double.tryParse(latCtrl.text),
                  longitude: double.tryParse(lngCtrl.text),
                  mapUrl: mapUrlCtrl.text.trim().isEmpty
                      ? null
                      : mapUrlCtrl.text.trim(),
                );
                final data =
                    response['data'] as Map<String, dynamic>? ?? response;
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(data['message']?.toString() ??
                        'Masjid request submitted for review.'),
                  ));
                }
                await _loadMasjidData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ApiService.getErrorMessage(e))));
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget _statBadge(String title, String val, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(val,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text(title,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _prayerRow(String name, String? adhan, String? jamaah) {
    return _prayerRowEditable(name.toLowerCase(), name, adhan, jamaah);
  }

  Widget _solarTimeSummary(
    IconData icon,
    String label,
    dynamic value,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(
              value?.toString() ?? '--:--',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _prayerRowEditable(
      String prayerKey, String name, String? adhan, String? jamaah) {
    IconData icon;
    switch (prayerKey.toLowerCase()) {
      case 'fajr':
        icon = Icons.wb_twilight;
        break;
      case 'dhuhr':
        icon = Icons.wb_sunny;
        break;
      case 'asr':
        icon = Icons.filter_drama;
        break;
      case 'maghrib':
        icon = Icons.nights_stay;
        break;
      case 'isha':
        icon = Icons.bedtime;
        break;
      case 'jummah':
        icon = Icons.mosque;
        break;
      default:
        icon = Icons.access_time;
    }

    Widget timingActions() => Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (adhan != null && adhan.isNotEmpty)
              Text('Adhan: $adhan',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            InkWell(
              onTap: () => _editSinglePrayerTime(
                  prayerKey.toLowerCase(), name, adhan, jamaah),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Jamaah: ${jamaah ?? '--:--'}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.edit, size: 14, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ],
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final prayerLabel = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          );
          if (constraints.maxWidth < 410) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                prayerLabel,
                const SizedBox(height: 8),
                timingActions(),
              ],
            );
          }
          return Row(
            children: [
              prayerLabel,
              const Spacer(),
              Flexible(
                  child: Align(
                      alignment: Alignment.centerRight,
                      child: timingActions())),
            ],
          );
        },
      ),
    );
  }

  void _editSinglePrayerTime(String prayerKey, String prayerName,
      String? currentAdhan, String? currentJamaah) {
    final dateStr = DateTime.now().toIso8601String().split('T')[0];
    final adhanCtrl = TextEditingController(text: currentAdhan ?? '');
    final jamaahCtrl = TextEditingController(text: currentJamaah ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit_calendar, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Edit $prayerName Time',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date: $dateStr (Today)',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: adhanCtrl,
              decoration: InputDecoration(
                labelText: '$prayerName Adhan Time (HH:mm)',
                prefixIcon: const Icon(Icons.access_time, size: 20),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.schedule),
                  onPressed: () async {
                    final parts = adhanCtrl.text.split(':');
                    final initialTime = TimeOfDay(
                      hour: int.tryParse(parts.first) ?? 12,
                      minute:
                          parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
                    );
                    final picked = await showTimePicker(
                        context: ctx, initialTime: initialTime);
                    if (picked != null) {
                      final h = picked.hour.toString().padLeft(2, '0');
                      final m = picked.minute.toString().padLeft(2, '0');
                      adhanCtrl.text = '$h:$m';
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: jamaahCtrl,
              decoration: InputDecoration(
                labelText: '$prayerName Jamaah Time (HH:mm) *',
                prefixIcon: const Icon(Icons.people, size: 20),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.schedule),
                  onPressed: () async {
                    final parts = jamaahCtrl.text.split(':');
                    final initialTime = TimeOfDay(
                      hour: int.tryParse(parts.first) ?? 12,
                      minute:
                          parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
                    );
                    final picked = await showTimePicker(
                        context: ctx, initialTime: initialTime);
                    if (picked != null) {
                      final h = picked.hour.toString().padLeft(2, '0');
                      final m = picked.minute.toString().padLeft(2, '0');
                      jamaahCtrl.text = '$h:$m';
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (_masjidId == null) return;
              Navigator.pop(ctx);
              try {
                final adhanVal = adhanCtrl.text.trim();
                final jamaahVal = jamaahCtrl.text.trim();

                setState(() {
                  _todayPrayerTimes = {
                    ...?_todayPrayerTimes,
                    '${prayerKey}Adhan': adhanVal,
                    '${prayerKey}Jamaah': jamaahVal,
                  };
                });

                await ApiService.instance.updatePrayerTimes(_masjidId!, {
                  'date': dateStr,
                  '${prayerKey}Adhan': adhanVal,
                  '${prayerKey}Jamaah': jamaahVal,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('$prayerName timing updated to $jamaahVal!'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
                _loadMasjidData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ApiService.getErrorMessage(e))));
                }
              }
            },
            child: const Text('Save Timing'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: Manage Prayer Times & Special Events
  // -------------------------------------------------------------
  Widget _buildPrayerTimesTab() {
    final bool hasPrayerTimes = _todayPrayerTimes != null &&
        [
          'fajrAdhan',
          'fajrJamaah',
          'dhuhrAdhan',
          'dhuhrJamaah',
          'asrAdhan',
          'asrJamaah',
          'maghribAdhan',
          'maghribJamaah',
          'ishaAdhan',
          'ishaJamaah',
          'jummahKhutbah',
          'jummahJamaah',
        ].any((key) =>
            _todayPrayerTimes![key]?.toString().trim().isNotEmpty == true);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Manage Prayer & Events',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _loadMasjidData),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _masjidId == null
              ? _buildNoMasjidAdminCard()
              : RefreshIndicator(
                  onRefresh: _loadMasjidData,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (!hasPrayerTimes) ...[
                        // // 1. FIRST TIME / EMPTY: SHOW CREATE BUTTON FIRST (NO EDIT BUTTON)
                        const Text('Prayer Timings',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.access_time_filled,
                                      size: 48, color: AppColors.primary),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No Prayer Schedule Found',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Create a prayer schedule for this masjid. Once created, timings will appear here and can be edited anytime.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                      height: 1.4),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      elevation: 2,
                                    ),
                                    icon: const Icon(Icons.add_alarm, size: 22),
                                    label: const Text(
                                      'Create Prayer Schedule',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                    onPressed: _showFullPrayerTimesDialog,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      side: const BorderSide(
                                          color: AppColors.primary, width: 1.2),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    icon:
                                        const Icon(Icons.date_range, size: 20),
                                    label: const Text(
                                      'Set Date Range Schedule',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14),
                                    ),
                                    onPressed: _showDateRangePrayerDialog,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        // 2. TIMINGS CONFIGURED: SHOW SAVED TIMINGS WITH EDIT OPTIONS
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Today Prayer Timings',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8)),
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Edit Schedule',
                                  style: TextStyle(fontSize: 13)),
                              onPressed: _showFullPrayerTimesDialog,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side:
                                    const BorderSide(color: AppColors.primary)),
                            icon: const Icon(Icons.date_range, size: 16),
                            label: const Text('Edit Date Range Schedule',
                                style: TextStyle(fontSize: 12)),
                            onPressed: _showDateRangePrayerDialog,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 2. TIMINGS CONFIGURED: Show Solar & Prayer Timings Cards with Edit Options
                        InkWell(
                          onTap: _showFullPrayerTimesDialog,
                          borderRadius: BorderRadius.circular(12),
                          child: Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Wrap(
                                spacing: 18,
                                runSpacing: 12,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                alignment: WrapAlignment.spaceBetween,
                                children: [
                                  _solarTimeSummary(
                                    Icons.wb_sunny_outlined,
                                    'Sunrise (Ishraq)',
                                    _todayPrayerTimes?['sunrise'],
                                    Colors.orange,
                                  ),
                                  _solarTimeSummary(
                                    Icons.nights_stay_outlined,
                                    'Sunset (Maghrib)',
                                    _todayPrayerTimes?['sunset'],
                                    Colors.indigo,
                                  ),
                                  const Icon(Icons.edit_outlined,
                                      size: 18, color: AppColors.primary),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Daily Prayer Times Config Card
                        Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Tap Jamaah time to edit:',
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.grey)),
                                    TextButton.icon(
                                      icon: const Icon(Icons.edit, size: 14),
                                      label: const Text('Edit All Today'),
                                      onPressed: _showFullPrayerTimesDialog,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                _prayerRowEditable(
                                    'fajr',
                                    'Fajr',
                                    _todayPrayerTimes?['fajrAdhan'],
                                    _todayPrayerTimes?['fajrJamaah']),
                                const Divider(),
                                _prayerRowEditable(
                                    'dhuhr',
                                    'Dhuhr',
                                    _todayPrayerTimes?['dhuhrAdhan'],
                                    _todayPrayerTimes?['dhuhrJamaah']),
                                const Divider(),
                                _prayerRowEditable(
                                    'asr',
                                    'Asr',
                                    _todayPrayerTimes?['asrAdhan'],
                                    _todayPrayerTimes?['asrJamaah']),
                                const Divider(),
                                _prayerRowEditable(
                                    'maghrib',
                                    'Maghrib',
                                    _todayPrayerTimes?['maghribAdhan'],
                                    _todayPrayerTimes?['maghribJamaah']),
                                const Divider(),
                                _prayerRowEditable(
                                    'isha',
                                    'Isha',
                                    _todayPrayerTimes?['ishaAdhan'],
                                    _todayPrayerTimes?['ishaJamaah']),
                                if (_todayPrayerTimes?['jummahJamaah'] !=
                                    null) ...[
                                  const Divider(),
                                  _prayerRowEditable(
                                      'jummah',
                                      'Jummah',
                                      _todayPrayerTimes?['jummahKhutbah'],
                                      _todayPrayerTimes?['jummahJamaah']),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Special Events Section (Ramadan, Eid, Taraweeh, Tahajjud)
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 8,
                        children: [
                          const Text('Special Events (Ramadan / Eid)',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Event',
                                style: TextStyle(fontSize: 12)),
                            onPressed: _showAddSpecialEventDialog,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (_specialSchedules.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.event_available,
                                    color: AppColors.primary, size: 26),
                                const SizedBox(height: 10),
                                const Text(
                                  'No special events yet. Add Ramadan, Eid, Taraweeh, Tahajjud, or another masjid event.',
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton.icon(
                                    onPressed: _showAddSpecialEventDialog,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Create event'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._specialSchedules.map((s) {
                          if (s is! Map<String, dynamic>)
                            return const SizedBox.shrink();
                          final notes = s['notes']?.toString();
                          final title =
                              s['title']?.toString() ?? 'Special Event';
                          final startTime = s['startTime']?.toString() ?? '';
                          final endTime = s['endTime']?.toString();
                          final startDate =
                              s['startDate']?.toString().split('T').first ?? '';
                          final endDate =
                              s['endDate']?.toString().split('T').first;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.1),
                                child: const Icon(Icons.event,
                                    color: AppColors.primary),
                              ),
                              title: Text(title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  'Time: $startTime${endTime != null && endTime.isNotEmpty ? '–$endTime' : ''} • $startDate${endDate != null && endDate.isNotEmpty ? ' to $endDate' : ''}${notes != null && notes.isNotEmpty ? '\n$notes' : ''}'),
                              isThreeLine: notes != null && notes.isNotEmpty,
                              onTap: () =>
                                  _showAddSpecialEventDialog(existing: s),
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    _showAddSpecialEventDialog(existing: s);
                                  } else if (action == 'delete') {
                                    _deleteSpecialSchedule(
                                        s['id']?.toString() ?? '');
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit event'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete event'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTimePickerInput(
      BuildContext ctx, TextEditingController ctrl, String label,
      {bool isRequired = false}) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        labelStyle: const TextStyle(fontSize: 12),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        suffixIcon: IconButton(
          icon: const Icon(Icons.schedule, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () async {
            final parts = ctrl.text.split(':');
            final initialTime = TimeOfDay(
              hour: int.tryParse(parts.first) ?? 12,
              minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
            );
            final picked =
                await showTimePicker(context: ctx, initialTime: initialTime);
            if (picked != null) {
              final h = picked.hour.toString().padLeft(2, '0');
              final m = picked.minute.toString().padLeft(2, '0');
              ctrl.text = '$h:$m';
            }
          },
        ),
      ),
    );
  }

  void _showFullPrayerTimesDialog() {
    final bool isCreating = _todayPrayerTimes == null ||
        _todayPrayerTimes!['fajrJamaah'] == null ||
        _todayPrayerTimes!['fajrJamaah'].toString().trim().isEmpty;

    final dateStr = DateTime.now().toIso8601String().split('T')[0];
    final sunriseCtrl =
        TextEditingController(text: _todayPrayerTimes?['sunrise'] ?? '');
    final sunsetCtrl =
        TextEditingController(text: _todayPrayerTimes?['sunset'] ?? '');

    final fajrACtrl =
        TextEditingController(text: _todayPrayerTimes?['fajrAdhan'] ?? '');
    final fajrJCtrl =
        TextEditingController(text: _todayPrayerTimes?['fajrJamaah'] ?? '');

    final dhuhrACtrl =
        TextEditingController(text: _todayPrayerTimes?['dhuhrAdhan'] ?? '');
    final dhuhrJCtrl =
        TextEditingController(text: _todayPrayerTimes?['dhuhrJamaah'] ?? '');

    final asrACtrl =
        TextEditingController(text: _todayPrayerTimes?['asrAdhan'] ?? '');
    final asrJCtrl =
        TextEditingController(text: _todayPrayerTimes?['asrJamaah'] ?? '');

    final maghribACtrl =
        TextEditingController(text: _todayPrayerTimes?['maghribAdhan'] ?? '');
    final maghribJCtrl =
        TextEditingController(text: _todayPrayerTimes?['maghribJamaah'] ?? '');

    final ishaACtrl =
        TextEditingController(text: _todayPrayerTimes?['ishaAdhan'] ?? '');
    final ishaJCtrl =
        TextEditingController(text: _todayPrayerTimes?['ishaJamaah'] ?? '');

    final jummahKCtrl =
        TextEditingController(text: _todayPrayerTimes?['jummahKhutbah'] ?? '');
    final jummahJCtrl =
        TextEditingController(text: _todayPrayerTimes?['jummahJamaah'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isCreating ? Icons.add_alarm : Icons.edit_calendar,
                color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isCreating
                    ? 'Create Prayer Schedule (அட்டவணை அமைக்க)'
                    : 'Edit Prayer Schedule (அட்டவணையை மாற்ற)',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date: $dateStr (Today)',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 12),

                // Solar Timings
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Solar Timings',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.deepOrange)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                              child: _buildTimePickerInput(
                                  ctx, sunriseCtrl, 'Sunrise')),
                          const SizedBox(width: 6),
                          Expanded(
                              child: _buildTimePickerInput(
                                  ctx, sunsetCtrl, 'Sunset')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 5 Daily Prayers
                const Text('Daily Prayers (Adhan & Jamaah)',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),

                // Fajr
                Row(
                  children: [
                    Expanded(
                        child: _buildTimePickerInput(
                            ctx, fajrACtrl, 'Fajr Adhan')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildTimePickerInput(
                            ctx, fajrJCtrl, 'Fajr Jamaah',
                            isRequired: true)),
                  ],
                ),
                const SizedBox(height: 8),

                // Dhuhr
                Row(
                  children: [
                    Expanded(
                        child: _buildTimePickerInput(
                            ctx, dhuhrACtrl, 'Dhuhr Adhan')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildTimePickerInput(
                            ctx, dhuhrJCtrl, 'Dhuhr Jamaah',
                            isRequired: true)),
                  ],
                ),
                const SizedBox(height: 8),

                // Asr
                Row(
                  children: [
                    Expanded(
                        child:
                            _buildTimePickerInput(ctx, asrACtrl, 'Asr Adhan')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildTimePickerInput(
                            ctx, asrJCtrl, 'Asr Jamaah',
                            isRequired: true)),
                  ],
                ),
                const SizedBox(height: 8),

                // Maghrib
                Row(
                  children: [
                    Expanded(
                        child: _buildTimePickerInput(
                            ctx, maghribACtrl, 'Maghrib Adhan')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildTimePickerInput(
                            ctx, maghribJCtrl, 'Maghrib Jamaah',
                            isRequired: true)),
                  ],
                ),
                const SizedBox(height: 8),

                // Isha
                Row(
                  children: [
                    Expanded(
                        child: _buildTimePickerInput(
                            ctx, ishaACtrl, 'Isha Adhan')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildTimePickerInput(
                            ctx, ishaJCtrl, 'Isha Jamaah',
                            isRequired: true)),
                  ],
                ),
                const SizedBox(height: 14),

                // Jummah (Friday)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Jummah (Friday Prayer)',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.primary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                              child: _buildTimePickerInput(
                                  ctx, jummahKCtrl, 'Jummah Khutbah')),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _buildTimePickerInput(
                                  ctx, jummahJCtrl, 'Jummah Jamaah')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (_masjidId == null) return;
              Navigator.pop(ctx);
              try {
                final payload = <String, dynamic>{
                  'date': dateStr,
                  'sunrise': sunriseCtrl.text.trim(),
                  'sunset': sunsetCtrl.text.trim(),
                  'fajrAdhan': fajrACtrl.text.trim(),
                  'fajrJamaah': fajrJCtrl.text.trim(),
                  'dhuhrAdhan': dhuhrACtrl.text.trim(),
                  'dhuhrJamaah': dhuhrJCtrl.text.trim(),
                  'asrAdhan': asrACtrl.text.trim(),
                  'asrJamaah': asrJCtrl.text.trim(),
                  'maghribAdhan': maghribACtrl.text.trim(),
                  'maghribJamaah': maghribJCtrl.text.trim(),
                  'ishaAdhan': ishaACtrl.text.trim(),
                  'ishaJamaah': ishaJCtrl.text.trim(),
                  'jummahKhutbah': jummahKCtrl.text.trim(),
                  'jummahJamaah': jummahJCtrl.text.trim(),
                };

                setState(() {
                  _todayPrayerTimes = {
                    ...?_todayPrayerTimes,
                    ...payload,
                  };
                });

                await ApiService.instance
                    .updatePrayerTimes(_masjidId!, payload);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isCreating
                          ? 'Prayer schedule created successfully!'
                          : 'Prayer schedule updated successfully!'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
                _loadMasjidData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ApiService.getErrorMessage(e))));
                }
              }
            },
            child: Text(isCreating ? 'Create Schedule' : 'Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showDateRangePrayerDialog() {
    final startCtrl = TextEditingController(
        text: DateTime.now().toIso8601String().split('T')[0]);
    final endCtrl = TextEditingController(
        text: DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String()
            .split('T')[0]);
    final fajrJCtrl = TextEditingController();
    final dhuhrJCtrl = TextEditingController();
    final asrJCtrl = TextEditingController();
    final maghribJCtrl = TextEditingController();
    final ishaJCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Prayer Times Across Date Range'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: startCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Start Date (YYYY-MM-DD)')),
              const SizedBox(height: 12),
              TextField(
                  controller: endCtrl,
                  decoration: const InputDecoration(
                      labelText: 'End Date (YYYY-MM-DD)')),
              const SizedBox(height: 12),
              const Divider(),
              TextField(
                  controller: fajrJCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Fajr Jamaah (HH:mm)')),
              const SizedBox(height: 12),
              TextField(
                  controller: dhuhrJCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Dhuhr Jamaah (HH:mm)')),
              const SizedBox(height: 12),
              TextField(
                  controller: asrJCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Asr Jamaah (HH:mm)')),
              const SizedBox(height: 12),
              TextField(
                  controller: maghribJCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Maghrib Jamaah (HH:mm)')),
              const SizedBox(height: 12),
              TextField(
                  controller: ishaJCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Isha Jamaah (HH:mm)')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            onPressed: () async {
              if (_masjidId == null) return;
              Navigator.pop(ctx);
              try {
                await ApiService.instance.updatePrayerTimeRange(_masjidId!, {
                  'startDate': startCtrl.text.trim(),
                  'endDate': endCtrl.text.trim(),
                  'fajrJamaah': fajrJCtrl.text.trim(),
                  'dhuhrJamaah': dhuhrJCtrl.text.trim(),
                  'asrJamaah': asrJCtrl.text.trim(),
                  'maghribJamaah': maghribJCtrl.text.trim(),
                  'ishaJamaah': ishaJCtrl.text.trim(),
                });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Date range schedule applied!')));
                _loadMasjidData();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ApiService.getErrorMessage(e))));
              }
            },
            child: const Text('Apply Range'),
          ),
        ],
      ),
    );
  }

  void _showAddSpecialEventDialog({Map<String, dynamic>? existing}) {
    final id = existing?['id']?.toString();
    String selectedType = existing?['type']?.toString() ?? 'RAMZAN_TIMETABLE';
    final titleCtrl =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final startCtrl = TextEditingController(
        text: existing?['startDate']?.toString().split('T').first ??
            DateTime.now().toIso8601String().split('T')[0]);
    final endDateCtrl = TextEditingController(
        text: existing?['endDate']?.toString().split('T').first ?? '');
    final timeCtrl =
        TextEditingController(text: existing?['startTime']?.toString() ?? '');
    final endTimeCtrl =
        TextEditingController(text: existing?['endTime']?.toString() ?? '');
    final notesCtrl =
        TextEditingController(text: existing?['notes']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title:
              Text(id == null ? 'Create Special Event' : 'Edit Special Event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Event Type:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: selectedType,
                  items: const [
                    DropdownMenuItem(
                        value: 'RAMZAN_TIMETABLE',
                        child: Text('Ramadan Timetable (நோன்பு அட்டவணை)')),
                    DropdownMenuItem(
                        value: 'TARAWEEH', child: Text('Taraweeh (தராஹீஹ்)')),
                    DropdownMenuItem(
                        value: 'EID_UL_FITR',
                        child: Text('Eid-ul-Fitr (ஈகை பெருநாள் தொழுகை)')),
                    DropdownMenuItem(
                        value: 'EID_UL_ADHA',
                        child: Text('Eid-ul-Adha (பக்ரீத் பெருநாள் தொழுகை)')),
                    DropdownMenuItem(
                        value: 'TAHAJJUD', child: Text('Tahajjud (தஹஜ்ஜுத்)')),
                    DropdownMenuItem(
                        value: 'OTHER', child: Text('Other Special Occasion')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDState(() => selectedType = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: titleCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Event Title *')),
                const SizedBox(height: 12),
                TextField(
                    controller: startCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Start Date (YYYY-MM-DD) *')),
                const SizedBox(height: 12),
                TextField(
                    controller: endDateCtrl,
                    decoration: const InputDecoration(
                        labelText: 'End Date (optional)')),
                const SizedBox(height: 12),
                TextField(
                    controller: timeCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Start Time (HH:mm) *')),
                const SizedBox(height: 12),
                TextField(
                    controller: endTimeCtrl,
                    decoration: const InputDecoration(
                        labelText: 'End Time (optional)')),
                const SizedBox(height: 12),
                TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Notes (e.g. 20 Rakah)')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty ||
                    startCtrl.text.trim().isEmpty ||
                    timeCtrl.text.trim().isEmpty ||
                    _masjidId == null) return;
                Navigator.pop(ctx);
                try {
                  final payload = {
                    'type': selectedType,
                    'title': titleCtrl.text.trim(),
                    'startDate': startCtrl.text.trim(),
                    'startTime': timeCtrl.text.trim(),
                    if (endDateCtrl.text.trim().isNotEmpty)
                      'endDate': endDateCtrl.text.trim(),
                    if (endTimeCtrl.text.trim().isNotEmpty)
                      'endTime': endTimeCtrl.text.trim(),
                    'notes': notesCtrl.text.trim().isEmpty
                        ? null
                        : notesCtrl.text.trim(),
                  };
                  if (id == null) {
                    await ApiService.instance
                        .createSpecialSchedule(_masjidId!, payload);
                  } else {
                    await ApiService.instance
                        .updateSpecialSchedule(_masjidId!, id, payload);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(id == null
                          ? 'Special event created.'
                          : 'Special event updated.')));
                  _loadMasjidData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ApiService.getErrorMessage(e))));
                }
              },
              child: Text(id == null ? 'Create Event' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSpecialSchedule(String id) async {
    if (_masjidId == null) return;
    try {
      await ApiService.instance.deleteSpecialSchedule(_masjidId!, id);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Event deleted!')));
      _loadMasjidData();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ApiService.getErrorMessage(e))));
    }
  }

  // -------------------------------------------------------------
  // TAB 3: Notice Board / Announcements (Send to Connected Musallis)
  // -------------------------------------------------------------
  Widget _buildAnnouncementsTab() {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Masjid Notice Board',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: _masjidId == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_alert),
              label: const Text('New Notice'),
              onPressed: _showCreateNoticeDialog,
            ),
      body: _masjidId == null
          ? _buildNoMasjidAdminCard()
          : _announcements.isEmpty
              ? _buildEmptyCard(
                  'No Announcements Published for this Masjid Yet')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _announcements.length,
                  itemBuilder: (ctx, i) {
                    final a = _announcements[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(a['title'] ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red, size: 20),
                                  onPressed: () => _deleteNotice(a['id']),
                                ),
                              ],
                            ),
                            if (a['titleTa'] != null)
                              Text(a['titleTa'],
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 13)),
                            const SizedBox(height: 8),
                            Text(a['body'] ?? ''),
                            if (a['bodyTa'] != null) ...[
                              const SizedBox(height: 4),
                              Text(a['bodyTa'],
                                  style: const TextStyle(
                                      color: Colors.black87, fontSize: 13)),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              'Sent to all connected musallis • ${a['publishedAt']?.toString().split('T')[0] ?? ''}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _showCreateNoticeDialog() {
    final masjidId = _masjidId;
    if (masjidId == null) return;
    Navigator.of(context)
        .push<bool>(
      MaterialPageRoute(
        builder: (_) => NoticeEditorScreen(
          onSave: (title, message, {imageUrl, audioUrl, audioDuration}) async {
            await ApiService.instance.createAnnouncement(masjidId, {
              'category': 'GENERAL',
              'title': title,
              'body': message,
              if (imageUrl != null) 'imageUrl': imageUrl,
              if (audioUrl != null) 'audioUrl': audioUrl,
              if (audioDuration != null) 'audioDuration': audioDuration,
              'notifyPush': true,
            });
          },
        ),
      ),
    )
        .then((created) async {
      if (!mounted || created != true) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Notice sent to connected members.'),
      ));
      await _loadMasjidData();
    });
  }

  Future<void> _deleteNotice(String id) async {
    if (_masjidId == null) return;
    try {
      await ApiService.instance.deleteAnnouncement(_masjidId!, id);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Notice deleted!')));
      _loadMasjidData();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ApiService.getErrorMessage(e))));
    }
  }

  // -------------------------------------------------------------
  // TAB 4: Manage Members & Roles
  // -------------------------------------------------------------
  Widget _buildMembersTab() {
    final memberships = (_membersData?['memberships'] as List<dynamic>?) ?? [];
    final admins = (_membersData?['admins'] as List<dynamic>?) ?? [];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Manage Members & Roles',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            tooltip: 'Masjid QR Code',
            onPressed: _showInviteQrDialog,
          ),
        ],
      ),
      floatingActionButton: _masjidId == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Member'),
              onPressed: _showAddMemberDialog,
            ),
      body: _masjidId == null
          ? _buildNoMasjidAdminCard()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                        child: Icon(Icons.volunteer_activism)),
                    title: const Text('Sandha Management',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text(
                        'Set monthly UPI details, review receipts, and view collections by month.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            SandhaManagementScreen(masjidId: _masjidId!))),
                  ),
                ),
                const SizedBox(height: 8),
                // Live Masjid QR Code Card (Prominently displayed)
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.qr_code_2,
                                    color: AppColors.primary, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  _masjidName ?? 'Masjid',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: AppColors.primary, width: 0.8),
                              ),
                              child: const Text('JOIN QR',
                                  style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        InkWell(
                          onTap: _openFullscreenQr,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.grey.shade300, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3)),
                              ],
                            ),
                            child: QrImageView(
                              data: (_masjidDetails?['qrToken']
                                          ?.toString()
                                          .isNotEmpty ==
                                      true)
                                  ? _masjidDetails!['qrToken'].toString()
                                  : (_masjidId ?? 'silah-masjid'),
                              version: QrVersions.auto,
                              size: 180.0,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: AppColors.primary),
                              dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: AppColors.primary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SelectableText(
                          'Token: ${(_masjidDetails?['qrToken']?.toString().isNotEmpty == true) ? _masjidDetails!['qrToken'].toString() : (_masjidId ?? 'silah-masjid')}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: Colors.black87),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Musallis can scan this QR code with Silah App to join instantly!\n(பள்ளிவாசலில் இணைய இந்த QR குறியீட்டை ஸ்கேன் செய்யவும்)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.grey, fontSize: 12, height: 1.3),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 11, horizontal: 12),
                                ),
                                icon: const Icon(Icons.fullscreen, size: 19),
                                label: const Text('Fullscreen QR & Options',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                                onPressed: _openFullscreenQr,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Roles & Committee Card
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Masjid Admins & Roles',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      icon: const Icon(Icons.security, size: 16),
                      label: const Text('Assign Role'),
                      onPressed: _showAssignRoleDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (admins.isEmpty)
                  _buildEmptyCard('No custom roles assigned yet.')
                else
                  ...admins.map((adm) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child:
                              Icon(Icons.shield, color: Colors.white, size: 18),
                        ),
                        title: Text(adm['name'] ?? '',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(adm['phone'] ?? ''),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(adm['role'] ?? '',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11)),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 20),

                // Musallis / Members Section
                Text('Connected Members (${memberships.length})',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                if (memberships.isEmpty)
                  _buildEmptyCard(
                      'No members connected yet. Tap Add Member to enroll.')
                else
                  ...memberships.map((m) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey.shade200,
                          child: const Icon(Icons.person, color: Colors.grey),
                        ),
                        title: Text(m['name'] ?? 'Member',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '${m['phone'] ?? ''} ${m['address'] != null ? '• ${m['address']}' : ''}'),
                      ),
                    );
                  }),
              ],
            ),
    );
  }

  void _openFullscreenQr() {
    final rawToken = _masjidDetails?['qrToken']?.toString();
    final qrData = (rawToken != null && rawToken.trim().isNotEmpty)
        ? rawToken.trim()
        : (_masjidId ?? 'silah-masjid');
    final masjidName = _masjidName ?? _masjidDetails?['name'] ?? 'Masjid';
    final masjidNameTa = _masjidDetails?['nameTa']?.toString();
    final city = (_masjidDetails?['city'] ?? '').toString();
    final address = (_masjidDetails?['address'] ?? '').toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MasjidInviteQrScreen(
          masjidId: _masjidId ?? '',
          masjidName: masjidName,
          masjidNameTa: masjidNameTa,
          city: city,
          address: address,
          qrToken: qrData,
        ),
      ),
    );
  }

  void _showInviteQrDialog() => _openFullscreenQr();

  void _showAddMemberDialog() {
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final rawToken = _masjidDetails?['qrToken']?.toString();
    final qrData = (rawToken != null && rawToken.trim().isNotEmpty)
        ? rawToken.trim()
        : (_masjidId ?? 'silah-masjid');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: const [
            Icon(Icons.person_add, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Add Member to Masjid',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. QR Code Section: Generate and display QR for instant join
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.qr_code_2,
                              size: 20, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'Instant Join via QR Code',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _openFullscreenQr();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: QrImageView(
                            data: qrData,
                            version: QrVersions.auto,
                            size: 160.0,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: AppColors.primary),
                            dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact),
                        icon: const Icon(Icons.fullscreen, size: 16),
                        label: const Text('Fullscreen QR, Print & WhatsApp',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openFullscreenQr();
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('OR Enter Manually',
                          style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Manual Entry Section
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Mobile Number (+91...) *',
                    isDense: true,
                    prefixIcon: const Icon(Icons.phone, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Member Name',
                    isDense: true,
                    prefixIcon: const Icon(Icons.person, size: 20),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (phoneCtrl.text.isEmpty || _masjidId == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Please enter mobile number')));
                return;
              }
              Navigator.pop(ctx);
              try {
                await ApiService.instance.addMasjidMember(_masjidId!,
                    phone: phoneCtrl.text.trim(), name: nameCtrl.text.trim());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Member added successfully!')));
                }
                _loadMasjidData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ApiService.getErrorMessage(e))));
                }
              }
            },
            child: const Text('Add Member'),
          ),
        ],
      ),
    );
  }

  void _showAssignRoleDialog() {
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String selectedRole = 'FINANCE';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Assign Custom Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: phoneCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Mobile Number *')),
              const SizedBox(height: 12),
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name *')),
              const SizedBox(height: 10),
              DropdownButton<String>(
                isExpanded: true,
                value: selectedRole,
                items: const [
                  DropdownMenuItem(
                      value: 'ADMIN', child: Text('Admin (Mutawalli)')),
                  DropdownMenuItem(
                      value: 'FINANCE', child: Text('Finance (Treasurer)')),
                  DropdownMenuItem(
                      value: 'ANNOUNCEMENT',
                      child: Text('Announcement Volunteer')),
                ],
                onChanged: (v) {
                  if (v != null) setDState(() => selectedRole = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
              onPressed: () async {
                if (phoneCtrl.text.isEmpty ||
                    nameCtrl.text.isEmpty ||
                    _masjidId == null) return;
                Navigator.pop(ctx);
                try {
                  await ApiService.instance.assignRole(
                    _masjidId!,
                    phone: phoneCtrl.text.trim(),
                    name: nameCtrl.text.trim(),
                    role: selectedRole,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Role assigned!')));
                  _loadMasjidData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ApiService.getErrorMessage(e))));
                }
              },
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 5: Masjid Profile & Settings
  // -------------------------------------------------------------
  Widget _buildProfileTab() {
    final nameCtrl = TextEditingController(text: _masjidDetails?['name'] ?? '');
    final nameTaCtrl =
        TextEditingController(text: _masjidDetails?['nameTa'] ?? '');
    final cityCtrl = TextEditingController(text: _masjidDetails?['city'] ?? '');
    final addrCtrl =
        TextEditingController(text: _masjidDetails?['address'] ?? '');
    final latCtrl = TextEditingController(
        text: _masjidDetails?['latitude']?.toString() ?? '');
    final lngCtrl = TextEditingController(
        text: _masjidDetails?['longitude']?.toString() ?? '');
    final phoneCtrl =
        TextEditingController(text: _masjidDetails?['phone'] ?? '');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Masjid Settings & Profile',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Masjid Details',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Masjid Name')),
                  TextField(
                      controller: nameTaCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Tamil Name')),
                  TextField(
                      controller: cityCtrl,
                      decoration: const InputDecoration(labelText: 'City')),
                  TextField(
                      controller: addrCtrl,
                      decoration: const InputDecoration(labelText: 'Address')),
                  TextField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Phone')),
                  Row(
                    children: [
                      Expanded(
                          child: TextField(
                              controller: latCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Latitude'))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: TextField(
                              controller: lngCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Longitude'))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: () async {
                      if (_masjidId == null) return;
                      try {
                        await ApiService.instance.updateMasjid(_masjidId!, {
                          'name': nameCtrl.text.trim(),
                          'nameTa': nameTaCtrl.text.trim().isEmpty
                              ? null
                              : nameTaCtrl.text.trim(),
                          'city': cityCtrl.text.trim(),
                          'address': addrCtrl.text.trim(),
                          'phone': phoneCtrl.text.trim().isEmpty
                              ? null
                              : phoneCtrl.text.trim(),
                          'latitude': double.tryParse(latCtrl.text),
                          'longitude': double.tryParse(lngCtrl.text),
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Masjid details updated!')));
                        _loadMasjidData();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(ApiService.getErrorMessage(e))));
                      }
                    },
                    child: const Text('Save Details'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Options
          ListTile(
            tileColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.home, color: AppColors.primary),
            title: const Text('Switch to User App (Home)'),
            onTap: () {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()));
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log Out',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () async {
              await ApiService.instance.clearSession();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const OtpLoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String msg) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(msg,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: switch (_currentIndex) {
        0 => _buildDashboardTab(),
        1 => _buildPrayerTimesTab(),
        2 => _buildAnnouncementsTab(),
        3 => _buildMembersTab(),
        _ => _buildProfileTab(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule_rounded),
            label: 'Prayer',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign_rounded),
            label: 'Notices',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Members',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
