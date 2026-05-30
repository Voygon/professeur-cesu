import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/auth/auth_provider.dart';
import 'core/security/encryption_service.dart';
import 'core/database/database_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/navigation/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EncryptionService.init();
  runApp(const ProviderScope(child: ProfesseurCesuApp()));
}

class ProfesseurCesuApp extends ConsumerWidget {
  const ProfesseurCesuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(databaseProvider);
    return MaterialApp(
      title: 'Professeur CESU',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const _AppGuard(),
    );
  }
}

/// Widget qui surveille le cycle de vie de l'app ET l'état d'auth.
/// C'est lui qui décide quel écran afficher.
///
/// On utilise ConsumerStatefulWidget (pas ConsumerWidget) parce qu'on a
/// besoin de WidgetsBindingObserver — qui nécessite un State avec
/// initState() et dispose().
class _AppGuard extends ConsumerStatefulWidget {
  const _AppGuard();

  @override
  ConsumerState<_AppGuard> createState() => _AppGuardState();
}

class _AppGuardState extends ConsumerState<_AppGuard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Enregistre ce widget comme observateur du cycle de vie
    WidgetsBinding.instance.addObserver(this);
    // Lance la vérification auth au démarrage
    // addPostFrameCallback garantit que le widget est monté avant d'appeler ref
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).verifier();
    });
  }

  @override
  void dispose() {
    // Important : se désenregistrer pour éviter les fuites mémoire
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Appelé automatiquement par Flutter quand l'état de l'app change
    switch (state) {
      case AppLifecycleState.paused:
        // App en arrière-plan → on note l'heure
        ref.read(authProvider.notifier).mettreEnArrierePlan();
        break;
      case AppLifecycleState.resumed:
        // App revenue au premier plan → on vérifie si re-auth nécessaire
        ref.read(authProvider.notifier).revenirAuPremierPlan();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Écoute l'état d'auth — se reconstruit automatiquement si ça change
    final authState = ref.watch(authProvider);

    switch (authState) {
      case AuthState.initial:
        // Auth en cours de vérification → écran de chargement
        return const _EcranChargement();

      case AuthState.authentifie:
        // Auth validée → écran principal
        return const MainNavigation();

      case AuthState.verrouille:
        // Auth échouée ou annulée → écran de verrouillage
        return const _EcranVerrouille();

      case AuthState.nonDisponible:
        // Pas de verrouillage système → écran d'avertissement
        return const _EcranAvertissement();
    }
  }
}

/// Écran affiché pendant la vérification de l'auth
class _EcranChargement extends StatelessWidget {
  const _EcranChargement();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Écran affiché quand l'auth a échoué ou été annulée
class _EcranVerrouille extends ConsumerWidget {
  const _EcranVerrouille();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 72, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Application verrouillée',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Authentifiez-vous pour accéder à vos données'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.read(authProvider.notifier).verifier(),
              icon: const Icon(Icons.fingerprint),
              label: const Text('Déverrouiller'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Écran affiché quand le téléphone n'a pas de verrouillage configuré
class _EcranAvertissement extends ConsumerWidget {
  const _EcranAvertissement();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber, size: 72, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Sécurité recommandée',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Votre téléphone n\'a pas de verrouillage configuré. '
              'Vos données (élèves, paiements) ne sont pas protégées '
              'si quelqu\'un prend votre téléphone.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Case à cocher "ne plus m'avertir"
            _CaseNePlusAvertir(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Pour l'instant, on laisse passer vers l'accueil
                // Le vrai accueil sera branché quand on aura la navigation
                ref.read(authProvider.notifier).state = AuthState.authentifie;
              },
              child: const Text('Continuer quand même'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget séparé pour la case à cocher — a son propre état local
class _CaseNePlusAvertir extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CaseNePlusAvertir> createState() => _CaseNePlusAvertirState();
}

class _CaseNePlusAvertirState extends ConsumerState<_CaseNePlusAvertir> {
  bool _coche = false;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: const Text('Ne plus m\'avertir'),
      value: _coche,
      onChanged: (value) async {
        setState(() => _coche = value ?? false);
        if (_coche) {
          // Sauvegarde le choix dans SharedPreferences
          await ref.read(authServiceProvider).ignorerAvertissement();
        }
      },
    );
  }
}
