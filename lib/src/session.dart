import 'dart:typed_data';

import 'package:my_jdownloader_api/src/cipher.dart';
import 'package:my_jdownloader_api/src/models/_models.dart';

typedef RequestSender = Future<Map<String, dynamic>> Function(
  SessionHandler session,
  String path, {
  Map<String, dynamic>? queryParameters,
});

abstract class SessionHandler {
  Cipher get serverCipher;

  Cipher get deviceCipher;

  Future<Session> refresh(RequestSender send);

  Future<void> disconnect(RequestSender send);
}

class InitialSession implements SessionHandler {
  const InitialSession({
    required this.appKey,
    required this.email,
    required this.serverCipher,
    required this.deviceCipher,
  });

  InitialSession.fromCredentials(
    this.email,
    String password, {
    String? appKey,
  })  : appKey = appKey ?? 'jdownloader-api-indev',
        serverCipher = Cipher.fromCredentials(email, password, 'server'),
        deviceCipher = Cipher.fromCredentials(email, password, 'device');

  final String appKey;
  final String email;

  @override
  final Cipher serverCipher;

  @override
  final Cipher deviceCipher;

  @override
  Future<Session> refresh(RequestSender send) async {
    final json = await send(
      this,
      '/my/connect',
      queryParameters: {
        'appkey': appKey,
        'email': email,
      },
    );

    final response = ConnectResponse.fromJson(json);

    return Session(
      appKey: appKey,
      deviceSeed: deviceCipher.seed,
      sessionToken: response.sessionToken,
      regainToken: response.regainToken,
      serverCipher: Cipher.derive(serverCipher.seed, response.sessionToken),
      deviceCipher: Cipher.derive(deviceCipher.seed, response.sessionToken),
    );
  }

  @override
  Future<void> disconnect(RequestSender send) async {}
}

class Session implements SessionHandler {
  const Session({
    required this.appKey,
    required this.deviceSeed,
    required this.sessionToken,
    required this.regainToken,
    required this.serverCipher,
    required this.deviceCipher,
  });

  final String appKey;
  final Uint8List deviceSeed;
  final String sessionToken;
  final String regainToken;

  @override
  final Cipher serverCipher;

  @override
  final Cipher deviceCipher;

  @override
  Future<Session> refresh(RequestSender send) async {
    final json = await send(
      this,
      '/my/reconnect',
      queryParameters: {
        'appkey': appKey,
        'sessiontoken': sessionToken,
        'regaintoken': regainToken,
      },
    );

    final response = ConnectResponse.fromJson(json);

    return Session(
      appKey: appKey,
      deviceSeed: deviceSeed,
      sessionToken: response.sessionToken,
      regainToken: response.regainToken,
      serverCipher: Cipher.derive(serverCipher.seed, response.sessionToken),
      deviceCipher: Cipher.derive(deviceSeed, response.sessionToken),
    );
  }

  @override
  Future<void> disconnect(RequestSender send) {
    return send(
      this,
      '/my/disconnect',
      queryParameters: {
        'sessiontoken': sessionToken,
      },
    );
  }
}
