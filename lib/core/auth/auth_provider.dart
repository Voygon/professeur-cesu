import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';

// Les 4 états possibles de l'authentification
enum AuthState {
  initial, // App vient de démarrer
  authentifie, // Accès accordé
  verrouille, // Auth requise, pas encore faite
  nonDisponible, // Pas de verrouillage système sur ce téléphone
}

class AuthNotifier extends StateNotifier<AuthState> {
  // super(AuthState.initial) définit l'état de départ
  AuthNotifier(this._authService) : super(AuthState.initial);

  final AuthService _authService;

  // Heure à laquelle l'app est passée en arrière-plan
  // Nullable car au démarrage elle n'est pas encore définie
  DateTime? _heureArrierePlan;

  // Durée avant de re-demander l'auth après mise en arrière-plan
  static const _delaiVerrouillage = Duration(minutes: 5);

  Future<void> verifier() async {
    // Vérifie si l'appareil a un mécanisme d'auth (biométrie, PIN, schéma)
    final disponible = await _authService.isAvailable();

    if (!disponible) {
      // Si l'utilisateur avait coché "ne plus m'avertir", on laisse passer
      final ignore = await _authService.isAvertissementIgnore();
      state = ignore ? AuthState.authentifie : AuthState.nonDisponible;
      return;
    }

    // Déclenche la demande d'authentification
    final succes = await _authService.authenticate();

    // Met à jour l'état selon le résultat
    state = succes ? AuthState.authentifie : AuthState.verrouille;
  }

  void mettreEnArrierePlan() {
    _heureArrierePlan = DateTime.now();
  }

  Future<void> revenirAuPremierPlan() async {
    // Si l'app n'est pas encore authentifiée, on force la vérification
    if (state != AuthState.authentifie) {
      await verifier();
      return;
    }

    // Si on n'a pas noté d'heure de mise en arrière-plan, pas de re-demande
    if (_heureArrierePlan == null) return;

    // Calcule combien de temps l'app est restée en arrière-plan
    final tempsEcoule = DateTime.now().difference(_heureArrierePlan!);

    // Si plus de 5 minutes → on re-demande l'auth
    if (tempsEcoule > _delaiVerrouillage) {
      await verifier();
    }

    // Réinitialise l'heure — on repart à zéro pour le prochain passage
    _heureArrierePlan = null;
  }
}

// Provider de l'AuthService — instance unique partagée
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Provider du AuthNotifier — gère l'état de l'auth
// StateNotifierProvider expose à la fois le notifier (pour appeler les méthodes)
// et l'état (pour lire AuthState)
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});
