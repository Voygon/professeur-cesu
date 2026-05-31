import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/eleves_provider.dart';
import 'ajouter_eleve_sheet.dart';
import '../../../shared/models/enums.dart';
import 'fiche_eleve_screen.dart';

class ElevesScreen extends ConsumerStatefulWidget {
  const ElevesScreen({super.key});

  @override
  ConsumerState<ElevesScreen> createState() => _ElevesScreenState();
}

class _ElevesScreenState extends ConsumerState<ElevesScreen> {
  bool _afficherArchives = false;

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
        data: (listeEleves) => listeEleves.isEmpty
            ? Center(
                child: Text(_afficherArchives
                    ? 'Aucun élève archivé'
                    : 'Aucun élève'),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: listeEleves.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final eleve = listeEleves[index];
                  return Card(
                    child: ListTile(
                      title: Text('${eleve.prenom} ${eleve.nom}'),
                      subtitle: Text(() {
                        final base = eleve.hebdo && eleve.jourSemaine != null
                            ? 'Hebdo — ${JourSemaine.fromValeur(eleve.jourSemaine!).name[0].toUpperCase()}${JourSemaine.fromValeur(eleve.jourSemaine!).name.substring(1)} à ${eleve.heureDebut}'
                            : 'Cours ponctuels';
                        return eleve.dureeCours != null
                            ? '$base · ${eleve.dureeCours} min'
                            : base;
                      }()),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                FicheEleveScreen(eleveId: eleve.elevesId),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: _afficherArchives
          ? null
          : FloatingActionButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => const AjouterEleveSheet(),
                );
              },
              child: const Icon(Icons.add),
            ),
    );
  }
}
