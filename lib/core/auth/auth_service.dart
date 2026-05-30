import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final _auth = LocalAuthentication();

  // Clé utilisée pour stocker le choix "ne plus m'avertir" en local
  static const _keyAvertissementIgnore = 'auth_avertissement_ignore';

  // Vérifie si l'appareil supporte un mécanisme d'authentification
  // (biométrie, PIN, schéma, mot de passe système)
  Future<bool> isAvailable() async {
    final canCheck = await _auth.canCheckBiometrics;
    final isSupported = await _auth.isDeviceSupported();
    return canCheck || isSupported;
  }

  // Déclenche l'authentification système
  // Retourne true si succès, false si échec ou annulation
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Déverrouillez pour accéder à vos données',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      // En cas d'erreur inattendue, on refuse l'accès par sécurité
      return false;
    }
  }

  // Lit la préférence "ne plus m'avertir"
  Future<bool> isAvertissementIgnore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAvertissementIgnore) ?? false;
  }

  // Sauvegarde le choix "ne plus m'avertir"
  Future<void> ignorerAvertissement() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAvertissementIgnore, true);
  }

  // Remet l'avertissement (utile pour les tests ou reset des préférences)
  Future<void> resetAvertissement() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAvertissementIgnore);
  }
}
