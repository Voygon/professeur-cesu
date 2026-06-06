import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../../dashboard/providers/dashboard_provider.dart';

class CoursAnnulesScreen extends ConsumerWidget {
  const CoursAnnulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursAsync = ref.watch(
      StreamProvider<List<Cour>>((ref) =>
          ref.watch(coursDaoProvider).watchCoursAnnules()),
    );

    return Scaffold(
      appBar: AppBar(
        title: coursAsync.when(
          data: (liste) => Text(
            'Cours annulés${liste.isNotEmpty ? ' (${liste.length})' : ''}',
          ),
          loading: () => const Text('Cours annulés'),
          error: (_, __) => const Text('Cours annulés'),
        ),
        actions: [
          coursAsync.when(
            data: (liste) => liste.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: 'Tout supprimer',
                    onPressed: () => _toutSupprimer(context, ref),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: coursAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (liste) {
          if (liste.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun cours annulé',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
            itemCount: liste.length,
            itemBuilder: (context, i) =>
                _CarteCours(cour: liste[i], index: i),
          );
        },
      ),
    );
  }

  Future<void> _toutSupprimer(BuildContext context, WidgetRef ref) async {
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tout supprimer'),
        content: const Text(
          'Tous les cours annulés seront définitivement supprimés.\n\n'
          'Cette action est irréversible.',
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
            child: const Text('Supprimer tout'),
          ),
        ],
      ),
    );
    if (confirmer != true) return;
    await ref.read(coursDaoProvider).purgerTousCoursAnnules();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cours annulés supprimés')),
      );
    }
  }
}

// ── Carte d'un cours annulé ──────────────────────────────────────────────────

class _CarteCours extends ConsumerWidget {
  final Cour cour;
  final int index;

  const _CarteCours({required this.cour, required this.index});

  String _formatDate(DateTime d) {
    const jours = [
      'Lundi', 'Mardi', 'Mercredi', 'Jeudi',
      'Vendredi', 'Samedi', 'Dimanche'
    ];
    final jourNom = jours[d.weekday - 1];
    final j = d.day.toString().padLeft(2, '0');
    final m = d.month.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$jourNom $j/$m/${d.year} à $h:$min';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eleveAsync = ref.watch(eleveParIdProvider(cour.elevesId));
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Nom de l'élève ──
              eleveAsync.when(
                loading: () => const SizedBox(height: 18),
                error: (_, __) => const Text('Élève inconnu'),
                data: (eleve) => Text(
                  eleve != null
                      ? '${eleve.prenom} ${eleve.nom}'
                      : 'Élève inconnu',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 4),
              // ── Date et durée ──
              Row(
                children: [
                  Icon(Icons.event_outlined,
                      size: 14, color: colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(cour.datePrevue),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (cour.dureeReelle != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.timer_outlined,
                        size: 14, color: colorScheme.outline),
                    const SizedBox(width: 4),
                    Text(
                      '${cour.dureeReelle} min',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              // ── Notes ──
              if (cour.notes != null && cour.notes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  cour.notes!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              // ── Actions ──
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Restaurer
                  OutlinedButton.icon(
                    onPressed: () =>
                        _restaurer(context, ref, eleveAsync.valueOrNull),
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('Restaurer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Supprimer définitivement
                  OutlinedButton.icon(
                    onPressed: () => _supprimer(context, ref),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Supprimer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _restaurer(
      BuildContext context, WidgetRef ref, dynamic eleve) async {
    await ref
        .read(coursDaoProvider)
        .remettreEnAttente(cour.coursId, eleve: eleve);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cours restauré — remis en attente')),
      );
    }
  }

  Future<void> _supprimer(BuildContext context, WidgetRef ref) async {
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer définitivement'),
        content: Text(
          'Supprimer ce cours du ${_formatDate(cour.datePrevue)} ?\n\n'
          'Cette action est irréversible.',
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
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmer != true) return;
    await ref.read(coursDaoProvider).deleteCours(cour.coursId);
  }
}
