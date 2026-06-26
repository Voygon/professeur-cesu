import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/models/eleve_avec_payeur.dart';
import 'package:drift/drift.dart';

final elevesActifsProvider = StreamProvider<List<Eleve>>((ref) {
  return ref.watch(elevesDaoProvider).watchElevesActifs();
});

final elevesArchivesProvider = StreamProvider<List<Eleve>>((ref) {
  return ref.watch(elevesDaoProvider).watchElevesArchives();
});

// Combine actifs + archivés pour un lookup synchrone par id (évite de
// refaire une requête FutureProvider par élève dans les listes de cours).
final elevesMapProvider = Provider<Map<int, Eleve>>((ref) {
  final actifs = ref.watch(elevesActifsProvider).valueOrNull ?? [];
  final archives = ref.watch(elevesArchivesProvider).valueOrNull ?? [];
  return {
    for (final e in [...actifs, ...archives]) e.elevesId: e,
  };
});

final elevesServiceProvider = Provider<ElevesService>((ref) {
  return ElevesService(ref);
});

class ElevesService {
  final Ref _ref;
  ElevesService(this._ref);

  Future<void> ajouterEleveAvecPayeur({
    required ElevesCompanion eleve,
    required PayeursCompanion payeur,
  }) async {
    final db = _ref.read(databaseProvider);
    final payeursDao = _ref.read(payeursDaoProvider);
    final elevesDao = _ref.read(elevesDaoProvider);

    await db.transaction(() async {
      final payeurId = await payeursDao.insertPayeur(payeur);
      await elevesDao.insertEleve(
        eleve.copyWith(payeurId: Value(payeurId)),
      );
    });
  }

  Future<void> modifierEleve({
    required ElevesCompanion eleve,
    required PayeursCompanion payeur,
    required int payeurId,
  }) async {
    final db = _ref.read(databaseProvider);
    final payeursDao = _ref.read(payeursDaoProvider);
    final elevesDao = _ref.read(elevesDaoProvider);

    await db.transaction(() async {
      await payeursDao.updatePayeur(
        payeur.copyWith(payeurId: Value(payeurId)),
      );
      await elevesDao.updateEleve(eleve);
    });
  }
}

final payeurParEleveProvider =
    FutureProvider.family<Payeur?, int>((ref, eleveId) {
  return ref.read(payeursDaoProvider).getPayeurByEleve(eleveId);
});

final eleveAvecPayeurProvider =
    StreamProvider.family<EleveAvecPayeur?, int>((ref, eleveId) async* {
  // Écoute uniquement cet élève — SQLite notifie seulement quand il change
  await for (final eleve
      in ref.watch(elevesDaoProvider).watchEleve(eleveId)) {
    if (eleve == null) {
      yield null;
      continue;
    }
    final payeur =
        await ref.read(payeursDaoProvider).getPayeurByEleve(eleveId);
    yield payeur == null ? null : EleveAvecPayeur(eleve: eleve, payeur: payeur);
  }
});
