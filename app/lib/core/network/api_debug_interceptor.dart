import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Prints copyable cURL requests and their responses in debug builds only.
/// Credential and device-token fields are redacted before reaching the console.
class ApiDebugInterceptor extends Interceptor {
  static final RegExp _sensitiveKey = RegExp(
    r'(authorization|token|otp|password|secret|credential|api.?key|cookie)',
    caseSensitive: false,
  );

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('\n========== API REQUEST ==========');
      debugPrint(_toCurl(options));
      debugPrint('=================================\n');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('\n========== API RESPONSE =========');
      debugPrint(
          '${response.requestOptions.method} ${_safeUri(response.requestOptions.uri)}');
      debugPrint('Status: ${response.statusCode ?? 'unknown'}');
      debugPrint(_prettySafe(response.data));
      debugPrint('=================================\n');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final response = err.response;
      debugPrint('\n=========== API ERROR ===========');
      debugPrint(
          '${err.requestOptions.method} ${_safeUri(err.requestOptions.uri)}');
      debugPrint('Type: ${err.type.name}');
      if (err.message != null && err.message!.isNotEmpty) {
        debugPrint('Message: ${err.message}');
      }
      if (err.error != null) {
        debugPrint('Error: ${err.error}');
      }
      if (response != null) {
        debugPrint('Status: ${response.statusCode ?? 'unknown'}');
        debugPrint(_prettySafe(response.data));
      }
      debugPrint('=================================\n');
    }
    handler.next(err);
  }

  String _toCurl(RequestOptions options) {
    final uri = _safeUri(options.uri);
    final parts = <String>[
      'curl -X ${options.method.toUpperCase()} ${_shellQuote(uri)}'
    ];
    options.headers.forEach((key, value) {
      final safeValue =
          _sensitiveKey.hasMatch(key) ? '[REDACTED]' : value.toString();
      parts.add('-H ${_shellQuote('$key: $safeValue')}');
    });
    final body = _redactBody(options.data);
    if (body != null &&
        options.method.toUpperCase() != 'GET' &&
        options.method.toUpperCase() != 'HEAD') {
      final encoded = body is String ? body : jsonEncode(body);
      parts.add('--data-raw ${_shellQuote(encoded)}');
    }
    return parts.join(' \\\n  ');
  }

  String _safeUri(Uri uri) {
    final query = <String, String>{};
    uri.queryParameters.forEach((key, value) {
      query[key] = _sensitiveKey.hasMatch(key) ? '[REDACTED]' : value;
    });
    var path = uri.path;
    final qrTokenPath = RegExp(r'(/qr/)[^/]+');
    path = path.replaceAllMapped(
        qrTokenPath, (match) => '${match.group(1)}[REDACTED]');
    return uri
        .replace(path: path, queryParameters: query.isEmpty ? null : query)
        .toString();
  }

  dynamic _redactBody(dynamic body) {
    if (body is String) {
      try {
        return _redact(jsonDecode(body));
      } on FormatException {
        return body;
      }
    }
    return _redact(body);
  }

  dynamic _redact(dynamic value, [String? parentKey]) {
    if (parentKey != null && _sensitiveKey.hasMatch(parentKey)) {
      return '[REDACTED]';
    }
    if (value is Map) {
      return value.map((key, item) =>
          MapEntry(key.toString(), _redact(item, key.toString())));
    }
    if (value is List) return value.map((item) => _redact(item)).toList();
    return value;
  }

  String _prettySafe(dynamic value) {
    final safeValue = _redact(value);
    try {
      return const JsonEncoder.withIndent('  ').convert(safeValue);
    } catch (_) {
      return safeValue.toString();
    }
  }

  String _shellQuote(String value) => "'${value.replaceAll("'", "'\"'\"'")}'";
}
