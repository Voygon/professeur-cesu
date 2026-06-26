import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/models/recap_mois.dart';
import '../../../shared/models/mois_info.dart';

final moisAvecCoursProvider = StreamProvider<List<MoisInfo>>((ref) {
  return ref.watch(coursDaoProvider).watchMoisAvecCours();
});

typedef MoisCle = ({int mois, int annee});
typedef EleveMoisCle = ({int eleveId, int mois, int annee});
typedef PeriodeCle = ({int eleveId, DateTime debut, DateTime fin});
typedef PeriodeSeuleCle = ({DateTime debut, DateTime fin});

final coursParMoisProvider =
    StreamProvider.autoDispose.family<List<Cour>, MoisCle>((ref, key) {
  return ref.watch(coursDaoProvider).watchCoursParMois(key.mois, key.annee);
});

final coursEleveParMoisProvider =
    StreamProvider.autoDispose.family<List<Cour>, EleveMoisCle>((ref, key) {
  final debut = DateTime(key.annee, key.mois, 1);
  final fin = DateTime(key.annee, key.mois + 1, 1);
  return ref
      .watch(coursDaoProvider)
      .watchCoursEleveParPeriode(key.eleveId, debut, fin);
});

final recapPeriodeProvider =
    StreamProvider.autoDispose.family<RecapMois, PeriodeCle>((ref, key) {
  return ref
      .watch(coursDaoProvider)
      .watchRecapPeriode(key.eleveId, key.debut, key.fin);
});

final coursParPeriodeProvider =
    StreamProvider.autoDispose.family<List<Cour>, PeriodeCle>((ref, key) {
  return ref
      .watch(coursDaoProvider)
      .watchCoursEleveParPeriode(key.eleveId, key.debut, key.fin);
});

final recapPeriodeTousProvider =
    StreamProvider.autoDispose.family<RecapMois, PeriodeSeuleCle>((ref, key) {
  return ref
      .watch(coursDaoProvider)
      .watchRecapPeriodeTous(key.debut, key.fin);
});

final coursParPeriodeTousProvider =
    StreamProvider.autoDispose.family<List<Cour>, PeriodeSeuleCle>((ref, key) {
  return ref
      .watch(coursDaoProvider)
      .watchCoursParPeriodeTous(key.debut, key.fin);
});
