import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../shared/models/enums.dart';
import '../providers/eleves_provider.dart';
import 'ajouter_eleve_sheet.dart';

class FicheEleveScreen extends ConsumerWidget {
  final int eleveId;

  const FicheEleveScreen({
    super.key,
    required this.eleveId,
  });

  Widget _infoTile(String label, String? valeur, {IconData? icon}) {
    return ListTile(
      leading: icon != null ? Icon(icon) : null,
      title:
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(valeur?.isNotEmpty == true ? valeur! : 'Non renseigné'),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _sectionTitre(BuildContext context, String titre) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        titre,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eleveAvecPayeurAsync = ref.watch(eleveAvecPayeurProvider(eleveId));
    final eleveVif = eleveAvecPayeurAsync.valueOrNull?.eleve;

    return Scaffold(
      appBar: AppBar(
        title: Text(eleveVif != null
            ? '${eleveVif.prenom} ${eleveVif.nom}'
            : 'Chargement...'),
      ),
      body: eleveVif == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Informations personnelles ──
                _sectionTitre(context, 'Informations'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _infoTile('Prénom', eleveVif.prenom,
                            icon: Icons.person_outlined),
                        _infoTile('Nom', eleveVif.nom,
                            icon: Icons.badge_outlined),
                        _infoTile('Adresse', eleveVif.adress,
                            icon: Icons.home_outlined),
                        _infoTile('Téléphone', eleveVif.telephone,
                            icon: Icons.phone_outlined),
                      ],
                    ),
                  ),
                ),

                // ── Planning ──
                _sectionTitre(context, 'Planning'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _infoTile(
                          'Type de cours',
                          eleveVif.hebdo ? 'Hebdomadaire' : 'Ponctuel',
                          icon: Icons.calendar_today_outlined,
                        ),
                        if (eleveVif.hebdo && eleveVif.jourSemaine != null)
                          _infoTile(
                            'Jour',
                            () {
                              final j =
                                  JourSemaine.fromValeur(eleveVif.jourSemaine!);
                              return j.name[0].toUpperCase() +
                                  j.name.substring(1);
                            }(),
                            icon: Icons.today_outlined,
                          ),
                        if (eleveVif.heureDebut != null)
                          _infoTile('Heure', eleveVif.heureDebut,
                              icon: Icons.access_time_outlined),
                      ],
                    ),
                  ),
                ),

                // ── Payeur ──
                _sectionTitre(context, 'Payeur'),
                eleveAvecPayeurAsync.when(
                  loading: () => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (_, __) => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Impossible de charger le payeur'),
                    ),
                  ),
                  data: (eleveAvecPayeur) {
                    final payeur = eleveAvecPayeur?.payeur;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            _infoTile(
                              'Nom',
                              payeur != null
                                  ? '${payeur.prenom} ${payeur.nom}'
                                  : null,
                              icon: Icons.person_outlined,
                            ),
                            _infoTile('Téléphone', payeur?.telephone,
                                icon: Icons.phone_outlined),
                            _infoTile(
                              'CESU+',
                              payeur?.cesuPlus == true ? 'Oui' : 'Non',
                              icon: Icons.credit_card_outlined,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                // ── Actions ──
                SafeArea(
                  child: Column(
                    children: [
                      if (eleveVif.actif) ...[
                        OutlinedButton.icon(
                          onPressed: () {
                            final ep = eleveAvecPayeurAsync.valueOrNull;
                            if (ep == null) return;
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) =>
                                  AjouterEleveSheet(eleveAvecPayeur: ep),
                            );
                          },
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Modifier'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final confirmer = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Archiver l\'élève ?'),
                                content: const Text(
                                  'L\'élève n\'apparaîtra plus dans la liste active. '
                                  'Ses cours et historique sont conservés.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Annuler'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          Theme.of(context).colorScheme.error,
                                    ),
                                    child: const Text('Archiver'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmer == true && context.mounted) {
                              await ref
                                  .read(elevesDaoProvider)
                                  .archiverEleve(eleveId);
                              if (context.mounted) Navigator.of(context).pop();
                            }
                          },
                          icon: const Icon(Icons.archive_outlined),
                          label: const Text('Archiver'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ] else
                        OutlinedButton.icon(
                          onPressed: () async {
                            await ref
                                .read(elevesDaoProvider)
                                .reactiverEleve(eleveId);
                            if (context.mounted) Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.unarchive_outlined),
                          label: const Text('Réactiver'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
