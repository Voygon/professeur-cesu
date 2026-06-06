import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../eleves/providers/eleves_provider.dart';
import '../providers/paiements_provider.dart';

String _nomMois(DateTime date) {
  const noms = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];
  return '${noms[date.month - 1]} ${date.year}';
}

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class VueParEleveScreen extends ConsumerStatefulWidget {
  const VueParEleveScreen({super.key});

  @override
  ConsumerState<VueParEleveScreen> createState() => _VueParEleveScreenState();
}

class _VueParEleveScreenState extends ConsumerState<VueParEleveScreen> {
  Eleve? _eleve;
  bool _modePeriode = false;
  DateTime _debut = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _fin = DateTime(DateTime.now().year, DateTime.now().month + 1, 1);
  bool _modeDetail = false;

  void _selectionnerMois(DateTime mois) {
    setState(() {
      _debut = mois;
      _fin = DateTime(mois.year, mois.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final elevesAsync = ref.watch(elevesActifsProvider);
    final moisDisponibles = ref.watch(moisAvecCoursProvider).valueOrNull ?? [];

    return Column(
      children: [
        // ── Sélecteurs ────────────────────────────────────────────────────
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              elevesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Erreur'),
                data: (eleves) => DropdownButtonFormField<Eleve?>(
                  initialValue: _eleve,
                  decoration: const InputDecoration(labelText: 'Élève'),
                  hint: const Text('Tous les élèves'),
                  items: [
                    const DropdownMenuItem<Eleve?>(
                      value: null,
                      child: Text('Tous les élèves'),
                    ),
                    ...eleves.map((e) => DropdownMenuItem<Eleve?>(
                          value: e,
                          child: Text('${e.prenom} ${e.nom}'),
                        )),
                  ],
                  onChanged: (e) => setState(() => _eleve = e),
                ),
              ),
              const SizedBox(height: 12),

              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: false,
                      label: Text('Mois'),
                      icon: Icon(Icons.calendar_view_month_outlined)),
                  ButtonSegment(
                      value: true,
                      label: Text('Période'),
                      icon: Icon(Icons.date_range_outlined)),
                ],
                selected: {_modePeriode},
                onSelectionChanged: (s) =>
                    setState(() => _modePeriode = s.first),
              ),
              const SizedBox(height: 8),

              if (!_modePeriode)
                DropdownButtonFormField<DateTime>(
                  initialValue: moisDisponibles.any((m) =>
                          m.mois.year == _debut.year &&
                          m.mois.month == _debut.month)
                      ? _debut
                      : null,
                  decoration: const InputDecoration(labelText: 'Mois'),
                  hint: const Text('Choisir un mois'),
                  items: moisDisponibles
                      .map((m) => DropdownMenuItem<DateTime>(
                            value: m.mois,
                            child: Text(_nomMois(m.mois)),
                          ))
                      .toList(),
                  onChanged: (m) {
                    if (m != null) _selectionnerMois(m);
                  },
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final p = await showDatePicker(
                            context: context,
                            initialDate: _debut,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (p != null) setState(() => _debut = p);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Du',
                            suffixIcon:
                                Icon(Icons.calendar_today_outlined, size: 18),
                          ),
                          child: Text(_formatDate(_debut)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final p = await showDatePicker(
                            context: context,
                            initialDate:
                                _fin.subtract(const Duration(days: 1)),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (p != null) {
                            setState(() => _fin =
                                DateTime(p.year, p.month, p.day + 1));
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Au',
                            suffixIcon:
                                Icon(Icons.calendar_today_outlined, size: 18),
                          ),
                          child: Text(_formatDate(
                              _fin.subtract(const Duration(days: 1)))),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),

              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: false,
                      label: Text('Récap'),
                      icon: Icon(Icons.summarize_outlined)),
                  ButtonSegment(
                      value: true,
                      label: Text('Détail cours'),
                      icon: Icon(Icons.list_outlined)),
                ],
                selected: {_modeDetail},
                onSelectionChanged: (s) =>
                    setState(() => _modeDetail = s.first),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // ── Contenu ───────────────────────────────────────────────────────
        Expanded(
          child: _modeDetail
              ? (_eleve == null
                  ? _DetailCoursTous(debut: _debut, fin: _fin)
                  : _DetailCours(
                      eleveId: _eleve!.elevesId, debut: _debut, fin: _fin))
              : (_eleve == null
                  ? _RecapCardTous(debut: _debut, fin: _fin)
                  : _RecapCard(
                      eleveId: _eleve!.elevesId, debut: _debut, fin: _fin)),
        ),
      ],
    );
  }
}

// ── Helpers partagés ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int nb;
  final double montant;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
    required this.nb,
    required this.montant,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$nb cours · ${montant.toStringAsFixed(2)} €',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecapGroupe extends StatelessWidget {
  final List<Cour> cours;
  final bool especes;

  const _RecapGroupe({required this.cours, required this.especes});

  @override
  Widget build(BuildContext context) {
    final total =
        cours.fold<double>(0, (s, c) => s + (c.montant ?? 0));
    final paye = cours.fold<double>(
        0, (s, c) => s + (c.paye ? (c.montant ?? 0) : 0));
    final nbPaye = cours.where((c) => c.paye).length;
    final restant = total - paye;
    final color = especes ? Colors.green : Colors.blue;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  especes
                      ? Icons.payments_outlined
                      : Icons.credit_card_outlined,
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  especes ? 'Espèces' : 'CESU+',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _LigneRecap(
              label: 'Cours validés',
              valeur: '${cours.length}',
            ),
            _LigneRecap(
              label: 'Cours payés',
              valeur: '$nbPaye / ${cours.length}',
            ),
            _LigneRecap(
              label: 'Montant total',
              valeur: '${total.toStringAsFixed(2)} €',
            ),
            _LigneRecap(
              label: 'Montant payé',
              valeur: '${paye.toStringAsFixed(2)} €',
              couleur: Colors.green,
            ),
            _LigneRecap(
              label: 'Restant dû',
              valeur: '${restant.toStringAsFixed(2)} €',
              couleur: restant > 0
                  ? Theme.of(context).colorScheme.error
                  : null,
              bold: restant > 0,
            ),
          ],
        ),
      ),
    );
  }
}

class _LigneRecap extends StatelessWidget {
  final String label;
  final String valeur;
  final Color? couleur;
  final bool bold;

  const _LigneRecap({
    required this.label,
    required this.valeur,
    this.couleur,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            valeur,
            style: TextStyle(
              color: couleur,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Récap un élève ────────────────────────────────────────────────────────────

class _RecapCard extends ConsumerWidget {
  final int eleveId;
  final DateTime debut;
  final DateTime fin;

  const _RecapCard({
    required this.eleveId,
    required this.debut,
    required this.fin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursAsync = ref.watch(
        coursParPeriodeProvider((eleveId: eleveId, debut: debut, fin: fin)));

    return coursAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Erreur')),
      data: (coursList) {
        if (coursList.isEmpty) {
          return const Center(child: Text('Aucun cours pour cette période'));
        }

        final cesu = coursList.where((c) => !c.paiementEspeces).toList();
        final especes = coursList.where((c) => c.paiementEspeces).toList();

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (cesu.isNotEmpty) ...[
                _RecapGroupe(cours: cesu, especes: false),
              ],
              if (cesu.isNotEmpty && especes.isNotEmpty)
                const SizedBox(height: 12),
              if (especes.isNotEmpty) ...[
                _RecapGroupe(cours: especes, especes: true),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Récap tous élèves ─────────────────────────────────────────────────────────

class _RecapCardTous extends ConsumerWidget {
  final DateTime debut;
  final DateTime fin;

  const _RecapCardTous({required this.debut, required this.fin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursAsync =
        ref.watch(coursParPeriodeTousProvider((debut: debut, fin: fin)));

    return coursAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Erreur')),
      data: (coursList) {
        if (coursList.isEmpty) {
          return const Center(child: Text('Aucun cours pour cette période'));
        }

        final cesu = coursList.where((c) => !c.paiementEspeces).toList();
        final especes = coursList.where((c) => c.paiementEspeces).toList();

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (cesu.isNotEmpty) _RecapGroupe(cours: cesu, especes: false),
              if (cesu.isNotEmpty && especes.isNotEmpty)
                const SizedBox(height: 12),
              if (especes.isNotEmpty)
                _RecapGroupe(cours: especes, especes: true),
            ],
          ),
        );
      },
    );
  }
}

// ── Détail cours un élève ─────────────────────────────────────────────────────

class _DetailCours extends ConsumerWidget {
  final int eleveId;
  final DateTime debut;
  final DateTime fin;

  const _DetailCours({
    required this.eleveId,
    required this.debut,
    required this.fin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursAsync = ref.watch(
        coursParPeriodeProvider((eleveId: eleveId, debut: debut, fin: fin)));

    return coursAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Erreur')),
      data: (coursList) {
        if (coursList.isEmpty) {
          return const Center(child: Text('Aucun cours pour cette période'));
        }

        final cesu = coursList.where((c) => !c.paiementEspeces).toList();
        final especes = coursList.where((c) => c.paiementEspeces).toList();

        return _ListeAvecSections(cesu: cesu, especes: especes);
      },
    );
  }
}

// ── Détail cours tous élèves ──────────────────────────────────────────────────

class _DetailCoursTous extends ConsumerWidget {
  final DateTime debut;
  final DateTime fin;

  const _DetailCoursTous({required this.debut, required this.fin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursAsync =
        ref.watch(coursParPeriodeTousProvider((debut: debut, fin: fin)));
    final elevesAsync = ref.watch(elevesActifsProvider);

    if (coursAsync.isLoading || elevesAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final coursList = coursAsync.valueOrNull ?? [];
    final elevesMap = <int, String>{
      for (final e in elevesAsync.valueOrNull ?? [])
        e.elevesId: '${e.prenom} ${e.nom}'
    };

    if (coursList.isEmpty) {
      return const Center(child: Text('Aucun cours pour cette période'));
    }

    final cesu = coursList.where((c) => !c.paiementEspeces).toList();
    final especes = coursList.where((c) => c.paiementEspeces).toList();

    return _ListeAvecSections(
        cesu: cesu, especes: especes, elevesMap: elevesMap);
  }
}

// ── Liste avec deux sections séparées ────────────────────────────────────────

class _ListeAvecSections extends ConsumerWidget {
  final List<Cour> cesu;
  final List<Cour> especes;
  final Map<int, String>? elevesMap;

  const _ListeAvecSections({
    required this.cesu,
    required this.especes,
    this.elevesMap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cesuTotal =
        cesu.fold<double>(0, (s, c) => s + (c.montant ?? 0));
    final especesTotal =
        especes.fold<double>(0, (s, c) => s + (c.montant ?? 0));

    // Construire la liste à plat : headers + items
    final items = <_ListItem>[];

    if (cesu.isNotEmpty) {
      items.add(_ListItem.header(
        icon: Icons.credit_card_outlined,
        label: 'CESU+',
        color: Colors.blue,
        nb: cesu.length,
        montant: cesuTotal,
      ));
      for (final c in cesu) {
        items.add(_ListItem.cours(c));
      }
    }

    if (especes.isNotEmpty) {
      if (cesu.isNotEmpty) items.add(_ListItem.separateur());
      items.add(_ListItem.header(
        icon: Icons.payments_outlined,
        label: 'Espèces',
        color: Colors.green,
        nb: especes.length,
        montant: especesTotal,
      ));
      for (final c in especes) {
        items.add(_ListItem.cours(c));
      }
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, 16 + MediaQuery.of(context).padding.bottom),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        if (item.isHeader) {
          return _SectionHeader(
            icon: item.icon!,
            label: item.label!,
            color: item.color!,
            nb: item.nb!,
            montant: item.montant!,
          );
        }
        if (item.isSeparateur) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _TuileCours(
            cour: item.cour!,
            nomEleve: elevesMap?[item.cour!.elevesId],
          ),
        );
      },
    );
  }
}

// Classe utilitaire pour les items de liste hétérogène
class _ListItem {
  final bool isHeader;
  final bool isSeparateur;
  final Cour? cour;
  final IconData? icon;
  final String? label;
  final Color? color;
  final int? nb;
  final double? montant;

  const _ListItem._({
    required this.isHeader,
    required this.isSeparateur,
    this.cour,
    this.icon,
    this.label,
    this.color,
    this.nb,
    this.montant,
  });

  factory _ListItem.header({
    required IconData icon,
    required String label,
    required Color color,
    required int nb,
    required double montant,
  }) =>
      _ListItem._(
        isHeader: true,
        isSeparateur: false,
        icon: icon,
        label: label,
        color: color,
        nb: nb,
        montant: montant,
      );

  factory _ListItem.cours(Cour c) => _ListItem._(
        isHeader: false,
        isSeparateur: false,
        cour: c,
      );

  factory _ListItem.separateur() => const _ListItem._(
        isHeader: false,
        isSeparateur: true,
      );
}

// ── Tuile cours ───────────────────────────────────────────────────────────────

class _TuileCours extends ConsumerWidget {
  final Cour cour;
  final String? nomEleve;

  const _TuileCours({required this.cour, this.nomEleve});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = cour.dateReelle ?? cour.datePrevue;
    final color = cour.paiementEspeces ? Colors.green : Colors.blue;

    return Card(
      child: ListTile(
        leading: Icon(
          cour.paye ? Icons.check_circle_outline : Icons.radio_button_unchecked,
          color: cour.paye ? Colors.green : Colors.grey,
        ),
        title: Text(nomEleve != null
            ? '$nomEleve — ${_formatDate(date)}'
            : _formatDate(date)),
        subtitle: Row(
          children: [
            Text(
              [
                if (cour.dureeReelle != null) '${cour.dureeReelle} min',
                if (cour.montant != null)
                  '${cour.montant!.toStringAsFixed(2)} €',
              ].join(' · '),
            ),
            const SizedBox(width: 6),
            Icon(
              cour.paiementEspeces
                  ? Icons.payments_outlined
                  : Icons.credit_card_outlined,
              size: 13,
              color: color,
            ),
          ],
        ),
        trailing: Switch(
          value: cour.paye,
          onChanged: (v) async {
            if (v) {
              await ref.read(coursDaoProvider).marquerCoursPaye(cour.coursId);
            } else {
              await ref
                  .read(coursDaoProvider)
                  .marquerCoursNonPaye(cour.coursId);
            }
          },
        ),
      ),
    );
  }
}
