import 'package:drift/drift.dart';
import '../app_database.dart';

part 'payeurs_dao.g.dart';

@DriftAccessor(tables: [Payeurs, Eleves])
class PayeursDao extends DatabaseAccessor<AppDatabase> with _$PayeursDaoMixin {
  PayeursDao(super.db);

  Stream<List<Payeur>> watchPayeursActifs(){
    return (select(payeurs)
      ..where((p) => p.actif.equals(true))
      ..orderBy([(p) => OrderingTerm.asc(p.prenom)])
    ).watch();
  }

  Stream<List<Payeur>> watchPayeursCesuPlus(){
    return (select(payeurs)
      ..where((p) => p.cesuPlus.equals(true))
      ..orderBy([(p) => OrderingTerm.asc(p.prenom)])
    ).watch();
  }

  Future<Payeur?> getPayeur(int id){
    return (select(payeurs)
      ..where((p) => p.payeurId.equals(id))
    ).getSingleOrNull();
  }

 Future<Payeur?> getPayeurByEleve(int eleveId) async {
  final eleve = await (select(eleves)
    ..where((e) => e.elevesId.equals(eleveId))
  ).getSingleOrNull();
  
  if (eleve == null) return null;
  
  return (select(payeurs)
    ..where((p) => p.payeurId.equals(eleve.payeurId))
  ).getSingleOrNull();
}

  Stream<List<Eleve>> watchElevesByPayeur(int payeurId) {
    return (select(eleves)
      ..where((e) => e.payeurId.equals(payeurId))
      ..orderBy([(e) => OrderingTerm.asc(e.prenom)])
    ).watch();
  }

  Stream<List<Payeur>> searchPayeurs(String query, {bool inclureArchives = false}) {
    final selectQuery = (select(payeurs)
      ..where((p) { 
        final condResearch =  
          p.nom.like('%$query%') |
          p.prenom.like('%$query%') |
          p.adress.like('%$query%') |
          p.telephone.like('%$query%');

        return inclureArchives ? condResearch : condResearch & p.actif.equals(true);
      })
      ..orderBy([(p) => OrderingTerm.asc(p.nom)])
    );

    return selectQuery.watch();
  }

  Future<int> insertPayeur(PayeursCompanion companion){
    return into(payeurs).insert(companion);
  }

  Future<bool> updatePayeur(PayeursCompanion companion){
    return update(payeurs).replace(companion);
  }

  Future<int> archiverPayeur(int id){
    return (update(payeurs)
      ..where((p) => p.payeurId.equals(id))
    ).write(const PayeursCompanion(actif: Value(false)));
  }

  Future<int> reactiverPayeur(int id){
    return (update(payeurs)
      ..where((p) => p.payeurId.equals(id))
    ).write(const PayeursCompanion(actif: Value(true)));
  }

  Future<int> deletePayeur(int id){
    return (delete(payeurs)
      ..where((p) => p.payeurId.equals(id))
      ).go();
  }

}