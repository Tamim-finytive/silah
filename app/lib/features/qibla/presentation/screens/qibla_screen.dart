import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass_v2/flutter_compass_v2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:masjid_namaz_app/core/constants/app_colors.dart';
import 'package:masjid_namaz_app/core/l10n/language_provider.dart';
import 'package:masjid_namaz_app/features/prayer_times/data/prayer_times_provider.dart';

class QiblaScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const QiblaScreen({super.key, this.onBack});

  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends ConsumerState<QiblaScreen> {
  // Kaaba (Makkah) exact GPS coordinates
  static const double kaabaLat = 21.422487;
  static const double kaabaLng = 39.826206;

  double _qiblaBearing = 0;
  double _distanceKm = 0;
  String _userCity = '';
  bool _hasValidLocation = false;
  double _magneticDeclination = 0;

  double? _heading;
  bool _hasCompassSensor = true;
  bool _isDetecting = false;
  StreamSubscription? _compassSub;
  bool _hasHapticFired = false;

  @override
  void initState() {
    super.initState();
    _initLocationAndCompass();
  }

  Future<void> _initLocationAndCompass() async {
    await _initLocationAndQibla();
    _startCompassListener();
  }

  Future<void> _initLocationAndQibla() async {
    try {
      // 1. Check & request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      double? lat;
      double? lng;

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position? pos;
        try {
          pos = await Geolocator.getLastKnownPosition();
          pos ??= await Geolocator.getCurrentPosition();
        } catch (_) {}

        if (pos != null) {
          lat = pos.latitude;
          lng = pos.longitude;
        }
      }

      // 2. Fallback to active masjid coordinates if GPS not acquired
      if (lat == null || lng == null) {
        final activeMasjid = ref.read(prayerTimesProvider).activeMasjid;
        if (activeMasjid != null) {
          lat = double.tryParse(activeMasjid['latitude']?.toString() ?? '');
          lng = double.tryParse(activeMasjid['longitude']?.toString() ?? '');
          if (activeMasjid['city'] != null) {
            _userCity = activeMasjid['city'].toString();
          }
        }
      }

      if (lat == null || lng == null) {
        if (mounted) setState(() => _hasValidLocation = false);
        return;
      }

      // 4. Compute exact Qibla bearing & distance
      final bearing = _calculateQiblaBearing(lat, lng);
      final dist = _calculateDistance(lat, lng, kaabaLat, kaabaLng);
      double declination = 0;
      try {
        declination =
            await const MethodChannel('silah/compass').invokeMethod<double>(
                  'magneticDeclination',
                  {'latitude': lat, 'longitude': lng},
                ) ??
                0;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _qiblaBearing = bearing;
          _distanceKm = dist;
          _magneticDeclination = declination;
          _hasValidLocation = true;
          if (_userCity.isEmpty) _userCity = 'Your current location';
        });
      }
    } catch (_) {}
  }

  // Great-Circle initial forward azimuth formula to Kaaba
  double _calculateQiblaBearing(double userLat, double userLng) {
    final phi1 = userLat * math.pi / 180.0;
    const phi2 = kaabaLat * math.pi / 180.0;
    final deltaLambda = (kaabaLng - userLng) * math.pi / 180.0;

    final y = math.sin(deltaLambda);
    final x = math.cos(phi1) * math.tan(phi2) -
        math.sin(phi1) * math.cos(deltaLambda);

    final qibla = math.atan2(y, x) * 180.0 / math.pi;
    return (qibla + 360.0) % 360.0;
  }

  // Haversine distance formula in kilometers
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371.0; // Earth radius in km
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  void _startCompassListener() {
    try {
      _compassSub?.cancel();
      _compassSub = FlutterCompass.events?.listen(
        (CompassEvent event) {
          if (!mounted) return;
          final heading = event.heading;
          if (heading != null) {
            // Normalize heading between 0 and 360
            final normalized =
                ((heading + _magneticDeclination) % 360.0 + 360.0) % 360.0;
            setState(() {
              _heading = normalized;
              _hasCompassSensor = true;
            });

            // Check if facing Qibla within ±5 degrees
            double diff = (_qiblaBearing - normalized);
            while (diff > 180) {
              diff -= 360;
            }
            while (diff < -180) {
              diff += 360;
            }

            if (diff.abs() <= 5.0) {
              if (!_hasHapticFired) {
                HapticFeedback.mediumImpact();
                _hasHapticFired = true;
              }
            } else {
              _hasHapticFired = false;
            }
          }
        },
        onError: (_) {
          if (mounted) setState(() => _hasCompassSensor = false);
        },
      );
    } catch (_) {
      if (mounted) setState(() => _hasCompassSensor = false);
    }
  }

  Future<void> _detectAndPointToQibla() async {
    setState(() => _isDetecting = true);
    HapticFeedback.selectionClick();
    var readingTimedOut = false;

    try {
      // Reuse the current location and live compass stream. Only request
      // location again when the screen does not already have a valid fix.
      if (!_hasValidLocation) await _initLocationAndQibla();
      if (!_hasValidLocation) {
        if (mounted) {
          setState(() => _isDetecting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Location is required to find Qibla.')),
          );
        }
        return;
      }

      // Read the current sensor value without asking the user to rotate the phone.
      final event = await FlutterCompass.events?.first
          .timeout(const Duration(seconds: 2));

      final rawHeading = event?.heading;
      if (rawHeading != null) {
        final normalized =
            ((rawHeading + _magneticDeclination) % 360.0 + 360.0) % 360.0;
        if (mounted) {
          setState(() {
            _heading = normalized;
            _hasCompassSensor = true;
          });
        }
      }
    } on TimeoutException {
      readingTimedOut = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Compass reading is unavailable right now.')),
        );
      }
    } catch (_) {
      // Keep the continuously updated heading when a one-time read fails.
    } finally {
      if (mounted) setState(() => _isDetecting = false);
    }

    if (!mounted || readingTimedOut) return;
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'The arrow is showing Qibla from your current phone direction.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    super.dispose();
  }

  String _getCardinalDirection(double angle) {
    if (angle >= 337.5 || angle < 22.5) return 'N';
    if (angle >= 22.5 && angle < 67.5) return 'NE';
    if (angle >= 67.5 && angle < 112.5) return 'E';
    if (angle >= 112.5 && angle < 157.5) return 'SE';
    if (angle >= 157.5 && angle < 202.5) return 'S';
    if (angle >= 202.5 && angle < 247.5) return 'SW';
    if (angle >= 247.5 && angle < 292.5) return 'W';
    return 'NW';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final lang = ref.read(languageProvider.notifier);
    final phoneHeading = _heading ?? 0.0;
    var diff = (_qiblaBearing - phoneHeading);
    while (diff > 180) {
      diff -= 360;
    }
    while (diff < -180) {
      diff += 360;
    }

    final isFacingQibla =
        _hasValidLocation && _heading != null && diff.abs() <= 5.0;
    final qiblaCardinal = _getCardinalDirection(_qiblaBearing);
    final phoneCardinal = _getCardinalDirection(phoneHeading);
    final int? alignment = _hasValidLocation && _heading != null
        ? ((180 - diff.abs()) / 180 * 100).round()
        : null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: (widget.onBack != null || Navigator.canPop(context))
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
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
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(lang.tr(en: 'Qibla Direction', ta: 'கிப்லா திசை'),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            const Text('MAKKAH AL-MUKARRAMAH • اتجاه القبلة',
                style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 0.45,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton.filledTonal(
              tooltip: 'Refresh location',
              onPressed: _isDetecting
                  ? null
                  : () async {
                      await _detectAndPointToQibla();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_hasValidLocation
                              ? 'Qibla updated for $_userCity'
                              : 'Location unavailable. Allow location access or connect a masjid with coordinates.'),
                        ),
                      );
                    },
              icon: _isDetecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final dialSize = math
                .min(420.0, math.max(180.0, constraints.maxWidth - 32))
                .toDouble();
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _QiblaSummaryCard(
                        bearing: _qiblaBearing,
                        cardinal: qiblaCardinal,
                        distanceKm: _distanceKm,
                        location: _userCity,
                        hasLocation: _hasValidLocation,
                        isAligned: isFacingQibla,
                      ),
                      const SizedBox(height: 8),
                      _QiblaTurnCard(
                        hasLocation: _hasValidLocation,
                        hasHeading: _heading != null,
                        isAligned: isFacingQibla,
                        difference: diff,
                        phoneHeading: phoneHeading,
                        phoneCardinal: phoneCardinal,
                        alignment: alignment,
                        language: lang,
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: SizedBox(
                          width: dialSize,
                          height: dialSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.rotate(
                                angle: -phoneHeading * (math.pi / 180),
                                child: Container(
                                  width: dialSize * .96,
                                  height: dialSize * .96,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceCard,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.secondary
                                          .withValues(alpha: .65),
                                      width: 1.4,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary
                                            .withValues(alpha: .10),
                                        blurRadius: 26,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CustomPaint(
                                        size: Size.square(dialSize * .96),
                                        painter: _CompassTicksPainter(
                                            color: AppColors.primary),
                                      ),
                                      const _CompassLabel(
                                          alignment: Alignment.topCenter,
                                          padding: EdgeInsets.only(top: 16),
                                          label: 'N',
                                          color: AppColors.emergency),
                                      const _CompassLabel(
                                          alignment: Alignment.bottomCenter,
                                          padding: EdgeInsets.only(bottom: 16),
                                          label: 'S'),
                                      const _CompassLabel(
                                          alignment: Alignment.centerLeft,
                                          padding: EdgeInsets.only(left: 16),
                                          label: 'W'),
                                      const _CompassLabel(
                                          alignment: Alignment.centerRight,
                                          padding: EdgeInsets.only(right: 16),
                                          label: 'E'),
                                      if (_hasValidLocation)
                                        Transform.rotate(
                                          angle:
                                              _qiblaBearing * (math.pi / 180),
                                          child: Align(
                                            alignment: Alignment.topCenter,
                                            //  child: Container(
                                            //    margin: EdgeInsets.only(
                                            //        top: dialSize * .105),
                                            //    padding: const EdgeInsets.all(6),
                                            //    decoration: BoxDecoration(
                                            //      color: AppColors.primary,
                                            //      shape: BoxShape.circle,
                                            //      border: Border.all(
                                            //         color: AppColors.secondary,
                                            //         width: 2),
                                            //    ),
                                            //    child: const Icon(Icons.mosque,
                                            //        color: Colors.white,
                                            //        size: 16),
                                            //  ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_hasValidLocation && _heading != null)
                                Transform.rotate(
                                  angle: diff * (math.pi / 180),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: isFacingQibla
                                              ? AppColors.success
                                              : AppColors.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: AppColors.secondary,
                                              width: 2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withValues(alpha: .24),
                                              blurRadius: 10,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.mosque_sharp,
                                            color: Colors.white, size: 23),
                                      ),
                                      Container(
                                        width: 4,
                                        height: dialSize * .35,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              AppColors.primary,
                                              AppColors.secondary
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                      ),
                                      SizedBox(height: dialSize * .25),
                                    ],
                                  ),
                                )
                              else
                                Icon(Icons.location_off_rounded,
                                    color: AppColors.warning,
                                    size: dialSize * .14),
                              Container(
                                width: 82,
                                height: 82,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceCard,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.secondary, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary
                                          .withValues(alpha: .08),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                        _hasValidLocation
                                            ? '${_qiblaBearing.round()}°'
                                            : '—',
                                        style: const TextStyle(
                                            fontSize: 20,
                                            height: 1.05,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary)),
                                    const SizedBox(height: 3),
                                    const Text('KAABA',
                                        style: TextStyle(
                                            fontSize: 9,
                                            letterSpacing: 1.3,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 11),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _hasCompassSensor
                                  ? Icons.sensors_rounded
                                  : Icons.sensors_off_rounded,
                              color: _hasCompassSensor
                                  ? AppColors.success
                                  : AppColors.warning,
                              size: 18,
                            ),
                            // const SizedBox(width: 8),
                            // Flexible(
                            //   child: Text(
                            //     !_hasCompassSensor
                            //         ? 'Compass sensor unavailable'
                            //         : _heading == null
                            //            ? 'Waiting for compass reading'
                            //            : 'True north • Compass sensor active',
                            //     textAlign: TextAlign.center,
                            //     style: const TextStyle(
                            //         fontSize: 12,
                            //         fontWeight: FontWeight.w600,
                            //         color: AppColors.textSecondary),
                            //   ),
                            // ),
                          ],
                        ),
                      ),

                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _QiblaSummaryCard extends StatelessWidget {
  final double bearing;
  final String cardinal;
  final double distanceKm;
  final String location;
  final bool hasLocation;
  final bool isAligned;

  const _QiblaSummaryCard({
    required this.bearing,
    required this.cardinal,
    required this.distanceKm,
    required this.location,
    required this.hasLocation,
    required this.isAligned,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: .35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.secondary.withValues(alpha: .8)),
                ),
                child: const Icon(Icons.mosque_rounded,
                    color: AppColors.secondary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text(hasLocation ? '${bearing.round()}°' : '—',
                            style: const TextStyle(
                                fontSize: 26,
                                height: 1,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary)),
                        if (hasLocation)
                          Text(cardinal,
                              style: const TextStyle(
                                  fontSize: 12,
                                  letterSpacing: 1.1,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.success)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                        hasLocation
                            ? 'Exact bearing to Kaaba'
                            : 'Allow location to calculate bearing',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                      hasLocation ? '${distanceKm.toStringAsFixed(0)} km' : '—',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  const Text('to Makkah',
                      style:
                          TextStyle(fontSize: 10, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isAligned ? Icons.check_circle_rounded : Icons.place_rounded,
                size: 14,
                color: hasLocation ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  hasLocation ? location : 'Location is needed for direction',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary),
                ),
              ),
              _QiblaPill(
                label: hasLocation
                    ? (isAligned ? 'ALIGNED' : 'LOCATION READY')
                    : 'NEEDS LOCATION',
                color: hasLocation
                    ? (isAligned ? AppColors.success : AppColors.primary)
                    : AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QiblaTurnCard extends StatelessWidget {
  final bool hasLocation;
  final bool hasHeading;
  final bool isAligned;
  final double difference;
  final double phoneHeading;
  final String phoneCardinal;
  final int? alignment;
  final LanguageNotifier language;

  const _QiblaTurnCard({
    required this.hasLocation,
    required this.hasHeading,
    required this.isAligned,
    required this.difference,
    required this.phoneHeading,
    required this.phoneCardinal,
    required this.alignment,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    final turnRight = difference > 0;
    final turn = difference.abs().round();
    final String instruction = !hasLocation
        ? language.tr(
            en: 'Allow location to find Qibla',
            ta: 'கிப்லா திசையைக் கண்டறிய இடத்தை அனுமதிக்கவும்')
        : !hasHeading
            ? language.tr(
                en: 'Waiting for compass reading',
                ta: 'திசைகாட்டி அளவீட்டுக்காக காத்திருக்கிறது')
            : isAligned
                ? language.tr(
                    en: 'You are facing the Kaaba',
                    ta: 'நீங்கள் கஅபாவை நோக்கி இருக்கிறீர்கள்')
                : language.tr(
                    en: 'Turn ${turnRight ? 'right' : 'left'} $turn° to face Kaaba',
                    ta: '${turnRight ? 'வலது' : 'இடது'} பக்கம் $turn° திரும்பவும்');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                    color: AppColors.secondary, shape: BoxShape.circle),
                child: Icon(
                  !hasLocation
                      ? Icons.location_off_rounded
                      : !hasHeading
                          ? Icons.sensors_rounded
                          : isAligned
                              ? Icons.check_rounded
                              : (turnRight
                                  ? Icons.turn_right_rounded
                                  : Icons.turn_left_rounded),
                  color: AppColors.onSecondary,
                  size: 17,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  instruction,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 6),
              if (hasHeading)
                _QiblaPill(
                  label: 'PHONE ${phoneHeading.round()}° $phoneCardinal',
                  color: AppColors.secondary,
                  darkText: true,
                ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Alignment',
                  style: TextStyle(color: Colors.white70, fontSize: 10)),
              Text(alignment == null ? 'Waiting…' : '$alignment% aligned',
                  style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: alignment == null ? 0 : alignment! / 100,
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: .18),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.secondary),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            language.tr(
              en: 'Keep your phone level. The arrow follows your direction.',
              ta: 'கைப்பேசியை நேராகப் பிடிக்கவும். அம்பு திசைக்கு ஏற்ப நகரும்.',
            ),
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _QiblaPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool darkText;

  const _QiblaPill({
    required this.label,
    required this.color,
    this.darkText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: darkText ? .18 : .10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .55)),
      ),
      child: Text(label,
          style: TextStyle(
              color: darkText ? AppColors.secondary : color,
              fontSize: 9,
              letterSpacing: .35,
              fontWeight: FontWeight.w800)),
    );
  }
}

class _CompassLabel extends StatelessWidget {
  final Alignment alignment;
  final EdgeInsets padding;
  final String label;
  final Color color;

  const _CompassLabel({
    required this.alignment,
    required this.padding,
    required this.label,
    this.color = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) => Align(
        alignment: alignment,
        child: Padding(
          padding: padding,
          child: Text(label,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w800)),
        ),
      );
}

class _CompassTicksPainter extends CustomPainter {
  final Color color;
  const _CompassTicksPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final tickPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2;
    for (var index = 0; index < 72; index++) {
      final angle = index * 5 * math.pi / 180;
      final isMajor = index % 6 == 0;
      final isMedium = index % 3 == 0;
      final outerRadius = radius * .94;
      final innerRadius = outerRadius -
          (isMajor
              ? radius * .085
              : (isMedium ? radius * .055 : radius * .027));
      tickPaint
        ..color = isMajor ? AppColors.secondary : color.withValues(alpha: .72)
        ..strokeWidth = isMajor ? 2.2 : 1.05;
      canvas.drawLine(
        Offset(center.dx + math.sin(angle) * innerRadius,
            center.dy - math.cos(angle) * innerRadius),
        Offset(center.dx + math.sin(angle) * outerRadius,
            center.dy - math.cos(angle) * outerRadius),
        tickPaint,
      );
    }
    final ringPaint = Paint()
      ..color = AppColors.secondary.withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius * .72, ringPaint);
    canvas.drawCircle(center, radius * .46, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _CompassTicksPainter oldDelegate) =>
      oldDelegate.color != color;
}
