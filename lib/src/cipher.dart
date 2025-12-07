import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

class Cipher {
  const Cipher({
    required this.seed,
    required this.encrypter,
    required this.iv,
    required this.mac,
  });

  factory Cipher.fromCredentials(String email, String password, String type) {
    final token = '$email$password$type';
    final digest = sha256.convert(utf8.encode(token));
    return Cipher.fromSeed(Uint8List.fromList(digest.bytes));
  }

  factory Cipher.derive(Uint8List seed, String sessionToken) {
    final sessionTokenBytes = Uint8List.fromList(hex.decode(sessionToken));
    final digest = sha256.convert([...seed, ...sessionTokenBytes]);
    return Cipher.fromSeed(Uint8List.fromList(digest.bytes));
  }

  factory Cipher.fromSeed(Uint8List seed) {
    if (seed.length < 32) {
      throw ArgumentError('seed must be at least 32 bytes');
    }

    final half = seed.length ~/ 2;
    final ivBytes = seed.sublist(0, half);
    final keyBytes = seed.sublist(half);

    final cipher = Encrypter(
      AES(Key(keyBytes), mode: AESMode.cbc),
    );

    return Cipher(
      seed: seed,
      encrypter: cipher,
      iv: IV(ivBytes),
      mac: Hmac(sha256, seed),
    );
  }

  final Uint8List seed;
  final Encrypter encrypter;
  final IV iv;
  final Hmac mac;

  String sign(String input) {
    return mac.convert(utf8.encode(input)).toString();
  }

  String encodeBase64(List<int> data) {
    final encrypted = encrypter.encryptBytes(data, iv: iv);
    return encrypted.base64;
  }

  List<int> decodeBase64(String encoded) {
    final bytes = base64.decode(encoded);
    return encrypter.decryptBytes(Encrypted(bytes), iv: iv);
  }
}
