import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:masjid_namaz_app/core/network/api_service.dart';

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

  PrayerTimesState({
    this.isLoading = false,
    this.times,
    this.activeMasjid,
    this.nextPrayer,
    this.error,
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
  }) {
    return PrayerTimesState(
      isLoading: isLoading ?? this.isLoading,
      times: clearTimes ? null : times ?? this.times,
      activeMasjid: clearMasjid ? null : activeMasjid ?? this.activeMasjid,
      nextPrayer: clearNextPrayer ? null : nextPrayer ?? this.nextPrayer,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class PrayerTimesNotifier extends StateNotifier<PrayerTimesState> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Timer? _countdownTimer;

  static const String _cachedTimesKey = 'cached_prayer_times_json';
  static const String _cachedMasjidKey = 'cached_active_masjid_json';

  PrayerTimesNotifier() : super(PrayerTimesState(isLoading: true)) {
    _initFromStorageAndBackend();
  }

  Future<void> _initFromStorageAndBackend() async {
    // 1. Immediately load maintained state from local storage (offline first)
    try {
      final cachedTimesRaw = await _storage.read(key: _cachedTimesKey);
      final cachedMasjidRaw = await _storage.read(key: _cachedMasjidKey);

      Map<String, dynamic>? cachedTimes;
      Map<String, dynamic>? cachedMasjid;

      if (cachedTimesRaw != null) {
        cachedTimes = jsonDecode(cachedTimesRaw) as Map<String, dynamic>;
      }
      if (cachedMasjidRaw != null) {
        cachedMasjid = jsonDecode(cachedMasjidRaw) as Map<String, dynamic>;
      }

      if (cachedTimes != null) {
        state = state.copyWith(
          times: cachedTimes,
          activeMasjid: cachedMasjid,
          isLoading: false,
        );
        _recalculateNextPrayer();
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
        state = state.copyWith(
          isLoading: false,
          clearMasjid: true,
          clearTimes: true,
          clearNextPrayer: true,
        );
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
      final String? targetId = specificMasjidId ??
          (availableIds.contains(primaryId) ? primaryId : null) ??
          (cachedIsJoined ? cachedId : null) ??
          defaultMasjid?['id']?.toString();

      // Do NOT auto-link to masjids.first! User must search or scan QR code.
      if (targetId == null) {
        state = state.copyWith(
          activeMasjid: null,
          times: null,
          nextPrayer: null,
          isLoading: false,
          clearMasjid: true,
          clearTimes: true,
          clearNextPrayer: true,
          clearError: true,
        );
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
        // Persist fresh backend data to storage
        await _storage.write(
            key: _cachedTimesKey, value: jsonEncode(backendTimes));
        await _storage.write(
            key: _cachedMasjidKey, value: jsonEncode(targetMasjid));

        state = state.copyWith(
          times: backendTimes,
          activeMasjid: targetMasjid,
          isLoading: false,
          error: null,
        );
        _recalculateNextPrayer();
      } else {
        state = state.copyWith(
          activeMasjid: targetMasjid,
          isLoading: false,
          clearTimes: true,
          clearNextPrayer: true,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Backend sync note: $e',
      );
    }
  }

  Future<void> switchMasjid(Map<String, dynamic> newMasjid) async {
    state = state.copyWith(isLoading: true, activeMasjid: newMasjid);
    await refreshFromBackend(specificMasjidId: newMasjid['id']);
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

    DateTime parseTime(String? timeStr, int fallbackHour, int fallbackMin) {
      if (timeStr == null || timeStr.isEmpty) {
        return DateTime(
            now.year, now.month, now.day, fallbackHour, fallbackMin);
      }
      final clean = timeStr.replaceAll(RegExp(r'[^\d:]'), '');
      final parts = clean.split(':');
      if (parts.length >= 2) {
        int h = int.tryParse(parts[0]) ?? fallbackHour;
        final m = int.tryParse(parts[1]) ?? fallbackMin;
        if (timeStr.toUpperCase().contains('PM') && h < 12) h += 12;
        if (timeStr.toUpperCase().contains('AM') && h == 12) h = 0;
        // 24hr format handling
        if (!timeStr.toUpperCase().contains('AM') &&
            !timeStr.toUpperCase().contains('PM')) {
          if (fallbackHour >= 12 && h < 12) h += 12;
        }
        return DateTime(now.year, now.month, now.day, h, m);
      }
      return DateTime(now.year, now.month, now.day, fallbackHour, fallbackMin);
    }

    final fajrAdhan = parseTime(times['fajrAdhan'], 5, 0);
    final fajrIqamah = parseTime(times['fajrJamaah'], 5, 15);

    final dhuhrAdhan = parseTime(times['dhuhrAdhan'], 12, 30);
    final dhuhrIqamah = parseTime(times['dhuhrJamaah'], 12, 45);

    final asrAdhan = parseTime(times['asrAdhan'], 16, 30);
    final asrIqamah = parseTime(times['asrJamaah'], 16, 45);

    final maghribAdhan = parseTime(times['maghribAdhan'], 18, 0);
    final maghribIqamah = parseTime(times['maghribJamaah'], 18, 10);

    final ishaAdhan = parseTime(times['ishaAdhan'], 19, 30);
    final ishaIqamah = parseTime(times['ishaJamaah'], 19, 45);

    DateTime nextAdhanTarget;
    DateTime nextIqamahTarget;
    String name;
    String adhanStr;
    String iqamahStr;

    if (now.isBefore(fajrAdhan)) {
      nextAdhanTarget = fajrAdhan;
      nextIqamahTarget = fajrIqamah;
      name = 'Fajr';
      adhanStr = times['fajrAdhan'] ?? 'Fajr';
      iqamahStr = times['fajrJamaah'] ?? 'Fajr';
    } else if (now.isBefore(dhuhrAdhan)) {
      nextAdhanTarget = dhuhrAdhan;
      nextIqamahTarget = dhuhrIqamah;
      name = now.weekday == DateTime.friday ? 'Jumu\'ah' : 'Dhuhr';
      adhanStr = times['dhuhrAdhan'] ?? 'Dhuhr';
      iqamahStr = times['dhuhrJamaah'] ?? 'Dhuhr';
    } else if (now.isBefore(asrAdhan)) {
      nextAdhanTarget = asrAdhan;
      nextIqamahTarget = asrIqamah;
      name = 'Asr';
      adhanStr = times['asrAdhan'] ?? 'Asr';
      iqamahStr = times['asrJamaah'] ?? 'Asr';
    } else if (now.isBefore(maghribAdhan)) {
      nextAdhanTarget = maghribAdhan;
      nextIqamahTarget = maghribIqamah;
      name = 'Maghrib';
      adhanStr = times['maghribAdhan'] ?? 'Maghrib';
      iqamahStr = times['maghribJamaah'] ?? 'Maghrib';
    } else if (now.isBefore(ishaAdhan)) {
      nextAdhanTarget = ishaAdhan;
      nextIqamahTarget = ishaIqamah;
      name = 'Isha';
      adhanStr = times['ishaAdhan'] ?? 'Isha';
      iqamahStr = times['ishaJamaah'] ?? 'Isha';
    } else {
      nextAdhanTarget = fajrAdhan.add(const Duration(days: 1));
      nextIqamahTarget = fajrIqamah.add(const Duration(days: 1));
      name = 'Fajr';
      adhanStr = times['fajrAdhan'] ?? 'Fajr';
      iqamahStr = times['fajrJamaah'] ?? 'Fajr';
    }

    final diffAdhan = nextAdhanTarget.difference(now);
    final diffIqamah = nextIqamahTarget.difference(now);

    state = state.copyWith(
      nextPrayer: NextPrayerInfo(
        name: name,
        adhan: adhanStr,
        iqamah: iqamahStr,
        timeUntilAdhan: diffAdhan.isNegative ? Duration.zero : diffAdhan,
        timeUntilIqamah: diffIqamah.isNegative ? Duration.zero : diffIqamah,
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
