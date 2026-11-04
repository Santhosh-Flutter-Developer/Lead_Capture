import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

Uint8List masterKeyFromPassword(String password) {
  final digest = SHA256Digest();
  final bytes = utf8.encode(password);
  final hash1 = digest.process(Uint8List.fromList(bytes));
  final hash2 = digest.process(hash1);

  // 32 + 32 = 64 bytes
  return Uint8List.fromList([...hash1, ...hash2]);
}

/// HMAC-SHA256
Uint8List _hmacSha256(Uint8List key, Uint8List data) {
  final hmac = HMac(SHA256Digest(), 64)..init(KeyParameter(key));
  return _processDigest(hmac, data);
}

Uint8List _processDigest(Mac mac, Uint8List data) {
  mac.reset();
  mac.update(data, 0, data.length);
  final out = Uint8List(mac.macSize);
  mac.doFinal(out, 0);
  return out;
}

/// AES-CTR encryption/decryption (symmetric)
Uint8List _aesCtr(Uint8List key, Uint8List iv, Uint8List data) {
  final params = ParametersWithIV(KeyParameter(key), iv);
  final cipher = StreamCipher('AES/CTR')
    ..init(true, params); // true for encrypt, same works for decrypt in CTR
  final out = Uint8List(data.length);
  cipher.processBytes(data, 0, data.length, out, 0);
  return out;
}

/// Combine keys: expects masterKey length >= 64 bytes (512 bits) ideally.
/// Alternatively you can derive two keys properly via HKDF. For simplicity we split masterKey.
class DeterministicCrypto {
  final Uint8List encryptionKey; // 32 bytes for AES-256
  final Uint8List macKey; // 32 bytes for HMAC-SHA256

  DeterministicCrypto(Uint8List masterKey)
    : assert(
        masterKey.length >= 64,
        'masterKey must be at least 64 bytes (use a KDF/HKDF in production)',
      ),
      encryptionKey = Uint8List.fromList(masterKey.sublist(0, 32)),
      macKey = Uint8List.fromList(masterKey.sublist(32, 64));

  /// Deterministic encryption:
  /// - iv := first 16 bytes of HMAC(macKey, plaintext)
  /// - ciphertext := AES-CTR(encryptionKey, iv, plaintext)
  /// - tag := HMAC(macKey, ciphertext)
  /// - output := base64(tag || ciphertext)
  String encryptDeterministic(String plaintext) {
    final pt = Uint8List.fromList(utf8.encode(plaintext));

    // iv: deterministic from plaintext
    final ivFull = _hmacSha256(macKey, pt);
    final iv = Uint8List.fromList(ivFull.sublist(0, 16));

    final ct = _aesCtr(encryptionKey, iv, pt);

    // Tag on ciphertext for authentication
    final tag = _hmacSha256(macKey, ct);

    final out = Uint8List(tag.length + ct.length);
    out.setAll(0, tag);
    out.setAll(tag.length, ct);

    return base64Encode(out);
  }

  /// Decrypt:
  /// - splits tag and ciphertext
  /// - verifies tag matches HMAC(macKey, ciphertext)
  /// - reconstruct iv from plaintext? (we cannot compute IV from ciphertext)
  ///   but we encrypt using deterministic IV derived from plaintext; to decrypt,
  ///   compute IV from plaintext is circular. Instead: during decrypt we
  ///   compute iv from plaintext after decrypt — impossible.
  ///
  /// To avoid that problem, we derive IV during encrypt from HMAC(macKey, plaintext),
  /// but for decrypt we MUST be able to recompute IV without knowing plaintext:
  /// therefore we MUST store IV or derive IV from ciphertext (we derived it from plaintext).
  ///
  /// To fix: store IV (deterministic derived from plaintext) along with ciphertext.
  ///
  /// Final scheme: store iv (16 bytes) as prefix after tag.
  ///
  String encrypt(String plaintext) {
    final pt = Uint8List.fromList(utf8.encode(plaintext));
    final ivFull = _hmacSha256(macKey, pt);
    final iv = Uint8List.fromList(ivFull.sublist(0, 16));
    final ct = _aesCtr(encryptionKey, iv, pt);
    final tag = _hmacSha256(macKey, ct);

    // format: tag || iv || ciphertext
    final out = Uint8List(tag.length + iv.length + ct.length);
    var pos = 0;
    out.setAll(pos, tag);
    pos += tag.length;
    out.setAll(pos, iv);
    pos += iv.length;
    out.setAll(pos, ct);

    return base64Encode(out);
  }

  String tryDecrypt(String b64) {
    try {
      return decrypt(b64);
    } catch (_) {
      return '';
    }
  }

  /// Decrypt counterpart for the above format (tag || iv || ciphertext)
  String decrypt(String b64) {
    final raw = base64Decode(b64);
    final tagLen = 32; // HMAC-SHA256 length
    final ivLen = 16;

    if (raw.length < tagLen + ivLen) {
      // throw ArgumentError('Invalid ciphertext format');
      return '';
    }

    final tag = raw.sublist(0, tagLen);
    final iv = raw.sublist(tagLen, tagLen + ivLen);
    final ct = raw.sublist(tagLen + ivLen);

    // verify tag
    final expectedTag = _hmacSha256(macKey, ct);
    if (!_constantTimeEqual(tag, expectedTag)) {
      throw StateError(
        'Authentication tag mismatch - invalid key or tampered ciphertext',
      );
    }

    final pt = _aesCtr(encryptionKey, Uint8List.fromList(iv), ct);
    return utf8.decode(pt);
  }

  bool _constantTimeEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
