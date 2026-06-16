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
