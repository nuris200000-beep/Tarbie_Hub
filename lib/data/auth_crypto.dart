import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class AuthCrypto {
  AuthCrypto._();

  static String randomSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String hashPassword(String password, String salt) =>
      sha256.convert(utf8.encode('$password$salt')).toString();
}
