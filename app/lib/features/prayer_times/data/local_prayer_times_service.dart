import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

class LocalPrayerTimesService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.aladhan.com/v1',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  static Future<Map<String, dynamic>> fetchDaily({
    required double latitude,
    required double longitude,
    int school = 1,
    DateTime? date,
  }) async {
    final day = DateFormat('dd-MM-yyyy').format(date ?? DateTime.now());
    final response = await _dio.get('/timings/$day', queryParameters: {
      'latitude': latitude,
      'longitude': longitude,
      'method': 1,
      'school': school,
    });
    final payload = response.data;
    if (payload is! Map || payload['code'] != 200 || payload['data'] is! Map) {
      throw const FormatException(
          'Prayer times could not be loaded for this location');
    }
    final raw = payload['data']['timings'];
    if (raw is! Map)
      throw const FormatException('Prayer times response was incomplete');

    String? time(String key) {
      final value = raw[key]?.toString();
      if (value == null || value.isEmpty) return null;
      final normalized = value.split(' ').first.trim();
      return RegExp(r'^\d{2}:\d{2}').firstMatch(normalized)?.group(0);
    }

    return {
      'source': 'AlAdhan',
      'date': DateFormat('yyyy-MM-dd').format(date ?? DateTime.now()),
      'fajrAdhan': time('Fajr'),
      'dhuhrAdhan': time('Dhuhr'),
      'asrAdhan': time('Asr'),
      'maghribAdhan': time('Maghrib'),
      'ishaAdhan': time('Isha'),
      'sunrise': time('Sunrise'),
      'sunset': time('Sunset'),
    };
  }
}
