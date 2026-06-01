import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../providers/paiements_provider.dart';

String _nomMoisCapitalize(int mois, int annee) {
  const noms = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];
  return '${noms[mois - 1]} $annee';
}

class DetailMoisScreen extends ConsumerWidget {
  final int mois;
  final int annee;

  const DetailMoisScreen({
    super.key,
    required this.mois,
    required this.annee,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursAsync =
        ref.watch(coursParMoisProvider((mois: mois, annee: annee)));

    return Scaffold(
      appBar: AppBar(title: Text(_nomMoisCapitalize(mois, annee))),
      body: coursAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('Erreur de chargement')),
        data: (coursList) {
          if (coursList.isEmpty) {
            return const Center(child: Text('Aucun cours pour ce mois'));
          }

          // Groupe par élève
          final Map<int, List<Cour>> parEleve = {};
          for (final c in coursList) {
            parEleve.putIfAbsent(c.elevesId, () => []).add(c);
          }

          final elevesIds = parEleve.keys.toList();
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: elevesIds.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final eleveId = elevesIds[i];
              final coursDuEleve = parEleve[eleveId]!;
              final eleveAsync =
                  ref.watch(eleveParIdProvider(eleveId));

              return eleveAsync.when(
                loading: () => const SizedBox(height: 72),
                error: (_, __) => const SizedBox(),
                data: (eleve) {
                  if (eleve == null) return const SizedBox();
                  final total = coursDuEleve.fold<double>(
                      0, (s, c) => s + (c.montant ?? 0));
                  final paye = coursDuEleve.fold<double>(
                      0, (s, c) => s + (c.paye ? (c.montant ?? 0) : 0));
                  final toutPaye = coursDuEleve.every((c) => c.paye);

                  return Card(
                    child: ListTile(
                      title: Text('${eleve.prenom} ${eleve.nom}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${coursDuEleve.length} cours · ${total.toStringAsFixed(2)} €',
                          ),
                          Text(
                            toutPaye
                                ? 'Payé ✓'
                                : 'Restant : ${(total - paye).toStringAsFixed(2)} €',
                            style: TextStyle(
                              color: toutPaye
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.error,
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
                                .marquerMoisPaye(eleveId, mois, annee);
                          } else {
                            await ref
                                .read(coursDaoProvider)
                                .marquerMoisNonPaye(eleveId, mois, annee);
                          }
                        },
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
