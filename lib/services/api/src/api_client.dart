import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';
import 'api_response.dart';
import 'session_manager.dart';

/// A file to send in a multipart request. Works on web (bytes) and native.
class ApiUploadFile {
  final String field;
  final String fileName;
  final Uint8List bytes;
  const ApiUploadFile({required this.field, required this.fileName, required this.bytes});
}

/// Single entry point for every PHP API call.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final http.Client _http = http.Client();

  // Rate-limit protection: the server/CDN answers 429 when too many requests
  // arrive at once (the app fires dozens on startup). We cap concurrency,
  // share identical in-flight read requests, and retry 429 with backoff.
  static const int _maxConcurrent = 4;
  static const int _max429Retries = 4;
  int _running = 0;
  final List<Completer<void>> _waiting = [];
  final Map<String, Future<ApiResponse>> _inFlight = {};

  static final RegExp _readAction =
      RegExp(r'^(list|get|overview|search|view|count|summary|stats|report|fetch)', caseSensitive: false);

  Future<void> _acquire() async {
    if (_running < _maxConcurrent) {
      _running++;
      return;
    }
    final c = Completer<void>();
    _waiting.add(c);
    await c.future; // slot is handed over without decrementing _running
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete();
    } else {
      _running--;
    }
  }

  /// Runs [run] once for concurrent identical [key]s (reads only).
  Future<ApiResponse> _dedupe(String? key, Future<ApiResponse> Function() run) {
    if (key == null) return run();
    final existing = _inFlight[key];
    if (existing != null) return existing;
    final f = run();
    _inFlight[key] = f;
    f.whenComplete(() => _inFlight.remove(key)).ignore();
    return f;
  }

  Uri _uri(String endpoint, [Map<String, dynamic>? query]) {
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v != null) q[k] = v.toString();
    });
    return Uri.parse('${ApiConfig.baseUrl}/$endpoint')
        .replace(queryParameters: q.isEmpty ? null : q);
  }

  Future<Map<String, String>> _headers({bool json = true, bool auth = true}) async {
    final h = <String, String>{'Accept': 'application/json'};
    if (json) h['Content-Type'] = 'application/json';
    if (auth) {
      final t = await SessionManager.getToken();
      if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  /// POST JSON. `action` is sent both in the query string and the body, which
  /// the documentation allows ("either as a URL query param or in the body").
  Future<ApiResponse> post(
    String endpoint, {
    String? action,
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    final payload = <String, dynamic>{...?body};
    if (action != null) payload['action'] = action;
    final q = <String, dynamic>{...?query};
    if (action != null) q['action'] = action;
    final isRead = action != null && _readAction.hasMatch(action);
    final tokenKey = auth ? (await SessionManager.getToken() ?? '') : '';
    return _dedupe(
      isRead ? 'POST|${_uri(endpoint, q)}|$tokenKey|${jsonEncode(payload)}' : null,
      () => _send(
        () async => _http.post(
          _uri(endpoint, q),
          headers: await _headers(auth: auth),
          body: jsonEncode(payload),
        ),
        timeout: ApiConfig.receiveTimeout,
      ),
    );
  }

  Future<ApiResponse> get(
    String endpoint, {
    String? action,
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    final q = <String, dynamic>{...?query};
    if (action != null) q['action'] = action;
    final tokenKey = auth ? (await SessionManager.getToken() ?? '') : '';
    return _dedupe(
      'GET|${_uri(endpoint, q)}|$tokenKey',
      () => _send(
        () async => _http.get(_uri(endpoint, q), headers: await _headers(json: false, auth: auth)),
        timeout: ApiConfig.receiveTimeout,
      ),
    );
  }

  /// Multipart POST (file uploads, chat attachments, feed media).
  /// [fields] values that are Lists are sent as repeated `key[]` entries.
  /// NOTE: http's MultipartRequest cannot report byte-level progress; the
  /// optional [onProgress] is called with 0.0 at start and 1.0 on completion.
  Future<ApiResponse> multipart(
    String endpoint, {
    String? action,
    Map<String, dynamic>? fields,
    List<ApiUploadFile> files = const [],
    void Function(double progress)? onProgress,
  }) async {
    return _send(() async {
      final req = http.MultipartRequest('POST', _uri(endpoint, {if (action != null) 'action': action}));
      req.headers.addAll(await _headers(json: false));
      if (action != null) req.fields['action'] = action;
      fields?.forEach((k, v) {
        if (v == null) return;
        if (v is List) {
          for (var i = 0; i < v.length; i++) {
            req.fields['$k[$i]'] = v[i].toString();
          }
        } else {
          req.fields[k] = v.toString();
        }
      });
      for (final f in files) {
        req.files.add(http.MultipartFile.fromBytes(f.field, f.bytes, filename: f.fileName));
      }
      onProgress?.call(0.0);
      final streamed = await _http.send(req);
      final res = await http.Response.fromStream(streamed);
      onProgress?.call(1.0);
      return res;
    }, timeout: ApiConfig.uploadTimeout);
  }

  Future<ApiResponse> _send(
    Future<http.Response> Function() call, {
    required Duration timeout,
  }) async {
    try {
      http.Response res;
      var attempt = 0;
      while (true) {
        await _acquire();
        try {
          res = await call().timeout(timeout);
        } finally {
          _release();
        }
        if (res.statusCode != 429 || attempt >= _max429Retries) break;
        final ra = int.tryParse(res.headers['retry-after'] ?? '');
        final wait = Duration(milliseconds: ra != null ? ra * 1000 : 800 * (1 << attempt));
        attempt++;
        await Future<void>.delayed(wait);
      }
      if (res.statusCode == 429) {
        throw const ApiException(
          'Too many requests. Please wait a moment and try again.',
          type: ApiErrorType.server,
          statusCode: 429,
        );
      }
      return _parse(res);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('The request timed out. Please try again.', type: ApiErrorType.timeout);
    } on http.ClientException {
      throw const ApiException('Unable to reach the server. Check your internet connection.', type: ApiErrorType.network);
    } catch (e) {
      // dart:io SocketException etc. (not importable on web, so match by name)
      final s = e.runtimeType.toString();
      if (s.contains('SocketException') || s.contains('HandshakeException')) {
        throw const ApiException('No internet connection.', type: ApiErrorType.network);
      }
      debugPrint('ApiClient unexpected error: $e');
      throw ApiException(e.toString(), type: ApiErrorType.unknown);
    }
  }

  ApiResponse _parse(http.Response res) {
    final code = res.statusCode;
    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map) json = Map<String, dynamic>.from(decoded);
    } catch (_) {}

    if (code == 401 || code == 403) {
      SessionManager.onUnauthorized?.call();
      throw ApiException(
        (json?['message'] ?? 'Session expired. Please log in again.').toString(),
        type: ApiErrorType.unauthorized,
        statusCode: code,
      );
    }
    if (json == null) {
      throw ApiException(
        code >= 500 ? 'Server error ($code). Please try again later.' : 'Invalid response from server.',
        type: code >= 500 ? ApiErrorType.server : ApiErrorType.invalidResponse,
        statusCode: code,
      );
    }
    final r = ApiResponse.fromJson(json, code);
    if (!r.status && _looksLikeAuthFailure(r.message)) {
      SessionManager.onUnauthorized?.call();
    }
    return r;
  }

  static bool _looksLikeAuthFailure(String m) {
    final l = m.toLowerCase();
    return l.contains('unauthorized') ||
        l.contains('invalid token') ||
        l.contains('token expired') ||
        l.contains('session expired');
  }
}
