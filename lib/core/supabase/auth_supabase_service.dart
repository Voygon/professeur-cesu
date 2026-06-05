import 'package:supabase_flutter/supabase_flutter.dart';

class AuthSupabaseService {
  AuthSupabaseService._();

  static final _client = Supabase.instance.client;

  static User? get currentUser => _client.auth.currentUser;
  static bool get isConnected => currentUser != null;
  static String? get userId => currentUser?.id;

  // ── Email / mot de passe ──────────────────────────────────────────────────

  static Future<void> inscrire(String email, String motDePasse) async {
    await _client.auth.signUp(
      email: email,
      password: motDePasse,
      emailRedirectTo: 'professeurcesu://auth-callback',
    );
  }

  static Future<void> connecter(String email, String motDePasse) async {
    await _client.auth.signInWithPassword(
      email: email,
      password: motDePasse,
    );
  }

  static Future<void> deconnecter() async {
    await _client.auth.signOut();
  }

  static Future<void> reinitialiserMotDePasse(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // ── État de connexion ─────────────────────────────────────────────────────

  static Stream<AuthState> get authStream => _client.auth.onAuthStateChange;
}
