import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../providers/paiements_provider.dart';

class DetailCoursEleveMoisScreen extends ConsumerWidget {
  final int eleveId;
  final String eleveName;
  final int mois;
  final int annee;

  const DetailCoursEleveMoisScreen({
    super.key,
    required this.eleveId,
    required this.eleveName,
    required this.mois,
    required this.annee,
  });

  static const _moisNoms = [
    'jan', 'fév', 'mar', 'avr', 'mai', 'juin',
    'juil', 'août', 'sep', 'oct', 'nov', 'déc',
  ];

  String _formatDate(DateTime d) =>
      '${d.day} ${_moisNoms[d.month - 1]} · '
      '${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursAsync = ref.watch(coursEleveParMoisProvider(
        (eleveId: eleveId, mois: mois, annee: annee)));

    return Scaffold(
      appBar: AppBar(title: Text(eleveName)),
      body: coursAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Erreur de chargement')),
        data: (coursList) {
          if (coursList.isEmpty) {
            return const Center(child: Text('Aucun cours pour ce mois'));
          }

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
            itemCount: coursList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final c = coursList[i];
              final date = c.dateReelle ?? c.datePrevue;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: c.paye
                        ? Colors.green.withValues(alpha: 0.15)
                        : Theme.of(context).colorScheme.errorContainer,
                    child: Icon(
                      c.paye ? Icons.check : Icons.pending_outlined,
                      color: c.paye
                          ? Colors.green
                          : Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                  ),
                  title: Text(_formatDate(date)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (c.dureeReelle != null) Text('${c.dureeReelle} min'),
                      if (c.montant != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${c.montant!.toStringAsFixed(2)} €',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 8),
                            _SmallBadge(
                              label: c.paiementEspeces ? 'Espèces' : 'CESU+',
                              icon: c.paiementEspeces
                                  ? Icons.payments_outlined
                                  : Icons.credit_card_outlined,
                              color:
                                  c.paiementEspeces ? Colors.green : Colors.blue,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  trailing: Switch(
                    value: c.paye,
                    onChanged: (v) async {
                      if (v) {
                        await ref
                            .read(coursDaoProvider)
                            .marquerCoursPaye(c.coursId);
                      } else {
                        await ref
                            .read(coursDaoProvider)
                            .marquerCoursNonPaye(c.coursId);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _SmallBadge({
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
