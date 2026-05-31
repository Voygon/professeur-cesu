import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_provider.dart';
import '../../../shared/widgets/cours_tile.dart';
import 'valider_cours_sheet.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursAsync = ref.watch(coursDuJourProvider);

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
        body: coursAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Text('Erreur : $err'),
          data: (listeCours) => listeCours.isEmpty
              ? Center(child: Text('Aucun cours aujourd\'hui'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: listeCours.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final cour = listeCours[index];
                    final eleveAsync =
                        ref.watch(eleveParIdProvider(cour.elevesId));
                    return eleveAsync.when(
                      loading: () => const SizedBox(height: 80),
                      error: (_, __) => const SizedBox(),
                      data: (eleve) => eleve == null
                          ? const SizedBox()
                          : GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (_) => ValiderCoursSheet(
                                    cours: cour,
                                    eleve: eleve,
                                  ),
                                );
                              },
                              child: CoursTile(cours: cour, eleve: eleve),
                            ),
                    );
                  },
                ),
        ));
  }
}
