import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:masjid_namaz_app/core/network/api_service.dart';
import 'package:masjid_namaz_app/features/prayer_times/data/local_prayer_times_service.dart';

class NextPrayerInfo {
  final String name;
  final String adhan;
  final String iqamah;
  final Duration timeUntilAdhan;
  final Duration timeUntilIqamah;

  NextPrayerInfo({
    required this.name,
    required this.adhan,
    required this.iqamah,
    required this.timeUntilAdhan,
    required this.timeUntilIqamah,
  });
}

class PrayerTimesState {
  final bool isLoading;
  final Map<String, dynamic>? times;
  final Map<String, dynamic>? activeMasjid;
  final NextPrayerInfo? nextPrayer;
  final String? error;
  final bool isLocalTimes;

  PrayerTimesState({
    this.isLoading = false,
    this.times,
    this.activeMasjid,
    this.nextPrayer,
    this.error,
    this.isLocalTimes = false,
  });

  PrayerTimesState copyWith({
    bool? isLoading,
    Map<String, dynamic>? times,
    Map<String, dynamic>? activeMasjid,
    NextPrayerInfo? nextPrayer,
    String? error,
    bool clearTimes = false,
    bool clearMasjid = false,
    bool clearNextPrayer = false,
    bool clearError = false,
    bool? isLocalTimes,
  }) {
    return PrayerTimesState(
      isLoading: isLoading ?? this.isLoading,
      times: clearTimes ? null : times ?? this.times,
      activeMasjid: clearMasjid ? null : activeMasjid ?? this.activeMasjid,
      nextPrayer: clearNextPrayer ? null : nextPrayer ?? this.nextPrayer,
      error: clearError ? null : error ?? this.error,
      isLocalTimes: isLocalTimes ?? this.isLocalTimes,
    );
  }
}

class PrayerTimesNotifier extends StateNotifier<PrayerTimesState> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Timer? _countdownTimer;

  static const String _cachedMasjidKey = 'cached_active_masjid_json';

  PrayerTimesNotifier() : super(PrayerTimesState(isLoading: true)) {
    _initFromStorageAndBackend();
  }

  Future<void> _initFromStorageAndBackend() async {
    // Restore only the last selected masjid while membership is revalidated.
    // Prayer rows are date-specific and must be fetched before display; reusing
    // yesterday's cached row made an unscheduled day look configured.
    try {
      await _storage.delete(key: 'cached_prayer_times_json');
      final cachedMasjidRaw = await _storage.read(key: _cachedMasjidKey);
      Map<String, dynamic>? cachedMasjid;
      if (cachedMasjidRaw != null) {
        cachedMasjid = jsonDecode(cachedMasjidRaw) as Map<String, dynamic>;
      }
      if (cachedMasjid != null) {
        state = state.copyWith(
          activeMasjid: cachedMasjid,
        );
      }
    } catch (e) {
      debugPrint('Error loading cached prayer times: $e');
    }

    // 2. Fetch fresh times from backend database
    await refreshFromBackend();
    _startTimer();
  }

  Future<void> refreshFromBackend({String? specificMasjidId}) async {
    try {
      // Use the authenticated user's masjids here. The public directory can be
      // large and must never be treated as the user's selected masjid.
      final masjids = await ApiService.instance.getMyMasjids();
      if (masjids.isEmpty) {
        await selectLocalTimes();
        return;
      }

      // Check if user has an explicitly connected / primary masjid
      final user = ApiService.instance.currentUser;
      final memberships = user?['memberships'] as List<dynamic>?;
      final primaryMembership = memberships?.firstWhere(
        (m) => m['isPrimary'] == true,
        orElse: () => memberships.isNotEmpty ? memberships.first : null,
      );

      final String? primaryId = user?['primaryMasjidId']?.toString() ??
          primaryMembership?['masjidId']?.toString();
      final userMasjids = masjids.whereType<Map<String, dynamic>>().toList();
      final availableIds = userMasjids
          .map((masjid) => masjid['id']?.toString())
          .whereType<String>()
          .toSet();
      final cachedId = state.activeMasjid?['id']?.toString();
      final cachedIsJoined =
          cachedId != null && availableIds.contains(cachedId);
      final primaryMasjids =
          userMasjids.where((m) => m['isPrimary'] == true).toList();
      final defaultMasjid = primaryMasjids.isNotEmpty
          ? primaryMasjids.first
          : (userMasjids.isNotEmpty ? userMasjids.first : null);
      final String? targetId = state.isLocalTimes && specificMasjidId == null
          ? null
          : specificMasjidId ??
              (availableIds.contains(primaryId) ? primaryId : null) ??
              (cachedIsJoined ? cachedId : null) ??
              defaultMasjid?['id']?.toString();

      // Never keep a previous masjid's cached schedule on screen while a new
      // selection is being resolved. This also prevents old values briefly
      // appearing after an admin switches accounts or masjids.
      if (targetId != cachedId) {
        state = state.copyWith(
          clearTimes: true,
          clearNextPrayer: true,
          isLoading: true,
        );
      }
      final now = DateTime.now();
      final localDate =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final cachedDate = state.times?['date']?.toString().split('T').first;
      if (cachedDate != null && cachedDate != localDate) {
        state = state.copyWith(clearTimes: true, clearNextPrayer: true);
      }

      // Do NOT auto-link to masjids.first! User must search or scan QR code.
      if (targetId == null) {
        await selectLocalTimes();
        return;
      }

      final targetMasjid = userMasjids.firstWhere(
        (m) => m['id'] == targetId,
        orElse: () => <String, dynamic>{},
      );

      if (targetMasjid.isEmpty) {
        state = state.copyWith(
          activeMasjid: null,
          times: null,
          nextPrayer: null,
          isLoading: false,
          clearMasjid: true,
          clearTimes: true,
          clearNextPrayer: true,
        );
        return;
      }

      // Fetch today's prayer times for this masjid from backend
      final backendTimes =
          await ApiService.instance.getTodayPrayerTimes(targetMasjid['id']);

      if (backendTimes != null) {
        await _storage.write(
            key: _cachedMasjidKey, value: jsonEncode(targetMasjid));

        state = state.copyWith(
          times: backendTimes,
          activeMasjid: targetMasjid,
          isLoading: false,
          error: null,
          isLocalTimes: false,
        );
        _recalculateNextPrayer();
      } else {
        state = state.copyWith(
          activeMasjid: targetMasjid,
          isLoading: false,
          clearTimes: true,
          clearNextPrayer: true,
          isLocalTimes: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        clearTimes: true,
        clearNextPrayer: true,
        error: 'Backend sync note: $e',
      );
    }
  }

  Future<void> switchMasjid(Map<String, dynamic> newMasjid) async {
    state = state.copyWith(
      isLoading: true,
      activeMasjid: newMasjid,
      clearTimes: true,
      clearNextPrayer: true,
      clearError: true,
      isLocalTimes: false,
    );
    await refreshFromBackend(specificMasjidId: newMasjid['id']);
  }

  Future<void> selectLocalTimes({int school = 1}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Allow location access to show local prayer times.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      final today = DateTime.now().toIso8601String().split('T').first;
      Map<String, dynamic>? cachedTimes;
      final cachedRaw =
          await _storage.read(key: 'cached_local_prayer_times_json');
      final cachedDate = await _storage.read(key: 'cached_local_prayer_date');
      final cachedSchool =
          await _storage.read(key: 'cached_local_prayer_school');
      final cachedLat = double.tryParse(
          (await _storage.read(key: 'cached_local_prayer_lat')) ?? '');
      final cachedLng = double.tryParse(
          (await _storage.read(key: 'cached_local_prayer_lng')) ?? '');
      final sameLocation = cachedLat != null &&
          cachedLng != null &&
          (cachedLat - position.latitude).abs() < 0.02 &&
          (cachedLng - position.longitude).abs() < 0.02;
      if (cachedRaw != null &&
          cachedDate == today &&
          sameLocation &&
          cachedSchool == school.toString()) {
        cachedTimes = jsonDecode(cachedRaw) as Map<String, dynamic>;
        state = state.copyWith(
          times: cachedTimes,
          clearMasjid: true,
          isLocalTimes: true,
          isLoading: false,
          clearError: true,
        );
        _recalculateNextPrayer();
      }
      final times = await LocalPrayerTimesService.fetchDaily(
        latitude: position.latitude,
        longitude: position.longitude,
        school: school,
      );
      times['latitude'] = position.latitude;
      times['longitude'] = position.longitude;
      await _storage.write(
          key: 'cached_local_prayer_times_json', value: jsonEncode(times));
      await _storage.write(
          key: 'cached_local_prayer_date', value: times['date']?.toString());
      await _storage.write(
          key: 'cached_local_prayer_school', value: school.toString());
      await _storage.write(
          key: 'cached_local_prayer_lat', value: position.latitude.toString());
      await _storage.write(
          key: 'cached_local_prayer_lng', value: position.longitude.toString());
      state = state.copyWith(
        times: times,
        clearMasjid: true,
        isLocalTimes: true,
        isLoading: false,
        clearError: true,
      );
      _recalculateNextPrayer();
    } catch (e) {
      final cachedRaw =
          await _storage.read(key: 'cached_local_prayer_times_json');
      final cachedDate = await _storage.read(key: 'cached_local_prayer_date');
      final cachedSchool =
          await _storage.read(key: 'cached_local_prayer_school');
      if (cachedRaw != null &&
          cachedDate == DateTime.now().toIso8601String().split('T').first &&
          cachedSchool == school.toString()) {
        final cachedTimes = jsonDecode(cachedRaw) as Map<String, dynamic>;
        state = state.copyWith(
          times: cachedTimes,
          clearMasjid: true,
          clearNextPrayer: true,
          isLocalTimes: true,
          isLoading: false,
          error:
              'Showing saved local prayer times. Refresh when you are online.',
        );
        _recalculateNextPrayer();
        return;
      }
      state = state.copyWith(
        isLoading: false,
        clearMasjid: true,
        clearTimes: true,
        clearNextPrayer: true,
        isLocalTimes: true,
        error: e.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _recalculateNextPrayer();
    });
  }

  void _recalculateNextPrayer() {
    final times = state.times;
    if (times == null) return;

    final now = DateTime.now();

    DateTime? parseTime(String? timeStr) {
      if (timeStr == null || timeStr.isEmpty) {
        return null;
      }
      final clean = timeStr.replaceAll(RegExp(r'[^\d:]'), '');
      final parts = clean.split(':');
      if (parts.length >= 2) {
        int? h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h == null || m == null) return null;
        if (timeStr.toUpperCase().contains('PM') && h < 12) h += 12;
        if (timeStr.toUpperCase().contains('AM') && h == 12) h = 0;
        return DateTime(now.year, now.month, now.day, h, m);
      }
      return null;
    }

    final prayers = <({String name, String adhanKey, String jamaahKey})>[
      (name: 'Fajr', adhanKey: 'fajrAdhan', jamaahKey: 'fajrJamaah'),
      (
        name: now.weekday == DateTime.friday ? "Jumu'ah" : 'Dhuhr',
        adhanKey: 'dhuhrAdhan',
        jamaahKey: 'dhuhrJamaah'
      ),
      (name: 'Asr', adhanKey: 'asrAdhan', jamaahKey: 'asrJamaah'),
      (name: 'Maghrib', adhanKey: 'maghribAdhan', jamaahKey: 'maghribJamaah'),
      (name: 'Isha', adhanKey: 'ishaAdhan', jamaahKey: 'ishaJamaah'),
    ];
    final upcoming = prayers
        .map((p) => (prayer: p, time: parseTime(times[p.adhanKey]?.toString())))
        .where((p) => p.time != null)
        .map((p) => (prayer: p.prayer, time: p.time!))
        .where((p) => p.time.isAfter(now))
        .toList();
    if (upcoming.isEmpty) {
      final firstPrayer = prayers.first;
      final tomorrowFajr = parseTime(times[firstPrayer.adhanKey]?.toString());
      if (tomorrowFajr == null) {
        state = state.copyWith(clearNextPrayer: true);
        return;
      }
      final tomorrowIqamah =
          parseTime(times[firstPrayer.jamaahKey]?.toString());
      final nextDayAdhan = tomorrowFajr.add(const Duration(days: 1));
      final nextDayIqamah = tomorrowIqamah?.add(const Duration(days: 1));
      state = state.copyWith(
        nextPrayer: NextPrayerInfo(
          name: firstPrayer.name,
          adhan: times[firstPrayer.adhanKey]?.toString() ?? '',
          iqamah: times[firstPrayer.jamaahKey]?.toString() ?? '',
          timeUntilAdhan: nextDayAdhan.difference(now),
          timeUntilIqamah: nextDayIqamah != null && nextDayIqamah.isAfter(now)
              ? nextDayIqamah.difference(now)
              : Duration.zero,
        ),
      );
      return;
    }
    final next = upcoming.first;
    final iqamah = parseTime(times[next.prayer.jamaahKey]?.toString());

    state = state.copyWith(
      nextPrayer: NextPrayerInfo(
        name: next.prayer.name,
        adhan: times[next.prayer.adhanKey]?.toString() ?? '',
        iqamah: times[next.prayer.jamaahKey]?.toString() ?? '',
        timeUntilAdhan: next.time.difference(now),
        timeUntilIqamah: iqamah?.isAfter(now) == true
            ? iqamah!.difference(now)
            : Duration.zero,
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}

final prayerTimesProvider =
    StateNotifierProvider<PrayerTimesNotifier, PrayerTimesState>((ref) {
  return PrayerTimesNotifier();
});
