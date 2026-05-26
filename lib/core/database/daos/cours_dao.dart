import 'package:drift/drift.dart';
import '../app_database.dart';

part 'cours_dao.g.dart';

@DriftAccessor(tables: [Cours, Eleves])
class CoursDao extends DatabaseAccessor<AppDatabase> with _$CoursDaoMixin {
  CoursDao(super.db);

  Future<Cour?>getCours(int id){
    return (select(cours)
      ..where((c) => c.coursId.equals(id))
      ).getSingleOrNull();
  }

  Stream<List<Cour>> watchCoursDuJour({bool inclureAnnules = false}){

    final maintenant = DateTime.now();
    final debutJour = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final finJour = debutJour.add(const Duration(days: 1));

    final query = (select(cours)
      ..where((c) => c.datePrevue.isBiggerOrEqualValue(debutJour) &
        c.datePrevue.isSmallerThanValue(finJour))
      ..orderBy([(c) => OrderingTerm.asc(c.datePrevue)])
    );

    if (!inclureAnnules) {
      query.where((c) => c.statut.isNotValue('annule'));
    }

    return query.watch();
  }

  Stream<List<Cour>> watchCoursSemaine(DateTime lundiSemaine, {bool inclureAnnules = false}){
  
    final finSemaine = lundiSemaine.add(const Duration(days: 7));

    final query = (select(cours)
      ..where((c) => c.datePrevue.isBiggerOrEqualValue(lundiSemaine) &
        c.datePrevue.isSmallerThanValue(finSemaine))
      ..orderBy([(c) => OrderingTerm.asc(c.datePrevue)])
    );

    if (!inclureAnnules) {
      query.where((c) => c.statut.isNotValue('annule'));
    }

    return query.watch();
  }

  Stream<List<Cour>> watchCoursEleve(int eleveId){
    return (select(cours)
      ..where((c) => c.elevesId.equals(eleveId))
      ..orderBy([(c) => OrderingTerm.desc(c.datePrevue)])
    ).watch();
  }

  Stream<List<Cour>> watchCoursEnAttente(){
    return (select(cours)
      ..where((c) => c.statut.equals('prevu') &
        c.datePrevue.isSmallerThanValue(DateTime.now()))
      ..orderBy([(c) => OrderingTerm.asc(c.datePrevue)])
    ).watch();
  }

  Future<bool> updateCours(CoursCompanion cour){
    return update(cours).replace(cour);
  }

  Future<int> deleteCours(int id){
    return (delete(cours)
      ..where((c) => c.coursId.equals(id))
    ).go();
  }

  Future<void> validerCours(int coursId, {required double montant, int? dureeReelle, int? tarifId}) async {
    await (update(cours)..where((c) => c.coursId.equals(coursId))).write(
      CoursCompanion(
        statut: const Value('effectue'),
        dateReelle: Value(DateTime.now()),
        montant: Value(montant),
        dureeReelle: dureeReelle != null ? Value(dureeReelle) : const Value.absent(),
        tarifsId: tarifId != null ? Value(tarifId) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}