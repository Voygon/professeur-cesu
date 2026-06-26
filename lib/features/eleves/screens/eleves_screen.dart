import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../providers/eleves_provider.dart';
import 'ajouter_eleve_sheet.dart';
import '../../../shared/models/enums.dart';
import '../../../core/validators/conflit_horaire.dart';
import '../../parametres/providers/parametres_provider.dart';
import '../../../shared/utils/tri_horaire_hebdo.dart';
import 'fiche_eleve_screen.dart';

enum _TriEleves { prenom, horaire }

class ElevesScreen extends ConsumerStatefulWidget {
  const ElevesScreen({super.key});

  @override
  ConsumerState<ElevesScreen> createState() => _ElevesScreenState();
}

class _ElevesScreenState extends ConsumerState<ElevesScreen> {
  bool _afficherArchives = false;
  _TriEleves _tri = _TriEleves.prenom;

  static bool _aCreneauHebdo(Eleve e) => e.hebdo && e.jourSemaine != null;

  List<Eleve> _trierEleves(List<Eleve> source) {
    switch (_tri) {
      case _TriEleves.prenom:
        final copie = [...source];
        copie.sort((a, b) => a.prenom.compareTo(b.prenom));
        return copie;
      case _TriEleves.horaire:
        return trierParJourHebdo(
          source,
          aCreneauHebdo: _aCreneauHebdo,
          jourSemaine: (e) => e.jourSemaine!,
          heureDebut: (e) => e.heureDebut,
          compareSansCreneau: (a, b) => a.prenom.compareTo(b.prenom),
        );
    }
  }

  // Retourne une liste plate : String = séparateur de jour, Eleve = carte.
  // Uniquement utilisé en mode horaire.
  List<Object> _buildListItems(List<Eleve> eleves) {
    return avecSeparateursJour(
      eleves,
      aCreneauHebdo: _aCreneauHebdo,
      jourSemaine: (e) => e.jourSemaine!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final elevesAsync = _afficherArchives
        ? ref.watch(elevesArchivesProvider)
        : ref.watch(elevesActifsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_afficherArchives ? 'Élèves archivés' : 'Élèves'),
        actions: [
          IconButton(
            tooltip:
                _afficherArchives ? 'Voir les actifs' : 'Voir les archivés',
            icon: Icon(
              _afficherArchives ? Icons.person : Icons.archive_outlined,
            ),
            onPressed: () =>
                setState(() => _afficherArchives = !_afficherArchives),
          ),
        ],
      ),
      body: elevesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erreur : $err')),
        data: (listeEleves) {
          final espacement = ref.watch(espacementProvider);
          final elevesEnConflit = ConflitHoraire.detecterConflitsElevesHebdo(
            listeEleves,
            espacement: espacement,
          );

          if (listeEleves.isEmpty) {
            return Center(
              child: Text(
                  _afficherArchives ? 'Aucun élève archivé' : 'Aucun élève'),
            );
          }

          final eleves = _trierEleves(listeEleves);

          return Column(
            children: [
              // ── Sélecteur de tri ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SegmentedButton<_TriEleves>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: _TriEleves.prenom,
                      label: Text('Prénom'),
                      icon: Icon(Icons.sort_by_alpha_outlined),
                    ),
                    ButtonSegment(
                      value: _TriEleves.horaire,
                      label: Text('Horaire'),
                      icon: Icon(Icons.schedule_outlined),
                    ),
                  ],
                  selected: {_tri},
                  onSelectionChanged: (s) =>
                      setState(() => _tri = s.first),
                ),
              ),
              // ── Liste ──
              Expanded(
                child: Builder(builder: (context) {
                  final items = _tri == _TriEleves.horaire
                      ? _buildListItems(eleves)
                      : eleves;

                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];

                      // Séparateur de jour (mode horaire uniquement)
                      if (item is String) {
                        return Padding(
                          key: ValueKey('sep_$item'),
                          padding: EdgeInsets.only(
                            top: index == 0 ? 0 : 16,
                            bottom: 6,
                          ),
                          child: Text(
                            item,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        );
                      }

                      final eleve = item as Eleve;
                      final enConflit =
                          elevesEnConflit.contains(eleve.elevesId);
                      final isLast = index == items.length - 1;
                      final nextIsSeparator =
                          !isLast && items[index + 1] is String;

                      return Padding(
                        key: ValueKey(eleve.elevesId),
                        padding: EdgeInsets.only(
                          bottom: (isLast || nextIsSeparator) ? 0 : 8,
                        ),
                        child: Card(
                          shape: enConflit
                              ? RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color:
                                        Theme.of(context).colorScheme.error,
                                    width: 2,
                                  ),
                                )
                              : null,
                          child: ListTile(
                            title: Row(
                              children: [
                                Text('${eleve.prenom} ${eleve.nom}'),
                                if (enConflit) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.schedule,
                                    size: 16,
                                    color:
                                        Theme.of(context).colorScheme.error,
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(() {
                              final base = eleve.hebdo &&
                                      eleve.jourSemaine != null
                                  ? 'Hebdo — ${JourSemaine.fromValeur(eleve.jourSemaine!).name[0].toUpperCase()}${JourSemaine.fromValeur(eleve.jourSemaine!).name.substring(1)} à ${eleve.heureDebut}'
                                  : 'Cours ponctuels';
                              return eleve.dureeCours != null
                                  ? '$base · ${eleve.dureeCours} min'
                                  : base;
                            }()),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    FicheEleveScreen(eleveId: eleve.elevesId),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _afficherArchives
          ? null
          : FloatingActionButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => const AjouterEleveSheet(),
              ),
              child: const Icon(Icons.add),
            ),
    );
  }
}
