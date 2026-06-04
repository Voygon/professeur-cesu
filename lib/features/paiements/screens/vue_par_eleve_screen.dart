import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../shared/models/recap_mois.dart';
import '../../eleves/providers/eleves_provider.dart';
import '../providers/paiements_provider.dart';

String _nomMois(DateTime date) {
  const noms = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
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
  bool _modePeriode = false; // false = mois, true = plage
  DateTime _debut = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _fin = DateTime(DateTime.now().year, DateTime.now().month + 1, 1);
  bool _modeDetail = false; // false = récap, true = détail

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
        // ── Sélecteurs ─────────────────────────────────────────────────────
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Élève
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

              // Mode période
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

              // Sélecteur de mois ou de plage
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
                            initialDate: _fin.subtract(const Duration(days: 1)),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (p != null) {
                            setState(() =>
                                _fin = DateTime(p.year, p.month, p.day + 1));
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

              // Mode affichage
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

        // ── Contenu ────────────────────────────────────────────────────────
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

// ── Récap ───────────────────────────────────────────────────────────────────

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
    final recapAsync = ref.watch(
        recapPeriodeProvider((eleveId: eleveId, debut: debut, fin: fin)));

    return recapAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Erreur')),
      data: (recap) => _buildRecap(context, recap),
    );
  }

  Widget _buildRecap(BuildContext context, RecapMois recap) {
    if (recap.nbCoursValides == 0) {
      return const Center(child: Text('Aucun cours pour cette période'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _LigneRecap(
                    label: 'Cours validés',
                    valeur: '${recap.nbCoursValides}',
                  ),
                  _LigneRecap(
                    label: 'Montant total',
                    valeur: '${recap.montantTotal.toStringAsFixed(2)} €',
                  ),
                  _LigneRecap(
                    label: 'Montant payé',
                    valeur: '${recap.montantPaye.toStringAsFixed(2)} €',
                    couleur: Colors.green,
                  ),
                  _LigneRecap(
                    label: 'Restant dû',
                    valeur: '${recap.montantRestant.toStringAsFixed(2)} €',
                    couleur: recap.montantRestant > 0
                        ? Theme.of(context).colorScheme.error
                        : null,
                    bold: recap.montantRestant > 0,
                  ),
                ],
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 6),
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

// ── Détail cours (un élève) ───────────────────────────────────────────────────

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
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: coursList.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _TuileCours(cour: coursList[i]),
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
    final recapAsync = ref.watch(
        recapPeriodeTousProvider((debut: debut, fin: fin)));

    return recapAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Erreur')),
      data: (recap) {
        if (recap.nbCoursValides == 0) {
          return const Center(child: Text('Aucun cours pour cette période'));
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _LigneRecap(
                          label: 'Cours validés',
                          valeur: '${recap.nbCoursValides}'),
                      _LigneRecap(
                          label: 'Montant total',
                          valeur:
                              '${recap.montantTotal.toStringAsFixed(2)} €'),
                      _LigneRecap(
                          label: 'Montant payé',
                          valeur:
                              '${recap.montantPaye.toStringAsFixed(2)} €',
                          couleur: Colors.green),
                      _LigneRecap(
                          label: 'Restant dû',
                          valeur:
                              '${recap.montantRestant.toStringAsFixed(2)} €',
                          couleur: recap.montantRestant > 0
                              ? Theme.of(context).colorScheme.error
                              : null,
                          bold: recap.montantRestant > 0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
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
    final elevesMap = {
      for (final e in elevesAsync.valueOrNull ?? [])
        e.elevesId: '${e.prenom} ${e.nom}'
    };

    if (coursList.isEmpty) {
      return const Center(child: Text('Aucun cours pour cette période'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: coursList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _TuileCours(
        cour: coursList[i],
        nomEleve: elevesMap[coursList[i].elevesId],
      ),
    );
  }
}

// ── Tuile cours réutilisable ──────────────────────────────────────────────────

class _TuileCours extends ConsumerWidget {
  final Cour cour;
  final String? nomEleve;

  const _TuileCours({required this.cour, this.nomEleve});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = cour.dateReelle ?? cour.datePrevue;
    return Card(
      child: ListTile(
        leading: Icon(
          cour.paye ? Icons.check_circle_outline : Icons.radio_button_unchecked,
          color: cour.paye ? Colors.green : Colors.grey,
        ),
        title: Text(nomEleve != null
            ? '$nomEleve — ${_formatDate(date)}'
            : _formatDate(date)),
        subtitle: Text(
          [
            if (cour.dureeReelle != null) '${cour.dureeReelle} min',
            if (cour.montant != null) '${cour.montant!.toStringAsFixed(2)} €',
          ].join(' · '),
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
