import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/models/recap_mois.dart';
import '../models/mois_info.dart';

final moisAvecCoursProvider = StreamProvider<List<MoisInfo>>((ref) {
  return ref.watch(coursDaoProvider).watchCoursValides().map((liste) {
    final map =
        <String, ({DateTime date, int nb, double total, double paye})>{};
    for (final c in liste) {
      final date = c.dateReelle ?? c.datePrevue;
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      final prev = map[key];
      final montant = c.montant ?? 0.0;
      map[key] = (
        date: DateTime(date.year, date.month, 1),
        nb: (prev?.nb ?? 0) + 1,
        total: (prev?.total ?? 0) + montant,
        paye: (prev?.paye ?? 0) + (c.paye ? montant : 0),
      );
    }
    return map.entries
        .map((e) => MoisInfo(
              mois: e.value.date,
              nbCours: e.value.nb,
              montantTotal: e.value.total,
              montantPaye: e.value.paye,
            ))
        .toList()
      ..sort((a, b) => b.mois.compareTo(a.mois));
  });
});

typedef MoisCle = ({int mois, int annee});
typedef EleveMoisCle = ({int eleveId, int mois, int annee});
typedef PeriodeCle = ({int eleveId, DateTime debut, DateTime fin});
typedef PeriodeSeuleCle = ({DateTime debut, DateTime fin});

final coursParMoisProvider =
    StreamProvider.family<List<Cour>, MoisCle>((ref, key) {
  return ref.watch(coursDaoProvider).watchCoursParMois(key.mois, key.annee);
});

final coursEleveParMoisProvider =
    StreamProvider.family<List<Cour>, EleveMoisCle>((ref, key) {
  final debut = DateTime(key.annee, key.mois, 1);
  final fin = DateTime(key.annee, key.mois + 1, 1);
  return ref
      .watch(coursDaoProvider)
      .watchCoursEleveParPeriode(key.eleveId, debut, fin);
});

final recapPeriodeProvider =
    StreamProvider.family<RecapMois, PeriodeCle>((ref, key) {
  return ref
      .watch(coursDaoProvider)
      .watchRecapPeriode(key.eleveId, key.debut, key.fin);
});

final coursParPeriodeProvider =
    StreamProvider.family<List<Cour>, PeriodeCle>((ref, key) {
  return ref
      .watch(coursDaoProvider)
      .watchCoursEleveParPeriode(key.eleveId, key.debut, key.fin);
});

final recapPeriodeTousProvider =
    StreamProvider.family<RecapMois, PeriodeSeuleCle>((ref, key) {
  return ref
      .watch(coursDaoProvider)
      .watchRecapPeriodeTous(key.debut, key.fin);
});

final coursParPeriodeTousProvider =
    StreamProvider.family<List<Cour>, PeriodeSeuleCle>((ref, key) {
  return ref
      .watch(coursDaoProvider)
      .watchCoursParPeriodeTous(key.debut, key.fin);
});
