import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_provider.dart';
import '../../../shared/widgets/cours_tile.dart';
import 'ajouter_cours_sheet.dart';
import 'valider_cours_sheet.dart';
import '../../../shared/models/enums.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/validators/conflit_horaire.dart';
import '../../parametres/providers/parametres_provider.dart';

enum _Mode { jour, semaine, mois, plage }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  _Mode _mode = _Mode.jour;
  DateTime? _plageDebut = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _plageFin = DateTime.now();

  Future<void> _afficherDialoguePlanification(BuildContext context, WidgetRef ref) async {
    String mode = 'semaine';
    DateTime debut = DateTime.now();
    DateTime fin = DateTime.now();

    final confirmer = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Planifier les cours'),
            content: SizedBox(
              height: 220,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Selecteur de mode
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'semaine', label: Text('Semaine')),
                      ButtonSegment(value: 'mois', label: Text('Mois')),
                      ButtonSegment(value: 'periode', label: Text('Période')),
                    ],
                    selected: {mode},
                    onSelectionChanged: (s) => setDialogState(() => mode = s.first),
                  ),
                  const SizedBox(height: 16),

                  // Afficher selon le mode
                  if (mode == 'semaine')
                    Text(
                      'Semaine du ${_formatDate(getLundiSemaine())} '
                      'au ${_formatDate(getLundiSemaine().add(const Duration(days: 6)))}', 
                    )
                  else if (mode == 'mois')
                    Text(
                      'Mois de ${_nomMois(DateTime.now())}',
                  )
                  else ...[
                    // Période libre
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Du'),
                      subtitle: Text(_formatDate(debut)),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () async {
                        final p = await showDatePicker(
                          context: context, 
                          initialDate: debut,
                          firstDate: DateTime(2020), 
                          lastDate: DateTime(2030),
                        );
                        if (p != null) setDialogState(() => debut = p);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Au'),
                      subtitle: Text(_formatDate(fin)),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: () async {
                        final p = await showDatePicker(
                          context: context, 
                          initialDate: fin,
                          firstDate: DateTime(2020), 
                          lastDate: DateTime(2030),
                        );
                        if (p != null) setDialogState(() => fin = p);
                      },

                    )
                  ]
                ],
              )
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false), 
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true), 
                child: const Text('Planifier'),
              )
            ],
          );
        }
      )
    );
    
    if (confirmer != true || !context.mounted) return;

    // Calcule les dates delon le mode
    final DateTime debutEffectif;
    final DateTime finEffective;

    switch (mode) {
      case 'semaine':
        debutEffectif = getLundiSemaine();
        finEffective = debutEffectif.add(const Duration(days: 7));
      case 'mois':
        final now = DateTime.now();
        debutEffectif = DateTime(now.year, now.month, 1);
        finEffective = DateTime(now.year, now.month + 1, 1);
      default:
        debutEffectif = DateTime(debut.year, debut.month, debut.day);
        finEffective = DateTime(fin.year, fin.month, fin.day + 1);
    }

    final nb = await ref
      .read(planificationServiceProvider)
      .planifierPeriode(debutEffectif, finEffective);

    if (!context.mounted) return;

    // Vérification des conflits sur la période planifiée
    final coursPeriode = await ref
        .read(coursDaoProvider)
        .watchCoursPeriode(debutEffectif, finEffective)
        .first;
    final espacement = ref.read(espacementProvider);
    final conflits = ConflitHoraire.detecterConflitsCours(coursPeriode,
        espacement: espacement);

    if (!context.mounted) return;

    if (conflits.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Conflits d\'horaire détectés'),
          content: Text(
            '${conflits.length} cours sont planifiés à moins de '
            '15 minutes d\'intervalle.\n\n'
            'Ils sont encadrés en rouge dans le planning.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Compris'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nb == 0
              ? 'Tous les cours sont déjà planifiés'
              : '$nb cours planifiés'),
        ),
      );
    }
  }



  // ── Séparateurs par jour ─────────────────────────────────────────────────

  List<Object> _construireItemsAvecJours(List<Cour> cours) {
    final items = <Object>[];
    DateTime? dernierJour;
    for (final c in cours) {
      final date = c.dateReelle ?? c.datePrevue;
      final jour = DateTime(date.year, date.month, date.day);
      if (dernierJour == null || jour != dernierJour) {
        items.add(jour);
        dernierJour = jour;
      }
      items.add(c);
    }
    return items;
  }

  Widget _enteteJour(BuildContext context, DateTime date) {
    const jours = [
      'Lundi', 'Mardi', 'Mercredi', 'Jeudi',
      'Vendredi', 'Samedi', 'Dimanche',
    ];
    const mois = [
      'jan.', 'fév.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
    ];
    final label =
        '${jours[date.weekday - 1]} ${date.day} ${mois[date.month - 1]}';

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  // ── Calcul des bornes selon le mode ──────────────────────────────────────

  DateTime get _debut {
    final now = DateTime.now();
    switch (_mode) {
      case _Mode.jour:
        return DateTime(now.year, now.month, now.day);
      case _Mode.semaine:
        final d = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(d.year, d.month, d.day);
      case _Mode.mois:
        return DateTime(now.year, now.month, 1);
      case _Mode.plage:
        final d = _plageDebut ?? now;
        return DateTime(d.year, d.month, d.day);
    }
  }

  DateTime get _fin {
    final now = DateTime.now();
    switch (_mode) {
      case _Mode.jour:
        return DateTime(now.year, now.month, now.day + 1);
      case _Mode.semaine:
        final d = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(d.year, d.month, d.day + 7);
      case _Mode.mois:
        return DateTime(now.year, now.month + 1, 1);
      case _Mode.plage:
        final d = _plageFin ?? now;
        return DateTime(d.year, d.month, d.day + 1); // exclusive
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  
  String _nomMois(DateTime date) {
    const noms = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
    ];
    return noms[date.month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final coursAsync = ref.watch(
      coursPeriodeProvider((debut: _debut, fin: _fin)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planning'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.event_repeat_outlined),
            label: const Text('Planifier'),
            onPressed: () => _afficherDialoguePlanification(context, ref),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── Sélecteur de période ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                SegmentedButton<_Mode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: _Mode.jour, label: Text('Jour')),
                    ButtonSegment(
                        value: _Mode.semaine, label: Text('Semaine')),
                    ButtonSegment(value: _Mode.mois, label: Text('Mois')),
                    ButtonSegment(
                        value: _Mode.plage, label: Text('Période')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) =>
                      setState(() => _mode = s.first),
                ),
                if (_mode == _Mode.plage) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final p = await showDatePicker(
                              context: context,
                              initialDate:
                                  _plageDebut ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (p != null) {
                              setState(() => _plageDebut = p);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Du',
                              suffixIcon: Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18),
                            ),
                            child: Text(_plageDebut != null
                                ? _formatDate(_plageDebut!)
                                : '—'),
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
                                  _plageFin ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (p != null) {
                              setState(() => _plageFin = p);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Au',
                              suffixIcon: Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18),
                            ),
                            child: Text(_plageFin != null
                                ? _formatDate(_plageFin!)
                                : '—'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),

          // ── Liste des cours ─────────────────────────────────────────────
          Expanded(
            child: _mode == _Mode.plage &&
                    (_plageDebut == null || _plageFin == null)
                ? const Center(child: Text('Sélectionnez une période'))
                : coursAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erreur : $err')),
              data: (listeCours) {
                final coursEnConflit = ConflitHoraire.detecterConflitsCours(
                    listeCours,
                    espacement: ref.watch(espacementProvider));
                if (listeCours.isEmpty) {
                  return const Center(
                    child: Text('Aucun cours pour cette période'),
                  );
                }

                final items = _mode == _Mode.jour
                    ? listeCours.cast<Object>().toList()
                    : _construireItemsAvecJours(listeCours);

                return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];

                        if (item is DateTime) {
                          return _enteteJour(context, item);
                        }

                        final cour = item as Cour;
                        final eleveAsync = ref
                            .watch(eleveParIdProvider(cour.elevesId));
                        return eleveAsync.when(
                          loading: () =>
                              const SizedBox(height: 80),
                          error: (_, __) => const SizedBox(),
                          data: (eleve) => eleve == null
                              ? const SizedBox()
                              : Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Dismissible(
                                key: ValueKey(cour.coursId), 
                                // Swipe droite
                                background: Container(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.check_circle_outline, color: Colors.green),
                                      SizedBox(width: 8),
                                      Text('Valider', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                                    ],
                                  )
                                ),
                                // Swipe gauche
                                secondaryBackground: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text('En attente', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                                      SizedBox(width: 8),
                                      Icon(Icons.undo_outlined, color: Colors.orange),
                                    ],
                                  ),
                                ),
                                confirmDismiss: (direction) async {
                                  final statut = StatutCours.fromDb(cour.statut);

                                  if (direction == DismissDirection.startToEnd) {
                                    // Swipe à droite -> valider si prévu
                                    if (statut == StatutCours.prevu) {
                                      final montant = await ref
                                        .read(tarifsDaoProvider)
                                        .calculerMontant(cour.dureeReelle ?? eleve.dureeCours ?? 60);
                                        if (montant == null && context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Aucun tarif défini — validation impossible')),
                                          );
                                          return false;
                                        }
                                        await ref.read(coursDaoProvider).validerCours(
                                          cour.coursId,
                                          montant: montant!,
                                          dureeReelle: cour.dureeReelle ?? eleve.dureeCours ?? 60,
                                        );
                                    }
                                  } else {
                                    // Swipe gauche
                                    if (statut == StatutCours.effectue || statut == StatutCours.modifie) {
                                      if (cour.paye && context.mounted) {
                                        final confirmer = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Cours déjà payé'),
                                            content: const Text(
                                              'Ce cours est marqué comme payé. '
                                              'Remettre en attente annulera également le paiement.'
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context,false), 
                                                child: const Text('Annulé'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(context,true), 
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Theme.of(context).colorScheme.error,
                                                ),
                                                child: const Text('Confirmer'),
                                              )
                                            ],
                                          ),
                                        );
                                        if (confirmer != true) return false;
                                      }
                                      await ref.read(coursDaoProvider).remettreEnAttente(cour.coursId);
                                    }
                                  }
                                  return false; // Ne jamais supprimé la carte
                                },
                                child: GestureDetector(
                                  onTap: () => showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) => ValiderCoursSheet(cours: cour, eleve: eleve),
                                  ),
                                  child: CoursTile(
                                    cours: cour,
                                    eleve: eleve,
                                    enConflit: coursEnConflit.contains(cour.coursId),
                                  ),
                                ),
                              ),
                            ),
                        );
                      },
                    );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const AjouterCoursSheet(),
        ),
        tooltip: 'Ajouter un cours',
        child: const Icon(Icons.add),
      ),
    );
  }
}
