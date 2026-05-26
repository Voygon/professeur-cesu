import 'package:drift/drift.dart';
import '../app_database.dart';

part 'tarifs_dao.g.dart';

@DriftAccessor(tables: [Tarifs])
class TarifsDao extends DatabaseAccessor<AppDatabase> with _$TarifsDaoMixin {
  TarifsDao(super.db);

  Future<Tarif?> getTarif(int id){
    return (select(tarifs)
      ..where((t) => t.tarifsId.equals(id))
    ).getSingleOrNull();
  }

  Stream<List<Tarif>> watchTarifEnCours(){
    return (select(tarifs)
      ..where((t) => t.dateFin.isNull())
    ).watch();
  }

  Stream<List<Tarif>> watchHistoriqueTarifs(int duree){
    return (select(tarifs)
      ..where((t) => t.duree.equals(duree))
      ..orderBy([(t) => OrderingTerm.desc(t.dateDebut)])
    ).watch();
  }

  Future<Tarif?> getTarifEnVigueur(int duree, DateTime date){
    return (select(tarifs)
      ..where((t) => t.duree.equals(duree) & t.dateDebut.isSmallerOrEqualValue (date)
      & (t.dateFin.isNull() | t.dateFin.isBiggerOrEqualValue(date)))
    ).getSingleOrNull();
  }

  Future<int> creerNouveauTarif(int duree, double nouveauPrix, DateTime dateChangement){
    return transaction(() async {
      final ancien = await getTarifEnVigueur(duree, dateChangement);

      if (ancien != null) {
        await (update(tarifs)..where((t) => t.tarifsId.equals(ancien.tarifsId))
        ).write(TarifsCompanion(dateFin: Value(dateChangement)));
      }

      final nouvelId = await into(tarifs).insert(TarifsCompanion(
        duree: Value(duree),
        prix: Value(nouveauPrix),
        dateDebut: Value(dateChangement),
      ));

      return nouvelId;
    });
  }

  Future<bool> updateTarif(TarifsCompanion tarif){
    return update(tarifs).replace(tarif);
  }

  Future<int> deleteTarif(int id){
    return (delete(tarifs)
      ..where((t) => t.tarifsId.equals(id))
    ).go();
  }
}