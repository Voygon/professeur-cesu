import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:math';

class EncryptionService {
  EncryptionService._();

  static const _keyChiffrement = 'field_encryption_key';
  // Préfixe qui distingue le nouveau format (IV aléatoire) de l'ancien
  static const _prefixeV2 = '2:';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Encrypter? _encrypter;
  // Conservé uniquement pour déchiffrer les valeurs chiffrées avant la v2
  static IV? _ivLegacy;

  static Future<void> init() async {
    String? keyBase64 = await _storage.read(key: _keyChiffrement);

    if (keyBase64 == null) {
      final keyBytes =
          List<int>.generate(32, (_) => Random.secure().nextInt(256));
      keyBase64 = base64Encode(keyBytes);
      await _storage.write(key: _keyChiffrement, value: keyBase64);
    }

    final keyBytes = base64Decode(keyBase64);
    final key = Key(keyBytes);
    _ivLegacy = IV(keyBytes.sublist(0, 16));
    _encrypter = Encrypter(AES(key, mode: AESMode.cbc));
  }

  // Chiffre avec un IV aléatoire par valeur (format v2)
  static String? chiffrer(String? value) {
    if (value == null || value.isEmpty) return value;
    if (_encrypter == null) {
      throw StateError('EncryptionService.init() doit être appelé au démarrage');
    }
    final iv = IV.fromSecureRandom(16);
    final encrypted = _encrypter!.encrypt(value, iv: iv);
    // Format : IV (16 bytes) || ciphertext, encodés ensemble en base64
    final combined = Uint8List(16 + encrypted.bytes.length);
    combined.setRange(0, 16, iv.bytes);
    combined.setRange(16, combined.length, encrypted.bytes);
    return '$_prefixeV2${base64Encode(combined)}';
  }

  // Déchiffre — gère les deux formats (v2 et legacy) pour la rétrocompatibilité
  static String? dechiffrer(String? value) {
    if (value == null || value.isEmpty) return value;
    if (_encrypter == null) {
      throw StateError('EncryptionService.init() doit être appelé au démarrage');
    }
    try {
      if (value.startsWith(_prefixeV2)) {
        // Format v2 : IV aléatoire préfixé au ciphertext
        final bytes = base64Decode(value.substring(_prefixeV2.length));
        if (bytes.length < 32) return value;
        final iv = IV(bytes.sublist(0, 16));
        final ciphertext = Encrypted(bytes.sublist(16));
        return _encrypter!.decrypt(ciphertext, iv: iv);
      }
      // Format legacy : IV fixe dérivé de la clé
      return _encrypter!.decrypt64(value, iv: _ivLegacy!);
    } catch (_) {
      // Données corrompues ou non chiffrées → retourne brut plutôt que crasher
      return value;
    }
  }
}
