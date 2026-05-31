import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';

DateTime getLundiSemaine() {
  final maintenant = DateTime.now();
  return maintenant.subtract(Duration(days: maintenant.weekday - 1));
}

final planificationServiceProvider = Provider<PlanificationService>((ref) {
  return PlanificationService(ref);
});

class PlanificationService {
  final Ref _ref;
  PlanificationService(this._ref);

  Future<int> planifierSemaineCourante() async {
    final elevesDao = _ref.read(elevesDaoProvider);
    final coursDao = _ref.read(coursDaoProvider);

    final elevesHebdo = await elevesDao.watchElevesHebdo().first;
    final lundi = getLundiSemaine();

    return coursDao.planifierCoursSemainePourTous(elevesHebdo, lundi);
  }
}

final coursDuJourProvider = StreamProvider<List<Cour>>((ref) {
  return ref.watch(coursDaoProvider).watchCoursDuJour();
});

final eleveParIdProvider = FutureProvider.family<Eleve?, int>((ref, id) {
  return ref.watch(elevesDaoProvider).getEleve(id);
});
