import 'package:shared_preferences/shared_preferences.dart';

class RgpdService {
  RgpdService._();

  static const _keyConsentement = 'rgpd_consentement_accepte';

  static Future<bool> isConsentementAccepte() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyConsentement) ?? false;
  }

  static Future<void> accepterConsentement() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyConsentement, true);
  }

  static Future<void> resetConsentement() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyConsentement);
  }
}
