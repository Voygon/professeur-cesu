import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';

final elevesActifsProvider = StreamProvider<List<Eleve>>((ref) {
  return ref.watch(elevesDaoProvider).watchElevesActifs();
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
    final payeursDao = _ref.read(payeursDaoProvider);
    final elevesDao = _ref.read(elevesDaoProvider);

    // Crée d'abord le payeur, récupère son id
    final payeurId = await payeursDao.insertPayeur(payeur);

    // Crée ensuite l'élève avec le payeurId
    await elevesDao.insertEleve(
      eleve.copyWith(payeurId: Value(payeurId)),
    );
  }
}
