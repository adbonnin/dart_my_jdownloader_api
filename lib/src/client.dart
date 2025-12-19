import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:my_jdownloader_api/src/models/_models.dart';
import 'package:my_jdownloader_api/src/session.dart';
import 'package:my_jdownloader_api/src/utils/http.dart';

final _utf8Json = json.fuse(utf8);
final _jdownloaderApiBaseUri = Uri.parse('https://api.jdownloader.org');

class Client {
  Client({
    Uri? baseUri,
    required InitialSession initialSession,
    http.Client? httpClient,
  })  : _baseUri = baseUri ?? _jdownloaderApiBaseUri,
        _initialSession = initialSession,
        _httpClient = httpClient;

  factory Client.fromCredentials(
    String email,
    String password, {
    Uri? baseUri,
    int? apiVersion,
    String? appKey,
    http.Client? httpClient,
  }) {
    final initialSession = InitialSession.fromCredentials(
      email,
      password,
      appKey: appKey,
    );

    return Client(
      baseUri: baseUri,
      initialSession: initialSession,
      httpClient: httpClient,
    );
  }

  final Uri _baseUri;
  final InitialSession _initialSession;
  Session? _session;
  http.Client? _httpClient;

  static int nextRequestId() {
    final rand = math.Random();
    return (rand.nextDouble() * 1e13).floor();
  }

  Future<Map<String, dynamic>> sendToServer(
    String path, {
    Map<String, dynamic>? queryParameters,
    int? maxRetries,
  }) {
    return _retryWithSessionRefresh(
      (session) => _sendToServer(
        session,
        path,
        queryParameters: {
          if (queryParameters != null) ...queryParameters,
          'sessiontoken': session.sessionToken,
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _sendToServer(
    SessionHandler session,
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final requestId = Client.nextRequestId();

    var uri = _baseUri.replace(
      pathSegments: _baseUri.pathSegmentsFollowedBy(path),
      queryParameters: {
        ..._baseUri.queryParameters,
        if (queryParameters != null) ...queryParameters,
        'rid': '$requestId',
      },
    );

    final requestTarget = uri.requestTarget;
    final signature = session.serverCipher.sign(requestTarget);

    uri = uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'signature': signature,
      },
    );

    final response = await (_httpClient?.post ?? http.post)(uri);
    ApiException.checkResponse(response);

    final responseBody = session.serverCipher.decodeBase64(response.body);
    return _utf8Json.decode(responseBody) as Map<String, dynamic>;
  }

  Future<T> sendToDevice<T>(
    String deviceId,
    String path, {
    int? apiVersion,
    Map<String, dynamic>? params,
    int? maxRetries,
  }) {
    return _retryWithSessionRefresh(
      (session) => _sendToDevice(
        session,
        deviceId,
        path,
        apiVersion: apiVersion,
        params: params,
      ),
    );
  }

  Future<T> _sendToDevice<T>(
    Session session,
    String deviceId,
    String path, {
    int? apiVersion,
    Map<String, dynamic>? params,
  }) async {
    final requestId = Client.nextRequestId();

    final body = {
      'apiVer': apiVersion ?? 1,
      'rid': requestId,
      'url': path,
      if (params != null) 'params': [jsonEncode(params)],
    };

    final encryptedBody = session.deviceCipher.encodeBase64(_utf8Json.encode(body));
    final target = 't_${session.sessionToken}_$deviceId$path';

    final uri = _baseUri.replace(
      pathSegments: _baseUri.pathSegmentsFollowedBy(target),
    );

    final response = await (_httpClient?.post ?? http.post)(uri, body: encryptedBody);
    ApiException.checkResponse(response);

    final responseBody = session.deviceCipher.decodeBase64(response.body);
    final decodedBody = _utf8Json.decode(responseBody) as Map<String, dynamic>;

    return decodedBody['data'] as T;
  }

  Future<T> _retryWithSessionRefresh<T>(Future<T> Function(Session session) operation) async {
    var session = _session ?? await refreshSession();
    var attempt = 0;

    while (true) {
      try {
        return await operation(session);
      } //
      on ApiException catch (e) {
        attempt++;

        final isInvalidToken = e.isInvalidToken;
        final canRetry = (isInvalidToken || e.isAuthFailed) && attempt < 2;

        if (!canRetry) {
          rethrow;
        }

        if (isInvalidToken) {
          session = await refreshSession();
        } //
        else {
          session = await refreshSession(init: true);
        }
      } //
      catch (e) {
        rethrow;
      }
    }
  }

  Future<Session>? _currentRefresh;

  Future<Session> refreshSession({bool init = false}) async {
    final currentRefresh = _currentRefresh;

    if (currentRefresh != null) {
      return currentRefresh;
    }

    final usedSession = init ? _initialSession : (_session ?? _initialSession);
    final refreshFuture = usedSession.refresh(_sendToServer);
    _currentRefresh = refreshFuture;

    try {
      return _session = await refreshFuture;
    } //
    finally {
      if (_currentRefresh == refreshFuture) {
        _currentRefresh = null;
      }
    }
  }

  Future<void> close() async {
    await _session?.disconnect(_sendToServer);
    _httpClient?.close();
    _httpClient = null;
  }
}

class ApiException implements Exception {
  const ApiException(
    this.url,
    this.statusCode,
    this.reasonPhrase, {
    this.error,
    this.errorSrc,
    this.errorType,
  });

  final Uri? url;
  final int statusCode;
  final String? reasonPhrase;
  final String? error;
  final String? errorSrc;
  final String? errorType;

  bool get isInvalidToken => errorType == 'TOKEN_INVALID';

  bool get isAuthFailed => errorType == 'AUTH_FAILED';

  factory ApiException.fromResponse(http.Response response) {
    final body = response.body;
    ErrorResponse? errorResponse;

    if (body.isNotEmpty) {
      try {
        final json = jsonDecode(body);
        errorResponse = ErrorResponse.fromJson(json);
      } //
      catch (e) {
        // Failed to parse error;
      }
    }

    return ApiException(
      response.request?.url,
      response.statusCode,
      response.reasonPhrase,
      error: body.isEmpty ? null : body,
      errorSrc: errorResponse?.src,
      errorType: errorResponse?.type,
    );
  }

  @override
  String toString() => 'ApiException($statusCode, $reasonPhrase, url: $url, error: $error)';

  static void checkResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 400) {
      return;
    }

    throw ApiException.fromResponse(response);
  }
}
