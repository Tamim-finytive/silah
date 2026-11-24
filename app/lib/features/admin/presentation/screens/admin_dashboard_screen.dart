import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:masjid_namaz_app/core/constants/app_colors.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masjid_namaz_app/core/l10n/language_provider.dart';
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
import 'package:masjid_namaz_app/features/sandha/presentation/screens/sandha_settings_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String? masjidId;
  final String? masjidName;
  const AdminDashboardScreen({super.key, this.masjidId, this.masjidName});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const _storage = FlutterSecureStorage();
  static const _lastAdminMasjidKey = 'last_selected_admin_masjid_id';
  static const _lastAdminMasjidNameKey = 'last_selected_admin_masjid_name';

  int _currentIndex = 0;
  bool _isLoading = true;
  final ScrollController _prayerTabScrollController = ScrollController();
  String? _prayerDataError;

  String? _masjidId;
  String? _masjidName;
  Map<String, dynamic>? _masjidDetails;
  Map<String, dynamic>? _adminOverview;
  Map<String, dynamic>? _todayPrayerTimes;
  Map<String, dynamic>? _dashboardPrayerTimes;
  List<dynamic> _monthPrayerTimes = [];
  List<dynamic> _monthRamadanTimes = [];
  DateTime _visibleScheduleMonth =
      DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedScheduleDate =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  bool _calendarRangeMode = false;
  DateTime? _calendarRangeStart;
  DateTime? _calendarRangeEnd;
  int _prayerEventsTab = 0;
  bool _isScheduleCalendarLoading = false;
  String? _scheduleCalendarError;
  String? _prayerScheduleLoadError;
  List<dynamic> _specialSchedules = [];
  List<dynamic> _announcements = [];
  Map<String, dynamic>? _membersData;
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;
  StreamSubscription<InactiveMasjidEvent>? _inactiveMasjidSubscription;
  bool _isMasjidInactive = false;

  @override
  void initState() {
    super.initState();
    _masjidId = widget.masjidId;
    _masjidName = widget.masjidName;
    _inactiveMasjidSubscription =
        ApiService.instance.inactiveMasjidEvents.listen((event) {
      if (mounted && event.masjidId == _masjidId) {
        setState(() => _isMasjidInactive = true);
      }
    });
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
    _inactiveMasjidSubscription?.cancel();
    _prayerTabScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMasjidData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _prayerDataError = null;
      });
    }
    try {
      String? mId = _masjidId ?? widget.masjidId;
      String? mName = _masjidName ?? widget.masjidName;
      var user = ApiService.instance.currentUser;
      if (mId == null &&
          (user == null ||
              (user['adminRoles'] == null && user['masjidAdmins'] == null))) {
        user = await ApiService.instance.getProfile() ?? user;
      }

      final adminRoles = (user?['adminRoles'] as List<dynamic>?) ??
          (ApiService.instance.currentUser?['adminRoles'] as List<dynamic>?);

      // 1. Check stored last selected admin masjid
      if (widget.masjidId == null && mId == null) {
        final lastSavedId = await _storage.read(key: _lastAdminMasjidKey);
        final lastSavedName = await _storage.read(key: _lastAdminMasjidNameKey);
        if (lastSavedId != null && adminRoles != null) {
          final matchingRole = adminRoles.firstWhere(
            (r) =>
                r is Map<String, dynamic> &&
                r['masjidId']?.toString() == lastSavedId,
            orElse: () => null,
          );
          if (matchingRole != null && matchingRole is Map<String, dynamic>) {
            mId = matchingRole['masjidId']?.toString();
            mName = matchingRole['masjidName']?.toString();
          } else if (lastSavedId.isNotEmpty) {
            final masjidAdmins = user?['masjidAdmins'] as List<dynamic>?;
            final matchingAdmin = masjidAdmins?.firstWhere(
              (r) =>
                  r is Map<String, dynamic> &&
                  r['masjidId']?.toString() == lastSavedId,
              orElse: () => null,
            );
            if (matchingAdmin != null &&
                matchingAdmin is Map<String, dynamic>) {
              mId = matchingAdmin['masjidId']?.toString();
              mName =
                  matchingAdmin['masjid']?['name']?.toString() ?? lastSavedName;
            }
          }
        }
      }

      // 2. Fallback to first role in adminRoles
      if (mId == null) {
        if (adminRoles != null && adminRoles.isNotEmpty) {
          final primary = adminRoles.first;
          if (primary is Map<String, dynamic>) {
            mId = primary['masjidId']?.toString();
            mName = primary['masjidName']?.toString();
          }
        }
      }

      // 3. Fallback to first in masjidAdmins
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

        // Start the prayer month request in parallel with dashboard requests.
        // Home remains in loading state until both finish, so it cannot show a
        // false create-schedule prompt during hot restart.
        final scheduleLoad = _loadScheduleCalendar(mId);

        // Automatically store active selection so reopening the app sets this masjid
        await _storage.write(key: _lastAdminMasjidKey, value: mId);
        if (_masjidName != null) {
          await _storage.write(
              key: _lastAdminMasjidNameKey, value: _masjidName);
        }

        final overview = await ApiService.instance.getMasjidAdminOverview(mId);
        final masjidInfo = await ApiService.instance.getMasjidById(mId);
        Map<String, dynamic>? todayTimes;
        String? prayerTimesError;
        try {
          todayTimes = await ApiService.instance.getTodayPrayerTimes(mId);
        } catch (error) {
          prayerTimesError = ApiService.getErrorMessage(error,
              fallback: 'Prayer schedule could not be loaded.');
        }
        final schedules = await ApiService.instance.getSpecialSchedules(mId);
        final notices = await ApiService.instance.getAnnouncements(mId);
        final members = await ApiService.instance.getMasjidMembers(mId);
        await scheduleLoad;

        if (mounted) {
          setState(() {
            _adminOverview = overview;
            _masjidDetails = masjidInfo ?? overview?['masjid'];
            // The overview already includes the saved current-day record. Use
            // it if the dedicated endpoint returns an empty response so both
            // admin surfaces stay consistent with the same backend data.
            final overviewTimes = overview?['todayPrayerTimes'];
            final today = DateTime.now();
            final selectedDateIsToday =
                _selectedScheduleDate.year == today.year &&
                    _selectedScheduleDate.month == today.month &&
                    _selectedScheduleDate.day == today.day;
            if (selectedDateIsToday) {
              // Keep a row found by the month query if the single-day request
              // returns null; both endpoints read the same saved prayer row.
              _todayPrayerTimes = todayTimes ??
                  (overviewTimes is Map
                      ? Map<String, dynamic>.from(overviewTimes)
                      : _todayPrayerTimes);
              _dashboardPrayerTimes = _todayPrayerTimes;
              _prayerDataError =
                  _prayerScheduleLoadError == null ? null : prayerTimesError;
            }
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
            _dashboardPrayerTimes = null;
            _monthPrayerTimes = [];
            _monthRamadanTimes = [];
            _scheduleCalendarError = null;
            _prayerScheduleLoadError = null;
            _specialSchedules = [];
            _announcements = [];
            _membersData = null;
            _isLoading = false;
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _prayerDataError = ApiService.getErrorMessage(error,
              fallback: 'Prayer data could not be loaded. Please retry.');
          _isLoading = false;
        });
      }
    }
  }

  String _calendarDateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String? _rowDateKey(dynamic row) {
    if (row is! Map) return null;
    final value = row['date']?.toString();
    if (value == null || value.length < 10) return null;
    return value.substring(0, 10);
  }

  dynamic _rowForDate(List<dynamic> rows, DateTime date) {
    final key = _calendarDateKey(date);
    for (final row in rows) {
      if (_rowDateKey(row) == key) return row;
    }
    return null;
  }

  Future<void> _loadScheduleCalendar(String masjidId, {DateTime? month}) async {
    final targetMonth = month ?? _visibleScheduleMonth;
    if (mounted) {
      setState(() {
        _isScheduleCalendarLoading = true;
        _scheduleCalendarError = null;
      });
    }
    try {
      List<dynamic> prayers = [];
      List<dynamic> fasting = [];
      String? loadError;
      String? prayerError;
      try {
        prayers = await ApiService.instance.getPrayerScheduleMonth(
            masjidId, targetMonth.year, targetMonth.month);
      } catch (error) {
        prayerError = ApiService.getErrorMessage(error,
            fallback: 'Prayer schedule could not be loaded.');
        loadError = prayerError;
      }
      try {
        fasting = await ApiService.instance.getRamadanScheduleMonth(
            masjidId, targetMonth.year, targetMonth.month);
      } catch (_) {
        // Fasting schedule is optional for non-Ramadan months; don't fail calendar
      }
      if (!mounted || masjidId != _masjidId) return;
      final selectedRow = _rowForDate(prayers, _selectedScheduleDate);
      final todayRow = _rowForDate(prayers, DateTime.now());
      final selectedDateIsToday = _calendarDateKey(_selectedScheduleDate) ==
          _calendarDateKey(DateTime.now());
      final currentPrayerRow = _todayPrayerTimes;
      final resolvedTodayRow = selectedRow is Map
          ? Map<String, dynamic>.from(selectedRow)
          : todayRow is Map
              ? Map<String, dynamic>.from(todayRow)
              : selectedDateIsToday
                  ? currentPrayerRow
                  : null;
      setState(() {
        _visibleScheduleMonth = DateTime(targetMonth.year, targetMonth.month);
        _monthPrayerTimes = prayers;
        _monthRamadanTimes = fasting;
        _scheduleCalendarError = loadError;
        _prayerScheduleLoadError = prayerError;
        if (_selectedScheduleDate.year == targetMonth.year &&
            _selectedScheduleDate.month == targetMonth.month) {
          _todayPrayerTimes = selectedDateIsToday
              ? resolvedTodayRow
              : selectedRow is Map
                  ? Map<String, dynamic>.from(selectedRow)
                  : null;
        }
        if (selectedDateIsToday && prayerError == null) {
          _dashboardPrayerTimes = resolvedTodayRow;
        }
        _isScheduleCalendarLoading = false;
      });
    } catch (error) {
      if (mounted && masjidId == _masjidId) {
        setState(() {
          _scheduleCalendarError = ApiService.getErrorMessage(error,
              fallback: 'Schedule calendar could not be loaded.');
          _isScheduleCalendarLoading = false;
        });
      }
    }
  }

  Future<void> _changeScheduleMonth(int offset) async {
    final next = DateTime(
        _visibleScheduleMonth.year, _visibleScheduleMonth.month + offset);
    setState(() {
      _visibleScheduleMonth = next;
      _selectedScheduleDate = DateTime(next.year, next.month, 1);
      _todayPrayerTimes = null;
      _monthPrayerTimes = [];
      _monthRamadanTimes = [];
      _scheduleCalendarError = null;
      _prayerScheduleLoadError = null;
    });
    final masjidId = _masjidId;
    if (masjidId != null) await _loadScheduleCalendar(masjidId, month: next);
  }

  Future<void> _selectScheduleDate(DateTime date) async {
    setState(() {
      _selectedScheduleDate = DateTime(date.year, date.month, date.day);
      _todayPrayerTimes = null;
    });
    final prayerRow = _rowForDate(_monthPrayerTimes, date);
    if (prayerRow is Map) {
      setState(() {
        _todayPrayerTimes = Map<String, dynamic>.from(prayerRow);
        _prayerDataError = null;
      });
      return;
    }
    final today = DateTime.now();
    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      try {
        final row = await ApiService.instance.getTodayPrayerTimes(_masjidId!);
        if (mounted && row != null) setState(() => _todayPrayerTimes = row);
      } catch (error) {
        if (mounted)
          setState(() => _prayerDataError = ApiService.getErrorMessage(error));
      }
    }
  }

  void _handleScheduleCalendarTap(DateTime date) {
    if (!_calendarRangeMode) {
      _selectScheduleDate(date);
      return;
    }
    final day = DateTime(date.year, date.month, date.day);
    if (_calendarRangeStart == null || _calendarRangeEnd != null) {
      setState(() {
        _calendarRangeStart = day;
        _calendarRangeEnd = null;
      });
      return;
    }
    final first = _calendarRangeStart!;
    final range = DateTimeRange(
      start: day.isBefore(first) ? day : first,
      end: day.isBefore(first) ? first : day,
    );
    final rangeDays = range.duration.inDays + 1;
    if (_prayerEventsTab == 0 && rangeDays > 31) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Prayer schedules can cover up to 31 days at a time.')),
      );
      setState(() {
        _calendarRangeEnd = null;
        _calendarRangeMode = true;
      });
      return;
    }
    setState(() {
      _calendarRangeStart = range.start;
      _calendarRangeEnd = range.end;
      _calendarRangeMode = false;
      _selectedScheduleDate = range.start;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_prayerEventsTab == 0) {
        _showDateRangePrayerDialog(initialRange: range);
      } else {
        _chooseEventsRangeAction(range);
      }
    });
  }

  void _chooseEventsRangeAction(DateTimeRange range) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('What do you want to schedule?'),
        content: Text(
            '${_calendarDateKey(range.start)} to ${_calendarDateKey(range.end)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showAddSpecialEventDialog(
                startDate: _calendarDateKey(range.start),
                endDate: _calendarDateKey(range.end),
              );
            },
            child: const Text('Special prayer / event'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showRamadanRangeDialog(initialRange: range);
            },
            child: const Text('Fasting times'),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCalendar() {
    final first =
        DateTime(_visibleScheduleMonth.year, _visibleScheduleMonth.month, 1);
    final daysInMonth =
        DateTime(_visibleScheduleMonth.year, _visibleScheduleMonth.month + 1, 0)
            .day;
    final leading = (first.weekday % 7);
    final selectedKey = _calendarDateKey(_selectedScheduleDate);
    final prayerDates =
        _monthPrayerTimes.map(_rowDateKey).whereType<String>().toSet();
    final ramadanDates =
        _monthRamadanTimes.map(_rowDateKey).whereType<String>().toSet();
    final eventDates = <String>{};
    for (final event in _specialSchedules) {
      if (event is! Map) continue;
      final start = DateTime.tryParse(event['startDate']?.toString() ?? '');
      final end =
          DateTime.tryParse(event['endDate']?.toString() ?? '') ?? start;
      if (start == null || end == null) continue;
      for (var d = DateTime(start.year, start.month, start.day);
          !d.isAfter(DateTime(end.year, end.month, end.day));
          d = d.add(const Duration(days: 1))) {
        if (d.year == _visibleScheduleMonth.year &&
            d.month == _visibleScheduleMonth.month) {
          eventDates.add(_calendarDateKey(d));
        }
      }
    }
    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) cells.add(const SizedBox(height: 48));
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(
          _visibleScheduleMonth.year, _visibleScheduleMonth.month, day);
      final key = _calendarDateKey(date);
      final isSelected = key == selectedKey;
      final rangeStart = _calendarRangeStart;
      final rangeEnd = _calendarRangeEnd;
      final inSelectedRange = rangeStart != null &&
          !date.isBefore(
              DateTime(rangeStart.year, rangeStart.month, rangeStart.day)) &&
          (rangeEnd == null ||
              !date.isAfter(
                  DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day)));
      final hasPrayer = prayerDates.contains(key);
      final hasRamadan = ramadanDates.contains(key);
      final hasEvent = eventDates.contains(key);
      cells.add(InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _handleScheduleCalendarTap(date),
        child: Container(
          height: 48,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : inSelectedRange
                    ? AppColors.primary.withValues(alpha: 0.14)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: !isSelected && _calendarDateKey(DateTime.now()) == key
                ? Border.all(color: AppColors.primary, width: 1.2)
                : null,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$day',
                style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : null)),
            const SizedBox(height: 2),
            Wrap(spacing: 2, children: [
              if (hasPrayer)
                _calendarDot(isSelected ? Colors.white : AppColors.primary),
              if (hasRamadan)
                _calendarDot(isSelected ? Colors.white : Colors.orange),
              if (hasEvent)
                _calendarDot(isSelected ? Colors.white : Colors.purple),
            ]),
          ]),
        ),
      ));
    }
    final weeks = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      weeks.add(Row(
          children: List.generate(
              7,
              (j) => Expanded(
                  child: i + j < cells.length
                      ? cells[i + j]
                      : const SizedBox(height: 48)))));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            IconButton(
                onPressed: () => _changeScheduleMonth(-1),
                icon: const Icon(Icons.chevron_left)),
            Expanded(
                child: Text(
                    '${_monthName(_visibleScheduleMonth.month)} ${_visibleScheduleMonth.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16))),
            IconButton(
                onPressed: () => _changeScheduleMonth(1),
                icon: const Icon(Icons.chevron_right)),
          ]),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _calendarRangeMode = !_calendarRangeMode;
                _calendarRangeStart = null;
                _calendarRangeEnd = null;
              }),
              icon: Icon(_calendarRangeMode ? Icons.close : Icons.date_range),
              label: Text(
                  _calendarRangeMode ? 'Cancel range' : 'Select date range'),
            ),
          ),
          if (_calendarRangeMode)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _calendarRangeStart == null
                    ? 'Tap the start date, then tap the end date.'
                    : 'Start date: ${_calendarDateKey(_calendarRangeStart!)} · tap an end date.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          Row(
              children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                  .map((d) => Expanded(
                      child: Center(
                          child: Text(d,
                              style: const TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600)))))
                  .toList()),
          const SizedBox(height: 4),
          ...weeks,
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 6, children: [
            _calendarLegend(AppColors.primary, 'Prayer'),
            _calendarLegend(Colors.orange, 'Fasting'),
            _calendarLegend(Colors.purple, 'Special event'),
          ]),
          if (_isScheduleCalendarLoading)
            const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 2)),
          if (_scheduleCalendarError != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Expanded(
                      child: Text(_scheduleCalendarError ?? '',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
                  TextButton(
                      onPressed: () {
                        final id = _masjidId;
                        if (id != null) _loadScheduleCalendar(id);
                      },
                      child: const Text('Retry'))
                ])),
        ]),
      ),
    );
  }

  Widget _calendarDot(Color color) => Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  Widget _calendarLegend(Color color, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        _calendarDot(color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11))
      ]);
  String _monthName(int month) => const [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ][month - 1];

  Widget _buildSelectedEventsPanel() {
    final fasting = _rowForDate(_monthRamadanTimes, _selectedScheduleDate);
    final selectedDate = _calendarDateKey(_selectedScheduleDate);
    final events = _specialSchedules.where((item) {
      if (item is! Map) return false;
      final start = DateTime.tryParse(item['startDate']?.toString() ?? '');
      final end = DateTime.tryParse(item['endDate']?.toString() ?? '') ?? start;
      if (start == null || end == null) return false;
      final date = DateTime(_selectedScheduleDate.year,
          _selectedScheduleDate.month, _selectedScheduleDate.day);
      return !date.isBefore(DateTime(start.year, start.month, start.day)) &&
          !date.isAfter(DateTime(end.year, end.month, end.day));
    }).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Events on $selectedDate',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      const SizedBox(height: 10),
      Card(
          child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.nightlight_round, color: Colors.orange),
            const SizedBox(width: 8),
            const Expanded(
                child: Text('Fasting times',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            TextButton.icon(
              onPressed: _showRamadanScheduleDialog,
              icon: Icon(fasting == null ? Icons.add : Icons.edit, size: 17),
              label: Text(fasting == null ? 'Add' : 'Edit'),
            ),
          ]),
          if (fasting == null)
            const Text('No fasting times saved for this date.',
                style: TextStyle(color: Colors.grey))
          else
            Wrap(spacing: 18, runSpacing: 8, children: [
              _eventTime('Sehri ends', fasting['sehriEnd']),
              _eventTime('Iftar', fasting['iftarTime']),
              if ((fasting['notes']?.toString() ?? '').isNotEmpty)
                _eventTime('Note', fasting['notes']),
            ]),
        ]),
      )),
      const SizedBox(height: 12),
      Row(children: [
        const Expanded(
            child: Text('Special prayers and events',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        FilledButton.icon(
            onPressed: _showAddSpecialEventDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add')),
      ]),
      const SizedBox(height: 8),
      if (events.isEmpty && _isLoading)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Expanded(child: Text('Loading saved events…')),
            ]),
          ),
        )
      else if (events.isEmpty)
        const Card(
            child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'No special events on this date. Add Taraweeh, Eid prayer, or another event.')))
      else
        ...events.map((item) {
          final event = Map<String, dynamic>.from(item as Map);
          final notes = event['notes']?.toString();
          return Card(
            child: ListTile(
              leading: const CircleAvatar(
                  child: Icon(Icons.event, color: AppColors.primary)),
              title: Text(event['title']?.toString() ?? 'Special event',
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                  '${event['startTime'] ?? ''}${event['endTime'] == null ? '' : ' – ${event['endTime']}'}${(notes ?? '').isEmpty ? '' : '\n$notes'}'),
              isThreeLine: (notes ?? '').isNotEmpty,
              onTap: () => _showAddSpecialEventDialog(existing: event),
              trailing: PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'edit')
                    _showAddSpecialEventDialog(existing: event);
                  if (action == 'delete')
                    _deleteSpecialSchedule(event['id']?.toString() ?? '');
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
          );
        }),
    ]);
  }

  Widget _eventTime(String label, dynamic value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value?.toString() ?? '—',
            style: const TextStyle(fontWeight: FontWeight.w600))
      ]);

  void _showRamadanScheduleDialog() {
    if (_masjidId == null) return;
    final existing = _rowForDate(_monthRamadanTimes, _selectedScheduleDate);
    final sehri = TextEditingController(
        text: existing is Map ? existing['sehriEnd']?.toString() ?? '' : '');
    final iftar = TextEditingController(
        text: existing is Map ? existing['iftarTime']?.toString() ?? '' : '');
    final notes = TextEditingController(
        text: existing is Map ? existing['notes']?.toString() ?? '' : '');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title:
            Text(existing == null ? 'Add fasting times' : 'Edit fasting times'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_calendarDateKey(_selectedScheduleDate)),
          const SizedBox(height: 12),
          _buildTimePickerInput(dialogContext, sehri, 'Sehri ends *'),
          const SizedBox(height: 12),
          _buildTimePickerInput(dialogContext, iftar, 'Iftar *'),
          const SizedBox(height: 12),
          TextField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'Notes (optional)')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (sehri.text.trim().isEmpty || iftar.text.trim().isEmpty)
                return;
              Navigator.pop(dialogContext);
              try {
                final id = _masjidId;
                if (id == null) return;
                await ApiService.instance.saveRamadanSchedule(id, [
                  {
                    'date': _calendarDateKey(_selectedScheduleDate),
                    'sehriEnd': sehri.text.trim(),
                    'iftarTime': iftar.text.trim(),
                    if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim()
                  },
                ]);
                await _loadScheduleCalendar(id);
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Alhamdulillah! Fasting times saved.')));
              } catch (error) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ApiService.getErrorMessage(error))));
              }
            },
            child: const Text('Save times'),
          ),
        ],
      ),
    );
  }

  void _showSwitchAdminMasjidSheet() {
    final user = ApiService.instance.currentUser;
    final adminRoles = (user?['adminRoles'] as List<dynamic>?) ?? [];
    if (adminRoles.isEmpty) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Switch Admin Masjid',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              ...adminRoles.map((role) {
                if (role is! Map<String, dynamic>) {
                  return const SizedBox.shrink();
                }
                final roleMasjidId = role['masjidId']?.toString();
                final roleMasjidName =
                    role['masjidName']?.toString() ?? 'Masjid';
                final isSelected = roleMasjidId == _masjidId;

                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.mosque,
                      color: isSelected ? Colors.white : AppColors.primary,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    roleMasjidName,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? AppColors.primary : Colors.black87,
                    ),
                  ),
                  subtitle: Text(role['role']?.toString() ?? 'Admin'),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: AppColors.primary)
                      : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (roleMasjidId != null && roleMasjidId != _masjidId) {
                      setState(() {
                        _masjidId = roleMasjidId;
                        _masjidName = roleMasjidName;
                        _todayPrayerTimes = null;
                        _dashboardPrayerTimes = null;
                        _monthPrayerTimes = [];
                        _monthRamadanTimes = [];
                        _prayerScheduleLoadError = null;
                        _scheduleCalendarError = null;
                        _isMasjidInactive = false;
                        _isLoading = true;
                      });
                      await _storage.write(
                          key: _lastAdminMasjidKey, value: roleMasjidId);
                      await _storage.write(
                          key: _lastAdminMasjidNameKey, value: roleMasjidName);
                      _loadMasjidData();
                    }
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: Dashboard Overview
  // -------------------------------------------------------------
  Widget _buildDashboardTab() {
    final metrics = _adminOverview?['metrics'] ?? {};
    final memberCount = metrics['memberCount'] ?? 0;
    final noticesCount =
        metrics['activeAnnouncementsCount'] ?? _announcements.length;
    final dashboardPrayerTimes = _dashboardPrayerTimes;
    final user = ApiService.instance.currentUser;
    final adminRoles = (user?['adminRoles'] as List<dynamic>?) ?? [];
    final hasMultipleMasjids = adminRoles.length > 1;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: InkWell(
          onTap: hasMultipleMasjids ? _showSwitchAdminMasjidSheet : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(_masjidName ?? 'Masjid Admin Dashboard',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (hasMultipleMasjids) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down,
                      color: Colors.white, size: 22),
                ],
              ],
            ),
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (hasMultipleMasjids)
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Switch Admin Masjid',
              onPressed: _showSwitchAdminMasjidSheet,
            ),
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

                    if (dashboardPrayerTimes == null &&
                        _isScheduleCalendarLoading) ...[
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Row(children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.2, color: AppColors.primary),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('Loading saved prayer schedule…'),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else if (dashboardPrayerTimes == null &&
                        _prayerScheduleLoadError != null) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.cloud_off_outlined,
                                  color: Colors.orange, size: 30),
                              const SizedBox(height: 10),
                              const Text(
                                'Prayer schedule could not be loaded.',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(_prayerScheduleLoadError ??
                                  'Error loading prayer times.'),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () {
                                  final id = _masjidId;
                                  if (id != null) {
                                    _loadScheduleCalendar(id);
                                  }
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else if (dashboardPrayerTimes == null) ...[
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
                        child: dashboardPrayerTimes == null
                            ? const Text(
                                'No prayer times configured for today.',
                                style: TextStyle(color: Colors.grey))
                            : Column(
                                children: [
                                  _prayerRow(
                                      'Fajr',
                                      dashboardPrayerTimes['fajrAdhan'],
                                      dashboardPrayerTimes['fajrJamaah']),
                                  const Divider(),
                                  _prayerRow(
                                      'Dhuhr',
                                      dashboardPrayerTimes['dhuhrAdhan'],
                                      dashboardPrayerTimes['dhuhrJamaah']),
                                  const Divider(),
                                  _prayerRow(
                                      'Asr',
                                      dashboardPrayerTimes['asrAdhan'],
                                      dashboardPrayerTimes['asrJamaah']),
                                  const Divider(),
                                  _prayerRow(
                                      'Maghrib',
                                      dashboardPrayerTimes['maghribAdhan'],
                                      dashboardPrayerTimes['maghribJamaah']),
                                  const Divider(),
                                  _prayerRow(
                                      'Isha',
                                      dashboardPrayerTimes['ishaAdhan'],
                                      dashboardPrayerTimes['ishaJamaah']),
                                  if (dashboardPrayerTimes['jummahJamaah'] !=
                                      null) ...[
                                    const Divider(),
                                    _prayerRow(
                                        'Jummah',
                                        dashboardPrayerTimes['jummahKhutbah'],
                                        dashboardPrayerTimes['jummahJamaah']),
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
                        minimumSize: const Size(0, 44),
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
                        'Alhamdulillah! Masjid request submitted for review.'),
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
            _buildTimePickerInput(ctx, adhanCtrl, '$prayerName Adhan Time'),
            const SizedBox(height: 14),
            _buildTimePickerInput(ctx, jamaahCtrl, '$prayerName Jamaah Time',
                isRequired: true),
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
                  _dashboardPrayerTimes = {
                    ...?_dashboardPrayerTimes,
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
                          Text('Alhamdulillah! $prayerName timing updated to $jamaahVal.'),
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
    final times = _todayPrayerTimes;
    final bool hasPrayerTimes = times != null &&
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
        ].any((key) => times[key]?.toString().trim().isNotEmpty == true);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const AppLanguageText('Manage Prayer & Events',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _loadMasjidData),
        ],
      ),
      body: _masjidId == null
          ? _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : _buildNoMasjidAdminCard()
          : LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : MediaQuery.sizeOf(context).width;
                return RefreshIndicator(
                  onRefresh: _loadMasjidData,
                  color: AppColors.primary,
                  child: SizedBox(
                    width: availableWidth,
                    child: ListView(
                      key: PageStorageKey<String>(
                          'admin-prayer-events-$_masjidId'),
                      controller: _prayerTabScrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(
                                value: 0,
                                icon: Icon(Icons.schedule),
                                label: AppLanguageText('Prayers')),
                            ButtonSegment(
                                value: 1,
                                icon: Icon(Icons.event),
                                label: AppLanguageText('Events')),
                          ],
                          selected: {_prayerEventsTab},
                          onSelectionChanged: (selection) => setState(
                              () => _prayerEventsTab = selection.first),
                        ),
                        const SizedBox(height: 12),
                        if (_prayerDataError != null) ...[
                          Card(
                            color: Theme.of(context).colorScheme.errorContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.cloud_off_outlined,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Some prayer information could not be loaded',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onErrorContainer,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _prayerDataError ?? '',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onErrorContainer,
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton.icon(
                                            onPressed: _loadMasjidData,
                                            icon: const Icon(Icons.refresh),
                                            label: const Text('Retry'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.primary,
                              child: Icon(Icons.mosque, color: Colors.white),
                            ),
                            title: Text(
                              _masjidName ?? 'Masjid Prayer Schedule',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: const Text('Prayer timings and events'),
                            trailing: IconButton(
                              tooltip: 'Refresh prayer data',
                              onPressed: _loadMasjidData,
                              icon: const Icon(Icons.refresh),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_prayerEventsTab == 0 &&
                            !hasPrayerTimes &&
                            _isScheduleCalendarLoading) ...[
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(22),
                              child: Row(children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.primary,
                                  ),
                                ),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    'Loading saved prayer times for this month…',
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ] else if (_prayerEventsTab == 0 &&
                            !hasPrayerTimes &&
                            _prayerScheduleLoadError != null) ...[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(children: [
                                const Icon(Icons.cloud_off_outlined,
                                    color: Colors.orange, size: 36),
                                const SizedBox(height: 10),
                                Text(
                                    _prayerScheduleLoadError ??
                                        'Error loading prayer times.',
                                    textAlign: TextAlign.center),
                                const SizedBox(height: 8),
                                FilledButton.icon(
                                  onPressed: () {
                                    final id = _masjidId;
                                    if (id != null) _loadScheduleCalendar(id);
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry loading schedule'),
                                ),
                              ]),
                            ),
                          ),
                        ] else if (_prayerEventsTab == 0 &&
                            !hasPrayerTimes) ...[
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
                                      icon:
                                          const Icon(Icons.add_alarm, size: 22),
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
                                            color: AppColors.primary,
                                            width: 1.2),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      icon: const Icon(Icons.date_range,
                                          size: 20),
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
                        ] else if (_prayerEventsTab == 0) ...[
                          // 2. TIMINGS CONFIGURED: SHOW SAVED TIMINGS WITH EDIT OPTIONS
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  '${_calendarDateKey(_selectedScheduleDate)} Prayer Timings',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 36),
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
                                  side: const BorderSide(
                                      color: AppColors.primary)),
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
                                              fontSize: 12,
                                              color: Colors.grey)),
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
                        if (_prayerEventsTab == 1) ...[
                          _buildSelectedEventsPanel(),
                        ],
                        const SizedBox(height: 12),
                        _buildScheduleCalendar(),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildTimePickerInput(
      BuildContext ctx, TextEditingController ctrl, String label,
      {bool isRequired = false}) {
    return TextField(
      controller: ctrl,
      readOnly: true,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        labelStyle: const TextStyle(fontSize: 12),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        suffixIcon: IconButton(
          icon: const Icon(Icons.schedule, size: 18),
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

  Widget _buildDatePickerInput(
      BuildContext ctx, TextEditingController ctrl, String label,
      {bool optional = false, VoidCallback? onChanged}) {
    return TextField(
      controller: ctrl,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          if (optional && ctrl.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear date',
              icon: const Icon(Icons.close),
              onPressed: () {
                ctrl.clear();
                onChanged?.call();
              },
            ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.calendar_month_outlined),
          ),
        ]),
      ),
      onTap: () async {
        final parsed = DateTime.tryParse(ctrl.text);
        final picked = await showDatePicker(
          context: ctx,
          initialDate: parsed ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          ctrl.text = _calendarDateKey(picked);
          onChanged?.call();
        }
      },
    );
  }

  void _showFullPrayerTimesDialog() {
    final bool isCreating = _todayPrayerTimes == null ||
        _todayPrayerTimes!['fajrJamaah'] == null ||
        _todayPrayerTimes!['fajrJamaah'].toString().trim().isEmpty;

    final dateStr = _calendarDateKey(_selectedScheduleDate);
    DateTime startDate = DateTime.tryParse(
          _todayPrayerTimes?['startDate']?.toString() ?? '',
        ) ??
        _selectedScheduleDate;
    DateTime? endDate = DateTime.tryParse(
      _todayPrayerTimes?['endDate']?.toString() ?? '',
    );
    bool appliesUntilChanged =
        _todayPrayerTimes?['startDate'] != null && endDate == null;
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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
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
                  const Text('Schedule dates',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text('From ${_calendarDateKey(startDate)}'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: startDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              startDate = DateTime(
                                  picked.year, picked.month, picked.day);
                              if (endDate != null &&
                                  endDate!.isBefore(startDate)) {
                                endDate = startDate;
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ]),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('No end date'),
                    subtitle: const Text(
                        'Keep these times until a new schedule replaces them'),
                    value: appliesUntilChanged,
                    onChanged: (value) => setDialogState(() {
                      appliesUntilChanged = value;
                      if (!value && endDate == null) endDate = startDate;
                    }),
                  ),
                  if (!appliesUntilChanged)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event_outlined),
                        label: Text(
                            'Until ${_calendarDateKey(endDate ?? startDate)}'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: endDate ?? startDate,
                            firstDate: startDate,
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() => endDate = DateTime(
                                picked.year, picked.month, picked.day));
                          }
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 12),

                  // Solar Timings
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3)),
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
                          child: _buildTimePickerInput(
                              ctx, asrACtrl, 'Asr Adhan')),
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
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
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
                    if (dateStr == _calendarDateKey(DateTime.now())) {
                      _dashboardPrayerTimes = {
                        ...?_dashboardPrayerTimes,
                        ...payload,
                      };
                    }
                  });

                  payload['startDate'] = _calendarDateKey(startDate);
                  if (!appliesUntilChanged) {
                    payload['endDate'] = _calendarDateKey(endDate ?? startDate);
                  }
                  await ApiService.instance
                      .updatePrayerTimeRange(_masjidId!, payload);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isCreating
                            ? 'Alhamdulillah! Prayer schedule created successfully.'
                            : 'Alhamdulillah! Prayer schedule updated successfully.'),
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
      ),
    );
  }

  void _showDateRangePrayerDialog({DateTimeRange? initialRange}) {
    DateTime startDate = initialRange?.start ?? DateTime.now();
    DateTime endDate = initialRange?.end ?? startDate;
    final fajrJCtrl = TextEditingController();
    final dhuhrJCtrl = TextEditingController();
    final asrJCtrl = TextEditingController();
    final maghribJCtrl = TextEditingController();
    final ishaJCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Set Prayer Times Across Date Range'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text('From ${_calendarDateKey(startDate)}'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: startDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          startDate =
                              DateTime(picked.year, picked.month, picked.day);
                          if (endDate.isBefore(startDate)) endDate = startDate;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event_outlined),
                    label: Text('Until ${_calendarDateKey(endDate)}'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: endDate,
                        firstDate: startDate,
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => endDate =
                            DateTime(picked.year, picked.month, picked.day));
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
                _buildTimePickerInput(ctx, fajrJCtrl, 'Fajr Jamaah *',
                    isRequired: true),
                const SizedBox(height: 12),
                _buildTimePickerInput(ctx, dhuhrJCtrl, 'Dhuhr Jamaah *',
                    isRequired: true),
                const SizedBox(height: 12),
                _buildTimePickerInput(ctx, asrJCtrl, 'Asr Jamaah *',
                    isRequired: true),
                const SizedBox(height: 12),
                _buildTimePickerInput(ctx, maghribJCtrl, 'Maghrib Jamaah *',
                    isRequired: true),
                const SizedBox(height: 12),
                _buildTimePickerInput(ctx, ishaJCtrl, 'Isha Jamaah *',
                    isRequired: true),
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
                if (_masjidId == null) return;
                Navigator.pop(ctx);
                try {
                  await ApiService.instance.updatePrayerTimeRange(_masjidId!, {
                    'startDate': _calendarDateKey(startDate),
                    'endDate': _calendarDateKey(endDate),
                    'fajrJamaah': fajrJCtrl.text.trim(),
                    'dhuhrJamaah': dhuhrJCtrl.text.trim(),
                    'asrJamaah': asrJCtrl.text.trim(),
                    'maghribJamaah': maghribJCtrl.text.trim(),
                    'ishaJamaah': ishaJCtrl.text.trim(),
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Alhamdulillah! Date range schedule applied.')));
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
      ),
    );
  }

  void _showRamadanRangeDialog({required DateTimeRange initialRange}) {
    if (_masjidId == null) return;
    final sehri = TextEditingController();
    final iftar = TextEditingController();
    final notes = TextEditingController();
    final days = initialRange.end.difference(initialRange.start).inDays + 1;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set fasting times for selected dates'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
              '${_calendarDateKey(initialRange.start)} to ${_calendarDateKey(initialRange.end)} · $days days'),
          const SizedBox(height: 12),
          _buildTimePickerInput(dialogContext, sehri, 'Sehri ends *'),
          const SizedBox(height: 12),
          _buildTimePickerInput(dialogContext, iftar, 'Iftar *'),
          const SizedBox(height: 12),
          TextField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'Notes (optional)')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (days > 31 ||
                  sehri.text.trim().isEmpty ||
                  iftar.text.trim().isEmpty) return;
              Navigator.pop(dialogContext);
              try {
                final payload = <Map<String, dynamic>>[];
                for (var offset = 0; offset < days; offset++) {
                  final date = initialRange.start.add(Duration(days: offset));
                  payload.add({
                    'date': _calendarDateKey(date),
                    'sehriEnd': sehri.text.trim(),
                    'iftarTime': iftar.text.trim(),
                    if (notes.text.trim().isNotEmpty)
                      'notes': notes.text.trim(),
                  });
                }
                final id = _masjidId;
                if (id == null) return;
                await ApiService.instance.saveRamadanSchedule(id, payload);
                await _loadScheduleCalendar(id);
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text('Alhamdulillah! Fasting schedule saved for selected dates.')));
              } catch (error) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(ApiService.getErrorMessage(error))));
              }
            },
            child: const Text('Save range'),
          ),
        ],
      ),
    );
  }

  void _showAddSpecialEventDialog({
    Map<String, dynamic>? existing,
    String? startDate,
    String? endDate,
  }) {
    final id = existing?['id']?.toString();
    String selectedType = existing?['type']?.toString() ?? 'RAMZAN_TIMETABLE';
    final titleCtrl =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final startCtrl = TextEditingController(
        text: existing?['startDate']?.toString().split('T').first ??
            startDate ??
            _calendarDateKey(_selectedScheduleDate));
    final endDateCtrl = TextEditingController(
        text:
            existing?['endDate']?.toString().split('T').first ?? endDate ?? '');
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
                _buildDatePickerInput(ctx, startCtrl, 'Start Date *'),
                const SizedBox(height: 12),
                _buildDatePickerInput(ctx, endDateCtrl, 'End Date (optional)',
                    optional: true, onChanged: () => setDState(() {})),
                const SizedBox(height: 12),
                _buildTimePickerInput(ctx, timeCtrl, 'Start Time *',
                    isRequired: true),
                const SizedBox(height: 12),
                _buildTimePickerInput(ctx, endTimeCtrl, 'End Time (optional)'),
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
                          ? 'Alhamdulillah! Special event created.'
                          : 'Alhamdulillah! Special event updated.')));
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
        title: const AppLanguageText('Masjid Notice Board',
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
        content: Text('Alhamdulillah! Notice sent to connected members.'),
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
        title: const AppLanguageText('Manage Members & Roles',
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
                      content: Text('Alhamdulillah! Member added successfully.')));
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
                      const SnackBar(content: Text('Alhamdulillah! Role assigned.')));
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
  // TAB 3: Sandha Management Module
  // -------------------------------------------------------------
  Widget _buildSandhaTab() {
    if (_masjidId == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return SandhaManagementScreen(
      masjidId: _masjidId!,
      isEmbedded: true,
    );
  }

  // -------------------------------------------------------------
  // TAB 6: Masjid Profile & Settings
  // -------------------------------------------------------------
  Widget _buildProfileTab() {
    final nameCtrl = TextEditingController(text: _masjidDetails?['name'] ?? '');
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
        title: Consumer(
            builder: (context, ref, _) => Text(
                  ref
                      .read(languageProvider.notifier)
                      .text('Masjid Settings & Profile'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AppLanguageSettingsTile(),
          const Divider(height: 1),

          // Sandha Settings Tile (User requested: Sandha settings inside Settings)
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.payments_outlined,
                    color: AppColors.primary, size: 20),
              ),
              title: const Text('Sandha Settings',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: const Text(
                  'Configure monthly subscription plan, amount & UPI payment details',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                if (_masjidId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SandhaSettingsScreen(masjidId: _masjidId!),
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 12),
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
                                content: Text('Alhamdulillah! Masjid details updated.')));
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

  Widget _buildInactiveMasjidScreen() {
    final roles =
        (ApiService.instance.currentUser?['adminRoles'] as List<dynamic>?) ??
            [];
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mosque_outlined,
                      size: 46, color: Colors.deepOrange),
                ),
                const SizedBox(height: 20),
                const AppLanguageText(
                  'Masjid currently inactive',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Text(
                  _masjidName ?? 'Masjid',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                const AppLanguageText(
                  'This masjid is currently inactive. Admin tools and schedules are unavailable until a Super Admin reactivates it.',
                  style:
                      TextStyle(fontSize: 15, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                if (roles.length > 1) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _showSwitchAdminMasjidSheet,
                      icon: const Icon(Icons.swap_horiz),
                      label: const AppLanguageText('Switch Admin Masjid'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
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
                    icon: const Icon(Icons.home_outlined),
                    label: const AppLanguageText('Return to User App'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      ref.watch(languageProvider);
      final language = ref.read(languageProvider.notifier);
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: _isMasjidInactive
            ? _buildInactiveMasjidScreen()
            : switch (_currentIndex) {
                0 => _buildDashboardTab(),
                1 => _buildPrayerTimesTab(),
                2 => _buildSandhaTab(),
                3 => _buildAnnouncementsTab(),
                4 => _buildMembersTab(),
                _ => _buildProfileTab(),
              },
        bottomNavigationBar: _isMasjidInactive
            ? null
            : NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() => _currentIndex = index);
                  if (index == 1) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_prayerTabScrollController.hasClients) {
                        _prayerTabScrollController.jumpTo(0);
                      }
                    });
                  }
                },
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard_rounded),
                    label: language.text('Home'),
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.schedule_outlined),
                    selectedIcon: Icon(Icons.schedule_rounded),
                    label: language.text('Prayer'),
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.payments_outlined),
                    selectedIcon: Icon(Icons.payments_rounded),
                    label: language.text('Sandha'),
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.campaign_outlined),
                    selectedIcon: Icon(Icons.campaign_rounded),
                    label: language.text('Notices'),
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.people_outline),
                    selectedIcon: Icon(Icons.people_rounded),
                    label: language.text('Members'),
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings_rounded),
                    label: language.text('Settings'),
                  ),
                ],
              ),
      );
    });
  }
}
