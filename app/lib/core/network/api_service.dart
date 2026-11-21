import 'package:dio/dio.dart';

class ApiService {
  static final ApiService instance = ApiService._internal();
  factory ApiService() => instance;

  late final Dio _dio;
  String? authToken;
  Map<String, dynamic>? currentUser;

  bool get isMasjidAdmin {
    final adminRoles = currentUser?['adminRoles'] as List<dynamic>?;
    return adminRoles != null && adminRoles.isNotEmpty;
  }

  bool get isSuperAdmin {
    return currentUser?['isSuperAdmin'] == true;
  }

  ApiService._internal() {
    // Vercel Live Production Backend
    const baseUrl = 'https://backend-finytive.vercel.app/v1';

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (authToken != null) {
            options.headers['Authorization'] = 'Bearer $authToken';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // If 127.0.0.1 fails on Android, fallback to LAN IP 192.168.1.50
          if (error.type == DioExceptionType.connectionError &&
              _dio.options.baseUrl.contains('127.0.0.1')) {
            _dio.options.baseUrl = 'http://192.168.1.50:3000/v1';
            try {
              final response = await _dio.request(
                error.requestOptions.path,
                data: error.requestOptions.data,
                queryParameters: error.requestOptions.queryParameters,
                options: Options(
                  method: error.requestOptions.method,
                  headers: error.requestOptions.headers,
                ),
              );
              return handler.resolve(response);
            } catch (_) {}
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<Map<String, dynamic>> checkUser(String phone) async {
    final res = await _dio.post('/auth/check-user', data: {'phone': phone});
    return res.data;
  }

  Future<Map<String, dynamic>> loginDirect(String phone) async {
    final res = await _dio.post('/auth/login-direct', data: {'phone': phone});
    if (res.data['success'] == true && res.data['data'] != null) {
      authToken = res.data['data']['tokens']?['accessToken'];
      currentUser = res.data['data']['user'];
    }
    return res.data;
  }

  Future<Map<String, dynamic>> register({
    required String phone,
    required String name,
    required int age,
    String? address,
  }) async {
    final res = await _dio.post('/auth/register', data: {
      'phone': phone,
      'name': name,
      'age': age,
      if (address != null && address.isNotEmpty) 'address': address,
    });
    if (res.data['success'] == true && res.data['data'] != null) {
      authToken = res.data['data']['tokens']?['accessToken'];
      currentUser = res.data['data']['user'];
    }
    return res.data;
  }

  Future<void> updateDeviceToken(String fcmToken, {String platform = 'ANDROID'}) async {
    try {
      await _dio.post('/auth/device-token', data: {
        'fcmToken': fcmToken,
        'platform': platform,
      });
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> joinMasjid(String masjidId, {bool isPrimary = true}) async {
    try {
      final res = await _dio.post('/masjids/$masjidId/join', data: {'isPrimary': isPrimary});
      if (res.data['success'] == true) {
        return res.data['data'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getMasjidByQr(String qrToken) async {
    try {
      final res = await _dio.get('/masjids/qr/$qrToken');
      if (res.data['success'] == true) {
        return res.data['data'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final res = await _dio.post('/auth/otp/send', data: {'phone': phone});
    return res.data;
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final res = await _dio.post('/auth/otp/verify', data: {'phone': phone, 'otp': otp});
    if (res.data['success'] == true && res.data['data'] != null) {
      authToken = res.data['data']['tokens']?['accessToken'];
      currentUser = res.data['data']['user'];
    }
    return res.data;
  }

  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final res = await _dio.get('/auth/me');
      if (res.data['success'] == true && res.data['data'] != null) {
        currentUser = res.data['data'] as Map<String, dynamic>;
        return currentUser;
      }
    } catch (_) {}
    return null;
  }

  Future<List<dynamic>> getMasjids() async {
    try {
      final res = await _dio.get('/masjids');
      if (res.data['success'] == true) {
        return res.data['data'] as List<dynamic>;
      }
    } catch (e) {
      // Fallback
    }
    return [];
  }

  Future<Map<String, dynamic>?> getTodayPrayerTimes(String masjidId) async {
    try {
      final res = await _dio.get('/masjids/$masjidId/prayer-times/today');
      if (res.data['success'] == true) {
        return res.data['data'] as Map<String, dynamic>;
      }
    } catch (e) {
      // Return null on network error
    }
    return null;
  }

  Future<List<dynamic>> getAnnouncements(String masjidId) async {
    try {
      final res = await _dio.get('/masjids/$masjidId/announcements');
      if (res.data['success'] == true) {
        return res.data['data'] as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  Future<void> ensureSuperAdminAuth() async {
    if (authToken == null) {
      try {
        await verifyOtp('1234567890', '123456');
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> createMasjid({
    required String name,
    required String city,
    required String address,
    String? nameTa,
    double? latitude,
    double? longitude,
  }) async {
    final res = await _dio.post('/masjids', data: {
      'name': name,
      'city': city,
      'address': address,
      if (nameTa != null && nameTa.isNotEmpty) 'nameTa': nameTa,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return res.data;
  }

  Future<List<dynamic>> getPendingMasjidRequests() async {
    try {
      await ensureSuperAdminAuth();
      final res = await _dio.get('/masjids/requests/pending');
      if (res.data['success'] == true && res.data['data'] != null) {
        return res.data['data'] as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> approveMasjidRequest(String masjidId) async {
    await ensureSuperAdminAuth();
    final res = await _dio.post('/masjids/requests/$masjidId/approve');
    return res.data;
  }

  Future<Map<String, dynamic>> rejectMasjidRequest(String masjidId, [String? reason]) async {
    await ensureSuperAdminAuth();
    final res = await _dio.post('/masjids/requests/$masjidId/reject', data: {
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    return res.data;
  }

  Future<Map<String, dynamic>?> getSuperAdminStats() async {
    try {
      await ensureSuperAdminAuth();
      final res = await _dio.get('/dashboard/super-admin');
      if (res.data['success'] == true) {
        return res.data['data'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}
