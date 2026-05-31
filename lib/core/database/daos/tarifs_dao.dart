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
      ..orderBy([(t) => OrderingTerm.asc(t.duree)])
    ).watch();
  }

  Stream<List<Tarif>> watchTarifsArchives() {
    return (select(tarifs)
      ..where((t) => t.dateFin.isNotNull())
      ..orderBy([(t) => OrderingTerm.asc(t.duree), (t) => OrderingTerm.desc(t.dateDebut)])
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

  Future<void> reactiverTarif(int tarifsId) {
    return transaction(() async {
      final tarif = await getTarif(tarifsId);
      if (tarif == null) return;
      final actif = await getTarifEnVigueur(tarif.duree, DateTime.now());
      if (actif != null) {
        await (update(tarifs)..where((t) => t.tarifsId.equals(actif.tarifsId)))
            .write(TarifsCompanion(dateFin: Value(DateTime.now())));
      }
      await (update(tarifs)..where((t) => t.tarifsId.equals(tarifsId)))
          .write(const TarifsCompanion(dateFin: Value(null)));
    });
  }

  Future<void> fermerTarif(int tarifsId) async {
    await (update(tarifs)..where((t) => t.tarifsId.equals(tarifsId)))
        .write(TarifsCompanion(dateFin: Value(DateTime.now())));
  }

  Future<int> deleteTarif(int id){
    return (delete(tarifs)
      ..where((t) => t.tarifsId.equals(id))
    ).go();
  }

  Future<double?> calculerMontant(int dureeMinutes) async {
    final tarifExact = await getTarifEnVigueur(dureeMinutes, DateTime.now());
    if (tarifExact != null) return tarifExact.prix;

    final tarifHeure = await getTarifEnVigueur(60, DateTime.now());
    if (tarifHeure == null) return null;

    return (dureeMinutes / 60) * tarifHeure.prix;
  }
}