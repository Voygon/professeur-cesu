import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/tarifs_provider.dart';
import '../providers/parametres_provider.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/export/export_service.dart';
import '../../../core/export/backup_service.dart';
import '../../../core/import/import_screen.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/supabase/auth_supabase_service.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../core/supabase/sync_service.dart';
import 'tarifs_screen.dart';
import 'cours_annules_screen.dart';

class ParametresScreen extends ConsumerWidget {
  const ParametresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tarifsActifs = ref.watch(tarifsEnCoursProvider).valueOrNull ?? [];
    final espacement = ref.watch(espacementProvider);
    final nbAnnules = ref.watch(nbCoursAnnulesProvider).valueOrNull ?? 0;
    final purgeDelai = ref.watch(purgeAnnulesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
        children: [
          // ── Tarifs ──
          _sectionTitre(context, 'Tarifs'),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.sell_outlined),
              title: const Text('Tarifs'),
              subtitle: Text(
                tarifsActifs.isEmpty
                    ? 'Aucun tarif défini'
                    : tarifsActifs.length == 1
                        ? '1 tarif actif'
                        : '${tarifsActifs.length} tarifs actifs',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TarifsScreen()),
              ),
            ),
          ),

          // ── Planification ──
          const SizedBox(height: 24),
          _sectionTitre(context, 'Planification'),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('Espacement minimum entre cours'),
              subtitle: Text(
                espacement == 0
                    ? 'Aucun espacement'
                    : '$espacement min entre la fin d\'un cours et le début du suivant',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _choisirEspacement(context, ref, espacement),
            ),
          ),

          // ── Notifications ──
          const SizedBox(height: 24),
          _sectionTitre(context, 'Notifications'),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Rappel avant les cours'),
              subtitle: FutureBuilder<int>(
                future: NotificationService.getRappelMinutes(),
                builder: (context, snap) {
                  final minutes = snap.data ?? 30;
                  return Text('$minutes min avant chaque cours');
                },
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _choisirRappel(context),
            ),
          ),

          // ── Synchronisation cloud ──
          const SizedBox(height: 24),
          _sectionTitre(context, 'Synchronisation cloud'),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final supabaseUser = ref.watch(supabaseUserProvider).valueOrNull
                ?? AuthSupabaseService.currentUser;
            final estConnecte = supabaseUser != null;
            return Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(estConnecte
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined),
                    title: const Text('Compte Supabase'),
                    subtitle: Text(estConnecte
                        ? 'Connecté : ${supabaseUser.email}'
                        : 'Non connecté — données locales uniquement'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        _gererConnexionSupabase(context, estConnecte, supabaseUser),
                  ),
                  if (estConnecte) ...[
                    const Divider(height: 1),
                    const _SyncRow(),
                  ],
                ],
              ),
            );
          }),

          // ── Sauvegarde ──
          const SizedBox(height: 24),
          _sectionTitre(context, 'Sauvegarde'),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.save_outlined),
              title: const Text('Exporter une sauvegarde'),
              subtitle: const Text('Un seul fichier — toutes les données'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _exporterSauvegarde(context, ref),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.restore_outlined),
              title: const Text('Restaurer une sauvegarde'),
              subtitle: const Text('Remplace toutes les données actuelles'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _importerSauvegarde(context, ref),
            ),
          ),

          // ── Données ──
          const SizedBox(height: 24),
          _sectionTitre(context, 'Données'),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Exporter mes données'),
              subtitle: const Text('CSV — élèves, payeurs, cours'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _exporter(context, ref),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.upload_outlined),
              title: const Text('Importer des données'),
              subtitle: const Text('CSV — élèves et payeurs'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ImportScreen()),
              ),
            ),
          ),

          // ── Historique ──
          const SizedBox(height: 24),
          _sectionTitre(context, 'Historique'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.cancel_outlined),
                  title: const Text('Cours annulés'),
                  subtitle: Text(
                    nbAnnules == 0
                        ? 'Aucun cours annulé'
                        : nbAnnules == 1
                            ? '1 cours annulé conservé'
                            : '$nbAnnules cours annulés conservés',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const CoursAnnulesScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.auto_delete_outlined),
                  title: const Text('Suppression automatique'),
                  subtitle: Text(_labelPurge(purgeDelai)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      _choisirPurgeAnnules(context, ref, purgeDelai),
                ),
              ],
            ),
          ),

          // ── À propos ──
          const SizedBox(height: 24),
          _sectionTitre(context, 'À propos'),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outlined),
              title: const Text('Maestro'),
              subtitle: const Text('© 2026 Sylvain Nichilo — Tous droits réservés'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'Maestro',
                applicationVersion: '1.0.0',
                applicationLegalese:
                    '© 2026 Sylvain Nichilo\nTous droits réservés\nsylvain.nichilo16@gmail.com',
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionTitre(BuildContext context, String titre) {
    return Text(
      titre,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Future<void> _choisirEspacement(
      BuildContext context, WidgetRef ref, int valeurActuelle) async {
    int selectionne = valeurActuelle;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Espacement minimum'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Durée minimale entre la fin d\'un cours et le début du suivant.',
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [0, 5, 10, 15, 20, 30, 45, 60].map((v) {
                  return ChoiceChip(
                    label: Text(v == 0 ? 'Aucun' : '$v min'),
                    selected: selectionne == v,
                    onSelected: (_) => setDialogState(() => selectionne = v),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                ref
                    .read(espacementProvider.notifier)
                    .setEspacement(selectionne);
                Navigator.pop(context);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _choisirRappel(BuildContext context) async {
    int selectionne = await NotificationService.getRappelMinutes();
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rappel avant les cours'),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [5, 10, 15, 20, 30, 45, 60].map((v) {
              return ChoiceChip(
                label: Text('$v min'),
                selected: selectionne == v,
                onSelected: (_) => setDialogState(() => selectionne = v),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                await NotificationService.setRappelMinutes(selectionne);
                navigator.pop();
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  String _labelPurge(int? jours) {
    if (jours == null) return 'Jamais — cours annulés conservés';
    if (jours == 30) return 'Après 30 jours';
    if (jours == 90) return 'Après 3 mois';
    if (jours == 180) return 'Après 6 mois';
    if (jours == 365) return 'Après 1 an';
    return 'Après $jours jours';
  }

  Future<void> _choisirPurgeAnnules(
      BuildContext context, WidgetRef ref, int? delaiActuel) async {
    int? selectionne = delaiActuel;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Suppression automatique'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Purger automatiquement les cours annulés après :'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Jamais'),
                    selected: selectionne == null,
                    onSelected: (_) =>
                        setDialogState(() => selectionne = null),
                  ),
                  for (final (jours, label) in [
                    (30, '30 jours'),
                    (90, '3 mois'),
                    (180, '6 mois'),
                    (365, '1 an'),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: selectionne == jours,
                      onSelected: (_) =>
                          setDialogState(() => selectionne = jours),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                ref
                    .read(purgeAnnulesProvider.notifier)
                    .setDelai(selectionne);
                Navigator.pop(context);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _gererConnexionSupabase(
    BuildContext context,
    bool estConnecte,
    User? currentUser,
  ) async {
    if (estConnecte) {
      final confirmer = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Se déconnecter'),
          content: Text(
            'Connecté en tant que ${currentUser?.email ?? ''}.\n\n'
            'Vos données locales ne seront pas supprimées.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: const Text('Se déconnecter'),
            ),
          ],
        ),
      );
      if (confirmer == true) {
        await AuthSupabaseService.deconnecter();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Déconnecté de Supabase')),
          );
        }
      }
    } else {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _SupabaseConnexionSheet(),
      );
    }
  }

  Future<void> _exporterSauvegarde(BuildContext context, WidgetRef ref) async {
    try {
      await BackupService.exporterSauvegarde(
        ref.read(databaseProvider),
        ref.read(elevesDaoProvider),
        ref.read(payeursDaoProvider),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur export sauvegarde : $e')),
        );
      }
    }
  }

  Future<void> _importerSauvegarde(BuildContext context, WidgetRef ref) async {
    // Étape 1 — sélection du fichier
    final contenu = await BackupService.choisirFichier();
    if (contenu == null) return;
    if (!context.mounted) return;

    // Étape 2 — confirmation explicite avant destruction
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la restauration'),
        content: const Text(
          'Toutes vos données actuelles seront définitivement supprimées '
          '(élèves, payeurs, cours, tarifs) et remplacées par celles '
          'de la sauvegarde.\n\n'
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Supprimer et restaurer'),
          ),
        ],
      ),
    );
    if (confirmer != true) return;
    if (!context.mounted) return;

    // Étape 3 — restauration
    try {
      await BackupService.importerSauvegarde(contenu, ref.read(databaseProvider));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sauvegarde restaurée avec succès')),
        );
      }
    } on FormatException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur restauration : $e')),
        );
      }
    }
  }

  Future<void> _exporter(BuildContext context, WidgetRef ref) async {
    try {
      final eleves = await ref
          .read(elevesDaoProvider)
          .searchEleves('', inclureArchives: true)
          .first;
      final payeurs =
          await ref.read(payeursDaoProvider).watchPayeursActifs().first;
      final cours = await ref.read(coursDaoProvider).watchCoursValides().first;

      await ExportService.exporterTout(
        eleves: eleves,
        payeurs: payeurs,
        cours: cours,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur export : $e')),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ligne "dernière sync + bouton Synchroniser" dans la carte Supabase
// ─────────────────────────────────────────────────────────────────────────────

class _SyncRow extends ConsumerStatefulWidget {
  const _SyncRow();

  @override
  ConsumerState<_SyncRow> createState() => _SyncRowState();
}

class _SyncRowState extends ConsumerState<_SyncRow> {
  bool _enCours = false;

  Future<void> _sync(BuildContext context) async {
    setState(() => _enCours = true);
    try {
      await SyncService.synchroniser(
        ref.read(databaseProvider),
        ref.read(elevesDaoProvider),
        ref.read(payeursDaoProvider),
      );
      ref.invalidate(derniereSyncProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Synchronisation terminée')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur sync : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  String _formatDate(DateTime d) {
    final j = d.day.toString().padLeft(2, '0');
    final m = d.month.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$j/$m/${d.year} $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final syncAsync = ref.watch(derniereSyncProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: syncAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (date) => Text(
                date == null
                    ? 'Jamais synchronisé'
                    : 'Dernière sync : ${_formatDate(date)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _enCours ? null : () => _sync(context),
            icon: _enCours
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync, size: 18),
            label: const Text('Synchroniser'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet de connexion / inscription Supabase (depuis Paramètres)
// ─────────────────────────────────────────────────────────────────────────────

enum _ConnexionMode { connexion, inscription }

class _SupabaseConnexionSheet extends StatefulWidget {
  const _SupabaseConnexionSheet();

  @override
  State<_SupabaseConnexionSheet> createState() =>
      _SupabaseConnexionSheetState();
}

class _SupabaseConnexionSheetState extends State<_SupabaseConnexionSheet> {
  _ConnexionMode _mode = _ConnexionMode.connexion;
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

  Future<void> _soumettre() async {
    final email = _emailCtrl.text.trim();
    final mdp = _mdpCtrl.text;

    if (email.isEmpty || mdp.isEmpty) {
      setState(() => _erreur = 'Remplissez tous les champs');
      return;
    }
    if (_mode == _ConnexionMode.inscription) {
      if (mdp != _mdpConfirmCtrl.text) {
        setState(() => _erreur = 'Les mots de passe ne correspondent pas');
        return;
      }
      if (mdp.length < 6) {
        setState(
            () => _erreur = 'Le mot de passe doit faire au moins 6 caractères');
        return;
      }
    }

    setState(() {
      _chargement = true;
      _erreur = null;
      _infoMessage = null;
    });

    try {
      if (_mode == _ConnexionMode.connexion) {
        await AuthSupabaseService.connecter(email, mdp);
        if (mounted) Navigator.pop(context);
      } else {
        await AuthSupabaseService.inscrire(email, mdp);
        if (AuthSupabaseService.isConnected) {
          if (mounted) Navigator.pop(context);
        } else {
          setState(() {
            _infoMessage =
                'Un email de confirmation a été envoyé à $email. '
                'Confirmez votre adresse puis connectez-vous.';
            _mode = _ConnexionMode.connexion;
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
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_outlined),
              const SizedBox(width: 12),
              Text(
                'Synchronisation cloud',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          SegmentedButton<_ConnexionMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                  value: _ConnexionMode.connexion,
                  label: Text('Se connecter')),
              ButtonSegment(
                  value: _ConnexionMode.inscription,
                  label: Text('Créer un compte')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() {
              _mode = s.first;
              _erreur = null;
              _infoMessage = null;
            }),
          ),
          const SizedBox(height: 20),

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
                      color: Theme.of(context).colorScheme.primary, size: 18),
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
          const SizedBox(height: 12),

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
                onPressed: () => setState(() => _mdpVisible = !_mdpVisible),
              ),
            ),
            textInputAction: _mode == _ConnexionMode.inscription
                ? TextInputAction.next
                : TextInputAction.done,
            onSubmitted:
                _mode == _ConnexionMode.connexion ? (_) => _soumettre() : null,
            onChanged: (_) => setState(() => _erreur = null),
          ),

          if (_mode == _ConnexionMode.inscription) ...[
            const SizedBox(height: 12),
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

          if (_erreur != null) ...[
            const SizedBox(height: 10),
            Text(
              _erreur!,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),

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
                  : Text(_mode == _ConnexionMode.connexion
                      ? 'Se connecter'
                      : 'Créer mon compte'),
            ),
          ),
        ],
      ),
    );
  }
}
