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

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
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
        declination = await const MethodChannel('silah/compass').invokeMethod<double>(
              'magneticDeclination',
              {'latitude': lat, 'longitude': lng},
            ) ?? 0;
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
    final x = math.cos(phi1) * math.tan(phi2) - math.sin(phi1) * math.cos(deltaLambda);

    final qibla = math.atan2(y, x) * 180.0 / math.pi;
    return (qibla + 360.0) % 360.0;
  }

  // Haversine distance formula in kilometers
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371.0; // Earth radius in km
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) * math.cos(lat2 * math.pi / 180.0) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
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
            final normalized = ((heading + _magneticDeclination) % 360.0 + 360.0) % 360.0;
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
    HapticFeedback.mediumImpact();

    try {
      // 1. Recalibrate GPS coordinates
      await _initLocationAndQibla();
      if (!_hasValidLocation) {
        if (mounted) {
          setState(() => _isDetecting = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location is required to find Qibla.')));
        }
        return;
      }

      // 2. Fetch fresh sensor reading
      final event = await FlutterCompass.events?.first.timeout(const Duration(seconds: 2));

      final rawHeading = event?.heading;
      if (rawHeading != null) {
        final normalized = ((rawHeading + _magneticDeclination) % 360.0 + 360.0) % 360.0;
        setState(() {
          _heading = normalized;
          _hasCompassSensor = true;
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isDetecting = false);
      HapticFeedback.heavyImpact();

      if (_heading == null) return;
      final currentH = _heading!;
      double diff = (_qiblaBearing - currentH);
      while (diff > 180) {
        diff -= 360;
      }
      while (diff < -180) {
        diff += 360;
      }

      final turnStr = diff.abs() <= 5.0
          ? 'Facing Qibla!'
          : diff > 0
              ? 'Turn Right ➔ ${diff.toStringAsFixed(0)}°'
              : 'Turn Left ⬅ ${(-diff).toStringAsFixed(0)}°';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Phone facing ${currentH.toStringAsFixed(0)}° • Qibla is at ${_qiblaBearing.toStringAsFixed(0)}° ($turnStr)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF0F432B),
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
    final lang = ref.read(languageProvider.notifier);

    // Live phone heading from true North (0 = N, 90 = E, 180 = S, 270 = W)
    final double phoneHeading = _heading ?? 0.0;

    // Difference between Qibla bearing and phone heading (-180 to +180)
    double diff = (_qiblaBearing - phoneHeading);
    while (diff > 180) {
      diff -= 360;
    }
    while (diff < -180) {
      diff += 360;
    }

    final bool isFacingQibla = _hasValidLocation && _heading != null && diff.abs() <= 5.0;
    final qiblaCardinal = _getCardinalDirection(_qiblaBearing);
    final phoneCardinal = _getCardinalDirection(phoneHeading);

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
        title: Text(lang.tr(en: 'Qibla Direction', ta: 'கிப்லா திசை')),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Recalibrate GPS Location',
            onPressed: () async {
              await _initLocationAndQibla();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_hasValidLocation
                        ? 'Qibla direction calibrated to ${_qiblaBearing.toStringAsFixed(1)}° for $_userCity'
                        : 'Location is unavailable. Enable location or connect a masjid with coordinates.'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          TextButton(
            onPressed: () => lang.toggleLanguage(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(16)),
              child: Text(ref.watch(languageProvider) ? 'தமிழ்' : 'English',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              // Bearing info banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isFacingQibla ? const Color(0xFFE8F5E9) : AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isFacingQibla ? AppColors.success : AppColors.primary,
                    width: isFacingQibla ? 2.5 : 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isFacingQibla ? Icons.check_circle : Icons.explore,
                      color: isFacingQibla ? AppColors.success : AppColors.primary,
                      size: 34,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            !_hasValidLocation
                                ? lang.tr(en: 'Location is required to find Qibla', ta: 'கிப்லா திசைக்கு இடம் தேவை')
                                : isFacingQibla
                                    ? lang.tr(en: 'Facing Qibla! (Makkah)', ta: 'கிப்லாவை நோக்கி உள்ளீர்கள்!')
                                    : 'Qibla: ${_qiblaBearing.toStringAsFixed(0)}° $qiblaCardinal • ${lang.tr(en: 'Kaaba Direction', ta: 'கஅபா திசை')}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isFacingQibla ? AppColors.success : AppColors.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _hasValidLocation
                                ? 'Phone Facing: ${phoneHeading.toStringAsFixed(0)}° ($phoneCardinal) • Makkah: ~${_distanceKm.toStringAsFixed(0)} km'
                                : 'Enable location or connect a masjid with saved coordinates.',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Turn Instruction Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isFacingQibla
                      ? AppColors.success.withValues(alpha: 0.15)
                      : (diff > 0 ? Colors.blue.shade50 : Colors.indigo.shade50),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isFacingQibla ? AppColors.success : Colors.blue.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      !_hasValidLocation
                          ? Icons.location_off
                          : isFacingQibla
                              ? Icons.done_all
                              : (diff > 0 ? Icons.turn_right : Icons.turn_left),
                      size: 18,
                      color: isFacingQibla ? AppColors.success : Colors.indigo,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      !_hasValidLocation
                          ? lang.tr(en: 'Allow location to calculate direction', ta: 'திசையை கணக்கிட இட அனுமதி அளிக்கவும்')
                          : isFacingQibla
                              ? lang.tr(en: 'Directly Facing Makkah', ta: 'நேரடியாக மக்காவை நோக்கி நிற்கிறது')
                              : diff > 0
                              ? lang.tr(
                                  en: 'Turn Right by ${diff.toStringAsFixed(0)}° to face Qibla',
                                  ta: 'வலதுபுறம் ${diff.toStringAsFixed(0)}° திரும்பவும்',
                                )
                              : lang.tr(
                                  en: 'Turn Left by ${(-diff).toStringAsFixed(0)}° to face Qibla',
                                  ta: 'இடதுபுறம் ${(-diff).toStringAsFixed(0)}° திரும்பவும்',
                                ),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isFacingQibla ? AppColors.success : Colors.indigo.shade900,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Live Rotating Analog Compass with Arrow Pointing to Kaaba in Space
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: phoneHeading),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  builder: (ctx, animHeading, _) {
                    final animatedNeedleRad = (_qiblaBearing - animHeading) * (math.pi / 180.0);
                    final animatedDialRad = -animHeading * (math.pi / 180.0);

                    return SizedBox(
                      width: 290,
                      height: 290,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Compass Dial (Rotates in reverse of device heading)
                          Transform.rotate(
                            angle: animatedDialRad,
                            child: Container(
                              width: 280,
                              height: 280,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: isFacingQibla ? AppColors.success : const Color(0xFF0F432B),
                                  width: 3.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isFacingQibla ? AppColors.success : Colors.black).withValues(alpha: 0.12),
                                    blurRadius: 18,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Cardinal directions
                                  const Align(
                                    alignment: Alignment.topCenter,
                                    child: Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text('N', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 17)),
                                    ),
                                  ),
                                  const Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: Text('S', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 15)),
                                    ),
                                  ),
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Text('W', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 15)),
                                    ),
                                  ),
                                  const Align(
                                    alignment: Alignment.centerRight,
                                    child: Padding(
                                      padding: EdgeInsets.only(right: 8),
                                      child: Text('E', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 15)),
                                    ),
                                  ),

                                  // Kaaba Azimuth Marker directly on the compass dial at _qiblaBearing
                                  if (_hasValidLocation)
                                    Transform.rotate(
                                    angle: _qiblaBearing * (math.pi / 180.0),
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: Container(
                                        margin: const EdgeInsets.only(top: 24),
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F432B),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.amber, width: 2),
                                        ),
                                        child: const Icon(Icons.mosque, color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Kaaba Needle: Points towards physical Kaaba location relative to where phone is currently pointing
                          if (_hasValidLocation && _heading != null)
                            Transform.rotate(
                            angle: animatedNeedleRad,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Arrow Head with Kaaba Symbol
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: isFacingQibla ? AppColors.success : const Color(0xFF0F432B),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.amber, width: 2),
                                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                                  ),
                                  child: const Icon(Icons.arrow_upward, color: Colors.white, size: 26),
                                ),
                                // Needle Shaft
                                Container(
                                  width: 5.0,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: isFacingQibla
                                          ? [AppColors.success, AppColors.success.withValues(alpha: 0.6)]
                                          : [const Color(0xFF0F432B), Colors.amber],
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(height: 80),
                              ],
                            ),
                          )
                          else
                            const Icon(Icons.location_off, color: Colors.orange, size: 42),

                          // Center Pivot
                          CircleAvatar(
                            radius: 9,
                            backgroundColor: isFacingQibla ? AppColors.success : const Color(0xFF0F432B),
                            child: const CircleAvatar(radius: 4, backgroundColor: Colors.white),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 18),

              // USER REQUESTED BUTTON: Detect & Point Arrow to Qibla
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFacingQibla ? AppColors.success : const Color(0xFF0F432B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                  ),
                  icon: _isDetecting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.navigation, size: 22),
                  label: Text(
                    _isDetecting
                        ? lang.tr(en: 'Detecting Phone Orientation...', ta: 'திசையைக் கண்டுபிடிக்கிறது...')
                        : lang.tr(
                            en: 'Calibrate & Point Arrow to Qibla',
                            ta: 'கிப்லா திசையை சரியாக காட்டு (Detect Now)',
                          ),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: _isDetecting ? null : _detectAndPointToQibla,
                ),
              ),

              const SizedBox(height: 14),

              // Direction guidance card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F432B).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.explore, color: Color(0xFF0F432B), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.tr(
                              en: 'Arrow always points towards Makkah (Kaaba).',
                              ta: 'அம்புகுறி எப்போதும் மக்கா (கஅபா) திசையையே காட்டும்.',
                            ),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lang.tr(
                              en: 'Even if your phone faces elsewhere, the arrow points towards Kaaba. Turn until arrow points straight UP.',
                              ta: 'போன் எந்தப் பக்கம் திரும்பியிருந்தாலும் அம்பு கஅபாவை மட்டுமே காட்டும். அம்பு நேராகும் வரை திரும்பவும்.',
                            ),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _hasCompassSensor ? Icons.sensors : Icons.sensors_off,
                    size: 14,
                    color: _hasCompassSensor ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _hasCompassSensor
                        ? 'Live Compass Sensor Active'
                        : 'Static Direction Mode (Compass sensor not detected)',
                    style: TextStyle(
                      fontSize: 11,
                      color: _hasCompassSensor ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
