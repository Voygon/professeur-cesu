import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:math';

class EncryptionService {
  EncryptionService._();

  static const _keyChiffrement = 'field_encryption_key';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Encrypter? _encrypter;
  static IV? _iv;

  // Initialise le service — à appeler une fois au démarrage
  static Future<void> init() async {
    String? keyBase64 = await _storage.read(key: _keyChiffrement);

    if (keyBase64 == null) {
      // Première installation — génère une clé AES 256 bits
      final keyBytes =
          List<int>.generate(32, (_) => Random.secure().nextInt(256));
      keyBase64 = base64Encode(keyBytes);
      await _storage.write(key: _keyChiffrement, value: keyBase64);
    }

    final key = Key(base64Decode(keyBase64));
    // IV fixe dérivé de la clé — déterministe pour la même clé
    _iv = IV(base64Decode(keyBase64).sublist(0, 16));
    _encrypter = Encrypter(AES(key, mode: AESMode.cbc));
  }

  // Chiffre une valeur — retourne null si value est null
  static String? chiffrer(String? value) {
    if (value == null || value.isEmpty) return value;
    assert(_encrypter != null, 'EncryptionService non initialisé');
    return _encrypter!.encrypt(value, iv: _iv!).base64;
  }

  // Déchiffre une valeur — retourne null si value est null
  static String? dechiffrer(String? value) {
    if (value == null || value.isEmpty) return value;
    assert(_encrypter != null, 'EncryptionService non initialisé');
    try {
      return _encrypter!.decrypt64(value, iv: _iv!);
    } catch (e) {
      // Si le déchiffrement échoue (données corrompues ou non chiffrées)
      // on retourne la valeur brute plutôt que de crasher
      return value;
    }
  }
}
