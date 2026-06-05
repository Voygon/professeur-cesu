import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../rgpd/rgpd_service.dart';
import 'auth_supabase_service.dart';

enum _Mode { connexion, inscription }

class SupabaseOnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SupabaseOnboardingScreen({super.key, required this.onComplete});

  @override
  State<SupabaseOnboardingScreen> createState() =>
      _SupabaseOnboardingScreenState();
}

class _SupabaseOnboardingScreenState extends State<SupabaseOnboardingScreen> {
  _Mode _mode = _Mode.connexion;
  final _emailCtrl = TextEditingController();
  final _mdpCtrl = TextEditingController();
  final _mdpConfirmCtrl = TextEditingController();
  bool _chargement = false;
  bool _mdpVisible = false;
  String? _erreur;
  String? _infoMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _mdpCtrl.dispose();
    _mdpConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _continuerSansCompte() async {
    await RgpdService.marquerOnboardingSupabaseFait();
    widget.onComplete();
  }

  Future<void> _soumettre() async {
    final email = _emailCtrl.text.trim();
    final mdp = _mdpCtrl.text;

    if (email.isEmpty || mdp.isEmpty) {
      setState(() => _erreur = 'Remplissez tous les champs');
      return;
    }
    if (_mode == _Mode.inscription) {
      if (mdp != _mdpConfirmCtrl.text) {
        setState(() => _erreur = 'Les mots de passe ne correspondent pas');
        return;
      }
      if (mdp.length < 6) {
        setState(() => _erreur = 'Le mot de passe doit faire au moins 6 caractères');
        return;
      }
    }

    setState(() {
      _chargement = true;
      _erreur = null;
      _infoMessage = null;
    });
    try {
      if (_mode == _Mode.connexion) {
        await AuthSupabaseService.connecter(email, mdp);
        await RgpdService.marquerOnboardingSupabaseFait();
        widget.onComplete();
      } else {
        await AuthSupabaseService.inscrire(email, mdp);
        if (AuthSupabaseService.isConnected) {
          // Confirmation email désactivée — session ouverte directement
          await RgpdService.marquerOnboardingSupabaseFait();
          widget.onComplete();
        } else {
          // Email de confirmation envoyé — demander de vérifier
          setState(() {
            _infoMessage =
                'Un email de confirmation a été envoyé à $email. '
                'Confirmez votre adresse puis connectez-vous.';
            _mode = _Mode.connexion;
          });
        }
      }
    } on AuthException catch (e) {
      setState(() => _erreur = _traduire(e.message));
    } catch (_) {
      setState(() => _erreur = 'Erreur réseau — vérifiez votre connexion');
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  String _traduire(String msg) {
    if (msg.contains('Invalid login credentials')) {
      return 'Email ou mot de passe incorrect';
    }
    if (msg.contains('Email not confirmed')) {
      return 'Confirmez votre email avant de vous connecter';
    }
    if (msg.contains('User already registered')) {
      return 'Un compte existe déjà avec cet email';
    }
    if (msg.contains('Password should be at least')) {
      return 'Le mot de passe doit faire au moins 6 caractères';
    }
    if (msg.contains('Unable to validate email')) {
      return 'Adresse email invalide';
    }
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const Icon(Icons.cloud_outlined,
                  size: 48, color: Color(0xFF1565C0)),
              const SizedBox(height: 16),
              Text(
                'Synchronisez vos données',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Créez un compte pour accéder à vos données sur plusieurs '
                'appareils et les sauvegarder automatiquement. '
                'Vous pouvez continuer sans compte si vous préférez.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),

              // ── Connexion / Inscription ──────────────────────────────
              SegmentedButton<_Mode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: _Mode.connexion, label: Text('Se connecter')),
                  ButtonSegment(
                      value: _Mode.inscription,
                      label: Text('Créer un compte')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() {
                  _mode = s.first;
                  _erreur = null;
                  _infoMessage = null;
                }),
              ),
              const SizedBox(height: 24),

              // ── Message d'info (ex: confirmation email) ──────────────
              if (_infoMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                          size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _infoMessage!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Email ────────────────────────────────────────────────
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                onChanged: (_) => setState(() => _erreur = null),
              ),
              const SizedBox(height: 16),

              // ── Mot de passe ─────────────────────────────────────────
              TextField(
                controller: _mdpCtrl,
                obscureText: !_mdpVisible,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_mdpVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _mdpVisible = !_mdpVisible),
                  ),
                ),
                textInputAction: _mode == _Mode.inscription
                    ? TextInputAction.next
                    : TextInputAction.done,
                onSubmitted:
                    _mode == _Mode.connexion ? (_) => _soumettre() : null,
                onChanged: (_) => setState(() => _erreur = null),
              ),

              // ── Confirmation (inscription) ───────────────────────────
              if (_mode == _Mode.inscription) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _mdpConfirmCtrl,
                  obscureText: !_mdpVisible,
                  decoration: const InputDecoration(
                    labelText: 'Confirmer le mot de passe',
                    prefixIcon: Icon(Icons.lock_outlined),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _soumettre(),
                  onChanged: (_) => setState(() => _erreur = null),
                ),
              ],

              // ── Erreur ───────────────────────────────────────────────
              if (_erreur != null) ...[
                const SizedBox(height: 12),
                Text(
                  _erreur!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),

              // ── Bouton principal ─────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _chargement ? null : _soumettre,
                  child: _chargement
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_mode == _Mode.connexion
                          ? 'Se connecter'
                          : 'Créer mon compte'),
                ),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),

              // ── Continuer sans compte ────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _chargement ? null : _continuerSansCompte,
                  child: const Text('Continuer sans compte'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Vos données resteront uniquement sur cet appareil',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
