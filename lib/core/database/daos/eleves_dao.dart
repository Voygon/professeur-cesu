import 'package:drift/drift.dart';
import '../app_database.dart';

part 'eleves_dao.g.dart';

@DriftAccessor(tables: [Eleves])
class ElevesDao extends DatabaseAccessor<AppDatabase> with _$ElevesDaoMixin {
  ElevesDao(super.db);

  Stream<List<Eleve>> watchElevesActifs() {
    return (select(eleves)
      ..where((e) => e.actif.equals(true))
      ..orderBy([(e) => OrderingTerm.asc(e.prenom)])
    ).watch();
  }

  Stream<List<Eleve>> watchElevesHebdo() {
    return (select(eleves)
      ..where((e) => e.actif.equals(true) & e.hebdo.equals(true))
      ..orderBy([(e) => OrderingTerm.asc(e.prenom)])
    ).watch();
  }

  Future<Eleve?> getEleve(int id) {
    return (select(eleves)
      ..where((e) => e.elevesId.equals(id))
    ).getSingleOrNull();
  }

  Stream<List<Eleve>> searchEleves(String query, {bool inclureArchives = false}) {
    final selectQuery = (select(eleves)
      ..where((e) { 
        final condResearch =  
          e.nom.like('%$query%') |
          e.prenom.like('%$query%') |
          e.adress.like('%$query%') |
          e.telephone.like('%$query%');

        return inclureArchives ? condResearch : condResearch & e.actif.equals(true);
      })
      ..orderBy([(e) => OrderingTerm.asc(e.prenom)])
    );

    return selectQuery.watch();
  }

  Future<int> insertEleve(ElevesCompanion companion){
    return into(eleves).insert(companion);
  }

  Future<bool> updateEleve(ElevesCompanion companion){
    return update(eleves).replace(companion);
  }

  Future<int> archiverEleve(int id){
    return (update(eleves)
      ..where((e) => e.elevesId.equals(id))
    ).write(const ElevesCompanion(actif: Value(false)));
  }

  Future<int> reactiverEleve(int id){
    return (update(eleves)
      ..where((e) => e.elevesId.equals(id))
    ).write(const ElevesCompanion(actif: Value(true)));
  }

  Future<int> deleteEleve(int id){
    return (delete(eleves)
      ..where((e) => e.elevesId.equals(id))
      ).go();
  }


}