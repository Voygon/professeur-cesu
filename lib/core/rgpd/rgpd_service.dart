import 'package:shared_preferences/shared_preferences.dart';

class RgpdService {
  RgpdService._();

  static const _keyConsentement = 'rgpd_consentement_accepte';
  static const _keyDateAcceptation = 'rgpd_date_acceptation';
  static const _keyOnboardingSupabase = 'supabase_onboarding_fait';

  static Future<bool> isConsentementAccepte() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyConsentement) ?? false;
  }

  static Future<void> accepterConsentement() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyConsentement, true);
    await prefs.setString(
        _keyDateAcceptation, DateTime.now().toIso8601String());
  }

  static Future<DateTime?> dateAcceptation() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyDateAcceptation);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  static Future<bool> isOnboardingSupabaseFait() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingSupabase) ?? false;
  }

  static Future<void> marquerOnboardingSupabaseFait() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingSupabase, true);
  }

  static Future<void> resetConsentement() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyConsentement);
    await prefs.remove(_keyDateAcceptation);
  }
}
