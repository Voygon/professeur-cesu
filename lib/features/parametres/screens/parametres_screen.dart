import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tarifs_provider.dart';
import '../providers/parametres_provider.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/export/export_service.dart';
import '../../../core/export/backup_service.dart';
import '../../../core/import/import_screen.dart';
import 'tarifs_screen.dart';

class ParametresScreen extends ConsumerWidget {
  const ParametresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tarifsActifs = ref.watch(tarifsEnCoursProvider).valueOrNull ?? [];
    final espacement = ref.watch(espacementProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
