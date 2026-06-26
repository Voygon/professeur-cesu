import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/notifications/notification_service.dart';

DateTime getLundiSemaine() {
  final maintenant = DateTime.now();
  final lundi = maintenant.subtract(Duration(days: maintenant.weekday - 1));
  return DateTime(lundi.year, lundi.month, lundi.day);
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

  Future<int> planifierPeriode(DateTime debut, DateTime fin) async{
    final eleveDao = _ref.read(elevesDaoProvider);
    final coursDao = _ref.read(coursDaoProvider);
    final eleveHebdo = await eleveDao.watchElevesHebdo().first;

    int total = 0;

    // Trouve le premier lundi de la periode
    DateTime lundi = debut.subtract(Duration(days: debut.weekday -1));
    lundi = DateTime(lundi.year, lundi.month, lundi.day);

    // Itère sur chaque semaine jusqu'à la fin de la période
    while (lundi.isBefore(fin)){
      total+= await coursDao.planifierCoursSemainePourTous(eleveHebdo, lundi);
      lundi = lundi.add(const Duration(days: 7));
    }

    return total;
  }

  Future<int> planifierPeriodeAvecNotifications(
    DateTime debut,
    DateTime fin,
  ) async {
    final nb = await planifierPeriode(debut, fin);

    final cours = await _ref
        .read(coursDaoProvider)
        .watchCoursParPeriodeTous(debut, fin.add(const Duration(days: 7)))
        .first;

    final eleves = await _ref.read(elevesDaoProvider).watchElevesActifs().first;
    final elevesMap = {for (final e in eleves) e.elevesId: e};

    await NotificationService.replanifierTout(cours, elevesMap);

    return nb;
  }
}

final coursDuJourProvider = StreamProvider<List<Cour>>((ref) {
  return ref.watch(coursDaoProvider).watchCoursDuJour();
});

typedef PeriodeDashboard = ({DateTime debut, DateTime fin});

final coursPeriodeProvider =
    StreamProvider.family<List<Cour>, PeriodeDashboard>((ref, key) {
  return ref
      .watch(coursDaoProvider)
      .watchCoursPeriode(key.debut, key.fin);
});
