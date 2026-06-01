import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_provider.dart';
import '../../../shared/widgets/cours_tile.dart';
import 'ajouter_cours_sheet.dart';
import 'valider_cours_sheet.dart';

enum _Mode { jour, semaine, mois, plage }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  _Mode _mode = _Mode.jour;
  DateTime? _plageDebut;
  DateTime? _plageFin; // inclusive end, stored as-is for display

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

  @override
  Widget build(BuildContext context) {
    final coursAsync = ref.watch(
      coursPeriodeProvider((debut: _debut, fin: _fin)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planning'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Planifier la semaine',
            onPressed: () async {
              final nb = await ref
                  .read(planificationServiceProvider)
                  .planifierSemaineCourante();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(nb == 0
                        ? 'Tous les cours sont déjà planifiés'
                        : '$nb cours planifiés'),
                  ),
                );
              }
            },
          ),
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
              data: (listeCours) => listeCours.isEmpty
                  ? const Center(
                      child: Text('Aucun cours pour cette période'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: listeCours.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final cour = listeCours[index];
                        final eleveAsync = ref
                            .watch(eleveParIdProvider(cour.elevesId));
                        return eleveAsync.when(
                          loading: () =>
                              const SizedBox(height: 80),
                          error: (_, __) => const SizedBox(),
                          data: (eleve) => eleve == null
                              ? const SizedBox()
                              : GestureDetector(
                                  onTap: () => showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) => ValiderCoursSheet(
                                      cours: cour,
                                      eleve: eleve,
                                    ),
                                  ),
                                  child: CoursTile(
                                      cours: cour, eleve: eleve),
                                ),
                        );
                      },
                    ),
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
