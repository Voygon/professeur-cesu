import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tarifs_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/export/export_service.dart';
import '../../../core/validators/tarif_validator.dart';

class ParametresScreen extends ConsumerStatefulWidget {
  const ParametresScreen({super.key});

  @override
  ConsumerState<ParametresScreen> createState() => _ParametresScreenState();
}

class _ParametresScreenState extends ConsumerState<ParametresScreen> {
  bool _afficherArchives = false;

  @override
  Widget build(BuildContext context) {
    final tarifsAsync = _afficherArchives
        ? ref.watch(tarifsArchivesProvider)
        : ref.watch(tarifsEnCoursProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_afficherArchives ? 'Tarifs archivés' : 'Tarifs'),
        actions: [
          IconButton(
            tooltip: _afficherArchives ? 'Voir les actifs' : 'Voir les archivés',
            icon: Icon(
              _afficherArchives ? Icons.sell_outlined : Icons.archive_outlined,
            ),
            onPressed: () => setState(() => _afficherArchives = !_afficherArchives),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          tarifsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('Erreur de chargement'),
            data: (tarifs) => tarifs.isEmpty
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_afficherArchives
                          ? 'Aucun tarif archivé'
                          : 'Aucun tarif défini'),
                    ),
                  )
                : Card(
                    child: Column(
                      children: tarifs.map((tarif) {
                        return ListTile(
                          title: Text(
                            '${tarif.duree} minutes',
                            style: _afficherArchives
                                ? TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  )
                                : null,
                          ),
                          subtitle: Text(
                            '${tarif.prix.toStringAsFixed(2)} €',
                            style: _afficherArchives
                                ? TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  )
                                : null,
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'modifier') {
                                _modifierTarif(context, tarif);
                              } else if (action == 'archiver') {
                                _archiverTarif(context, tarif);
                              } else if (action == 'reactiver') {
                                _reactiverTarif(tarif);
                              } else if (action == 'supprimer') {
                                _supprimerTarif(context, tarif);
                              }
                            },
                            itemBuilder: (_) => _afficherArchives
                                ? const [
                                    PopupMenuItem(
                                      value: 'reactiver',
                                      child: Text('Réactiver'),
                                    ),
                                    PopupMenuItem(
                                      value: 'supprimer',
                                      child: Text('Supprimer'),
                                    ),
                                  ]
                                : const [
                                    PopupMenuItem(
                                      value: 'modifier',
                                      child: Text('Modifier'),
                                    ),
                                    PopupMenuItem(
                                      value: 'archiver',
                                      child: Text('Archiver'),
                                    ),
                                    PopupMenuItem(
                                      value: 'supprimer',
                                      child: Text('Supprimer'),
                                    ),
                                  ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          // ── Données ──
          const SizedBox(height: 24),
          Text(
            'Données',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
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
        ],
      ),
      floatingActionButton: _afficherArchives
          ? null
          : FloatingActionButton(
              onPressed: () => _afficherDialogue(context, null),
              child: const Icon(Icons.add),
            ),
    );
  }

  Future<void> _modifierTarif(BuildContext context, Tarif tarif) async {
    await _afficherDialogue(context, tarif);
  }

  Future<void> _reactiverTarif(Tarif tarif) async {
    await ref.read(tarifsDaoProvider).reactiverTarif(tarif.tarifsId);
  }

  Future<void> _archiverTarif(BuildContext context, Tarif tarif) async {
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Archiver ce tarif ?'),
        content: Text(
            'Le tarif ${tarif.duree} min sera fermé aujourd\'hui et n\'apparaîtra plus dans la liste active.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
    if (confirmer == true && context.mounted) {
      await ref.read(tarifsDaoProvider).fermerTarif(tarif.tarifsId);
    }
  }

  Future<void> _supprimerTarif(BuildContext context, Tarif tarif) async {
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce tarif ?'),
        content: Text('Le tarif ${tarif.duree} min sera supprimé définitivement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmer == true && context.mounted) {
      await ref.read(tarifsDaoProvider).deleteTarif(tarif.tarifsId);
    }
  }

  Future<void> _afficherDialogue(BuildContext context, Tarif? tarifActuel) async {
    final dureeCtrl = TextEditingController(
      text: tarifActuel?.duree.toString() ?? '',
    );
    final prixCtrl = TextEditingController(
      text: tarifActuel?.prix.toStringAsFixed(2) ?? '',
    );
    DateTime dateDebut = tarifActuel?.dateDebut ?? DateTime.now();
    DateTime? dateFin = tarifActuel?.dateFin;
    final formKey = GlobalKey<FormState>();

    final confirmer = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(tarifActuel != null ? 'Modifier le tarif' : 'Nouveau tarif'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: dureeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Durée (minutes) *',
                      suffixText: 'min',
                    ),
                    enabled: tarifActuel == null,
                    validator: (v) =>
                        TarifValidator.validateDuree(int.tryParse(v ?? '')),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: prixCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Prix *',
                      suffixText: '€',
                    ),
                    validator: (v) => TarifValidator.validatePrix(
                        double.tryParse(v?.replaceAll(',', '.') ?? '')),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date de début'),
                    subtitle: Text(_formatDate(dateDebut)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dateDebut,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => dateDebut = picked);
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date de fin'),
                    subtitle: Text(
                        dateFin != null ? _formatDate(dateFin!) : 'Aucune'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dateFin != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: 'Effacer la date de fin',
                            onPressed: () =>
                                setDialogState(() => dateFin = null),
                          ),
                        const Icon(Icons.calendar_today_outlined),
                      ],
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dateFin ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => dateFin = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (confirmer == true && context.mounted) {
      final duree = int.tryParse(dureeCtrl.text);
      final prix = double.tryParse(prixCtrl.text.replaceAll(',', '.'));
      if (duree == null || prix == null) return;

      if (tarifActuel != null) {
        await ref.read(tarifsDaoProvider).updateTarif(TarifsCompanion(
              tarifsId: Value(tarifActuel.tarifsId),
              duree: Value(duree),
              prix: Value(prix),
              dateDebut: Value(dateDebut),
              dateFin: Value(dateFin),
            ));
      } else {
        await ref
            .read(tarifsDaoProvider)
            .creerNouveauTarif(duree, prix, dateDebut);
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
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
