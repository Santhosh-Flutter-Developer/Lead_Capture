import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';
import 'dart:math';

class AesHelper {
  final Key key;

  AesHelper(this.key);

  /// Create AES key from password using SHA256
  factory AesHelper.fromPassword(String password) {
    final hash = sha256.convert(utf8.encode(password)).bytes;
    return AesHelper(Key(Uint8List.fromList(hash)));
  }

  /// Generate random 16-byte IV
  IV _randomIV() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return IV(Uint8List.fromList(bytes));
  }

  /// SAFE ENCRYPTION
  String encryptString(String plainText) {
    // If plain text is empty → return empty string  (NO encryption)
    if (plainText.isEmpty) return "";

    try {
      final iv = _randomIV();
      final encrypter = Encrypter(
        AES(key, mode: AESMode.cbc, padding: "PKCS7"),
      );
      final encrypted = encrypter.encrypt(plainText, iv: iv);

      // Combine IV + ciphertext → base64
      final combined = iv.bytes + encrypted.bytes;
      return base64Encode(combined);
    } catch (_) {
      return ""; // fallback
    }
  }

  /// SAFE DECRYPTION
  String decryptString(String encryptedBase64) {
    // If input is empty → return empty
    if (encryptedBase64.isEmpty) return "";

    try {
      final combined = base64Decode(encryptedBase64);

      // Ciphertext must be longer than 16 bytes (IV)
      if (combined.length < 17) return "";

      final ivBytes = combined.sublist(0, 16);
      final cipherBytes = combined.sublist(16);

      final iv = IV(ivBytes);
      final encrypter = Encrypter(
        AES(key, mode: AESMode.cbc, padding: "PKCS7"),
      );

      return encrypter.decrypt(Encrypted(cipherBytes), iv: iv);
    } catch (_) {
      // Any exception → return empty string
      return "";
    }
  }
}
