import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:my_jdownloader_api/src/cipher.dart';
import 'package:my_jdownloader_api/src/session.dart';
import 'package:my_jdownloader_api/src/utils/http.dart';

final _utf8Json = json.fuse(utf8);
final _jdownloaderApiUrl = Uri.parse('https://api.jdownloader.org');

class Client {
  Client({
    Uri? baseUrl,
    required SessionHandler session,
    http.Client? httpClient,
  })  : _baseUrl = baseUrl ?? _jdownloaderApiUrl,
        _session = session,
        _httpClient = httpClient;

  factory Client.fromCredentials(
    String email,
    String password, {
    Uri? baseUrl,
    int? apiVersion,
    String? appKey,
    http.Client? httpClient,
  }) {
    final effectiveSession = InitialSessionHandler.fromCredentials(
      email,
      password,
      appKey: appKey,
    );

    return Client(
      baseUrl: baseUrl,
      session: effectiveSession,
      httpClient: httpClient,
    );
  }

  final Uri _baseUrl;
  SessionHandler _session;
  http.Client? _httpClient;

  static int nextRequestId() {
    final rand = Random();
    return (rand.nextDouble() * 1e13).floor();
  }

  Future<Map<String, dynamic>> sendServerRequest(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    var session = _session;

    if (session is! Session) {
      session = await refreshSession();
    }

    return _sendServerRequest(
      session.serverCipher,
      path,
      queryParameters: {
        if (queryParameters != null) ...queryParameters,
        'sessiontoken': session.sessionToken,
      },
    );
  }

  Future<Map<String, dynamic>> _sendServerRequest(
    Cipher cipher,
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final requestId = Client.nextRequestId();

    var url = _baseUrl.replace(
      pathSegments: _baseUrl.pathSegmentsFollowedBy(path),
      queryParameters: {
        ..._baseUrl.queryParameters,
        if (queryParameters != null) ...queryParameters,
        'rid': '$requestId',
      },
    );

    final requestTarget = url.requestTarget;
    final signature = cipher.sign(requestTarget);

    url = url.replace(
      queryParameters: {
        ...url.queryParameters,
        'signature': signature,
      },
    );

    final response = await (_httpClient?.post ?? http.post)(url);
    ApiException.checkResponse(response);

    final responseBody = cipher.decodeBase64(response.body);
    return _utf8Json.decode(responseBody) as Map<String, dynamic>;
  }

  Future<T> sendDeviceRequest<T>(
    String deviceId,
    String path, {
    int apiVersion = 1,
    Map<String, dynamic>? params,
  }) async {
    var session = _session;

    if (session is! Session) {
      session = await refreshSession();
    }

    final requestId = Client.nextRequestId();

    final body = {
      'apiVer': apiVersion,
      'rid': requestId,
      'url': path,
      if (params != null) 'params': [jsonEncode(params)],
    };

    final encryptedBody = session.deviceCipher.encodeBase64(_utf8Json.encode(body));
    final target = 't_${session.sessionToken}_$deviceId$path';

    final url = _baseUrl.replace(
      pathSegments: _baseUrl.pathSegmentsFollowedBy(target),
    );

    final response = await (_httpClient?.post ?? http.post)(url, body: encryptedBody);
    ApiException.checkResponse(response);

    final responseBody = session.deviceCipher.decodeBase64(response.body);
    final decodedBody = _utf8Json.decode(responseBody) as Map<String, dynamic>;

    return decodedBody['data'] as T;
  }

  Future<Session>? _refreshingFuture;

  Future<Session> refreshSession() async {
    if (_refreshingFuture == null) {
      try {
        _refreshingFuture = _session.refresh(_sendServerRequest);
        return _session = await _refreshingFuture!;
      } //
      finally {
        _refreshingFuture = null;
      }
    } //
    else {
      return _refreshingFuture!;
    }
  }

  Future<void> close() async {
    await _session.disconnect(_sendServerRequest);
    _httpClient?.close();
    _httpClient = null;
  }
}

class ApiException implements Exception {
  const ApiException(
    this.url,
    this.statusCode,
    this.reasonPhrase,
  );

  final Uri? url;
  final int statusCode;
  final String? reasonPhrase;

  factory ApiException.fromResponse(http.Response response) {
    return ApiException(
      response.request?.url,
      response.statusCode,
      response.reasonPhrase,
    );
  }

  @override
  String toString() => 'ApiException($statusCode, $reasonPhrase, url: $url)';

  static void checkResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 400) {
      return;
    }

    throw ApiException.fromResponse(response);
  }
}
