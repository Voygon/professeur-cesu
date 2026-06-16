import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../eleves/providers/eleves_provider.dart';
import '../providers/paiements_provider.dart';
import 'detail_cours_eleve_mois_screen.dart';

String _nomMoisCapitalize(int mois, int annee) {
  const noms = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];
  return '${noms[mois - 1]} $annee';
}

enum _TriDetailMois { alphabetique, dateHeure }

class DetailMoisScreen extends ConsumerStatefulWidget {
  final int mois;
  final int annee;

  const DetailMoisScreen({
    super.key,
    required this.mois,
    required this.annee,
  });

  @override
  ConsumerState<DetailMoisScreen> createState() => _DetailMoisScreenState();
}

class _DetailMoisScreenState extends ConsumerState<DetailMoisScreen> {
  _TriDetailMois _tri = _TriDetailMois.alphabetique;

  static const _jours = [
    'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche',
  ];

  int _heureEnMinutes(String? h) {
    if (h == null) return 9999;
    final p = h.split(':');
    if (p.length != 2) return 9999;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  // Trie les eleveIds par jour hebdo puis heure de début
  List<int> _trierParHoraire(List<int> ids, Map<int, Eleve> elevesMap) {
    final copie = [...ids];
    copie.sort((a, b) {
      final ea = elevesMap[a];
      final eb = elevesMap[b];
      final aHebdo = ea != null && ea.hebdo && ea.jourSemaine != null;
      final bHebdo = eb != null && eb.hebdo && eb.jourSemaine != null;
      if (!aHebdo && !bHebdo) {
        if (ea == null && eb == null) return 0;
        if (ea == null) return 1;
        if (eb == null) return -1;
        final cmp = ea.prenom.compareTo(eb.prenom);
        return cmp != 0 ? cmp : ea.nom.compareTo(eb.nom);
      }
      if (!aHebdo) return 1;
      if (!bHebdo) return -1;
      final jourCmp = ea.jourSemaine!.compareTo(eb.jourSemaine!);
      if (jourCmp != 0) return jourCmp;
      return _heureEnMinutes(ea.heureDebut)
          .compareTo(_heureEnMinutes(eb.heureDebut));
    });
    return copie;
  }

  // Retourne une liste plate : String = séparateur de jour, int = eleveId
  List<Object> _buildItemsParJourHebdo(
      List<int> elevesIds, Map<int, Eleve> elevesMap) {
    final items = <Object>[];
    int? currentJour;
    bool sansCreneau = false;

    for (final eleveId in elevesIds) {
      final eleve = elevesMap[eleveId];
      final hasHebdo = eleve != null && eleve.hebdo && eleve.jourSemaine != null;

      if (hasHebdo) {
        if (eleve.jourSemaine != currentJour) {
          currentJour = eleve.jourSemaine;
          items.add(_jours[eleve.jourSemaine! - 1]);
        }
      } else {
        if (!sansCreneau) {
          sansCreneau = true;
          items.add('Sans créneau fixe');
        }
      }
      items.add(eleveId);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final coursAsync =
        ref.watch(coursParMoisProvider((mois: widget.mois, annee: widget.annee)));
    final elevesMap = <int, Eleve>{
      for (final e in ref.watch(elevesActifsProvider).valueOrNull ?? [])
        e.elevesId: e,
    };

    return Scaffold(
      appBar: AppBar(title: Text(_nomMoisCapitalize(widget.mois, widget.annee))),
      body: coursAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Erreur de chargement')),
        data: (coursList) {
          if (coursList.isEmpty) {
            return const Center(child: Text('Aucun cours pour ce mois'));
          }

          // Groupe par élève
          final Map<int, List<Cour>> parEleve = {};
          for (final c in coursList) {
            parEleve.putIfAbsent(c.elevesId, () => []).add(c);
          }

          // Tri des groupes
          var elevesIds = parEleve.keys.toList();
          switch (_tri) {
            case _TriDetailMois.alphabetique:
              elevesIds.sort((a, b) {
                final ea = elevesMap[a];
                final eb = elevesMap[b];
                if (ea == null && eb == null) return 0;
                if (ea == null) return 1;
                if (eb == null) return -1;
                final cmp = ea.prenom.compareTo(eb.prenom);
                return cmp != 0 ? cmp : ea.nom.compareTo(eb.nom);
              });
            case _TriDetailMois.dateHeure:
              elevesIds = _trierParHoraire(elevesIds, elevesMap);
          }

          return Column(
            children: [
              // ── Sélecteur de tri ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SegmentedButton<_TriDetailMois>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: _TriDetailMois.alphabetique,
                      label: Text('Prénom'),
                      icon: Icon(Icons.sort_by_alpha_outlined),
                    ),
                    ButtonSegment(
                      value: _TriDetailMois.dateHeure,
                      label: Text('Horaire'),
                      icon: Icon(Icons.schedule_outlined),
                    ),
                  ],
                  selected: {_tri},
                  onSelectionChanged: (s) => setState(() => _tri = s.first),
                ),
              ),
              // ── Liste ──
              Expanded(
                child: Builder(builder: (context) {
                  final items = _tri == _TriDetailMois.dateHeure
                      ? _buildItemsParJourHebdo(elevesIds, elevesMap)
                      : List<Object>.from(elevesIds);

                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                        16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];

                      // Séparateur de jour (mode horaire uniquement)
                      if (item is String) {
                        return Padding(
                          padding: EdgeInsets.only(
                            top: i == 0 ? 0 : 16,
                            bottom: 6,
                          ),
                          child: Text(
                            item,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        );
                      }

                      final eleveId = item as int;
                      final coursDuEleve = parEleve[eleveId]!;
                      final eleveAsync = ref.watch(eleveParIdProvider(eleveId));
                      final isLast = i == items.length - 1;
                      final nextIsSeparator = !isLast && items[i + 1] is String;

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: (isLast || nextIsSeparator) ? 0 : 8,
                        ),
                        child: eleveAsync.when(
                          loading: () => const SizedBox(height: 72),
                          error: (_, __) => const SizedBox(),
                          data: (eleve) {
                            if (eleve == null) return const SizedBox();
                            final total = coursDuEleve.fold<double>(
                                0, (s, c) => s + (c.montant ?? 0));
                            final paye = coursDuEleve.fold<double>(0,
                                (s, c) => s + (c.paye ? (c.montant ?? 0) : 0));
                            final toutPaye = coursDuEleve.every((c) => c.paye);

                            final montantEspeces = coursDuEleve.fold<double>(
                                0,
                                (s, c) => s +
                                    (c.paiementEspeces ? (c.montant ?? 0) : 0));
                            final montantCesu = total - montantEspeces;
                            final hasEspeces = montantEspeces > 0;
                            final hasCesu = montantCesu > 0;

                            return Card(
                              child: ListTile(
                                title: Text('${eleve.prenom} ${eleve.nom}'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${coursDuEleve.length} cours · ${total.toStringAsFixed(2)} €',
                                    ),
                                    if (hasEspeces || hasCesu) ...[
                                      const SizedBox(height: 2),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          if (hasCesu)
                                            _PaiementBadge(
                                              label:
                                                  'CESU+ ${montantCesu.toStringAsFixed(2)} €',
                                              icon: Icons.credit_card_outlined,
                                              color: Colors.blue,
                                            ),
                                          if (hasEspeces)
                                            _PaiementBadge(
                                              label:
                                                  'Espèces ${montantEspeces.toStringAsFixed(2)} €',
                                              icon: Icons.payments_outlined,
                                              color: Colors.green,
                                            ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 2),
                                    Text(
                                      toutPaye
                                          ? 'Payé ✓'
                                          : 'Restant : ${(total - paye).toStringAsFixed(2)} €',
                                      style: TextStyle(
                                        color: toutPaye
                                            ? Colors.green
                                            : Theme.of(context)
                                                .colorScheme
                                                .error,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Switch(
                                  value: toutPaye,
                                  onChanged: (v) async {
                                    if (v) {
                                      await ref
                                          .read(coursDaoProvider)
                                          .marquerMoisPaye(eleveId, widget.mois,
                                              widget.annee);
                                    } else {
                                      await ref
                                          .read(coursDaoProvider)
                                          .marquerMoisNonPaye(eleveId,
                                              widget.mois, widget.annee);
                                    }
                                  },
                                ),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => DetailCoursEleveMoisScreen(
                                      eleveId: eleveId,
                                      eleveName:
                                          '${eleve.prenom} ${eleve.nom}',
                                      mois: widget.mois,
                                      annee: widget.annee,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
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
    );
  }
}

class _PaiementBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _PaiementBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
