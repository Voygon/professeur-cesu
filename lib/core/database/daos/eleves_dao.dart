import 'package:drift/drift.dart';
import '../app_database.dart';
import '../../../core/security/encryption_service.dart';
part 'eleves_dao.g.dart';

@DriftAccessor(tables: [Eleves])
class ElevesDao extends DatabaseAccessor<AppDatabase> with _$ElevesDaoMixin {
  ElevesDao(super.db);

  // Chiffre les champs sensibles d'un companion avant insertion/update
  ElevesCompanion _chiffrerCompanion(ElevesCompanion e) {
    return e.copyWith(
      prenom: e.prenom.present
          ? Value(EncryptionService.chiffrer(e.prenom.value) ?? '')
          : const Value.absent(),
      nom: e.nom.present
          ? Value(EncryptionService.chiffrer(e.nom.value) ?? '')
          : const Value.absent(),
      nomPere: e.nomPere.present
          ? Value(EncryptionService.chiffrer(e.nomPere.value))
          : const Value.absent(),
      nomMere: e.nomMere.present
          ? Value(EncryptionService.chiffrer(e.nomMere.value))
          : const Value.absent(),
      telephone: e.telephone.present
          ? Value(EncryptionService.chiffrer(e.telephone.value) ?? '')
          : const Value.absent(),
      adress: e.adress.present
          ? Value(EncryptionService.chiffrer(e.adress.value) ?? '')
          : const Value.absent(),
    );
  }

// Déchiffre les champs sensibles d'un objet Eleve après lecture
  Eleve _dechiffrerEleve(Eleve e) {
    return e.copyWith(
      prenom: EncryptionService.dechiffrer(e.prenom) ?? e.prenom,
      nom: EncryptionService.dechiffrer(e.nom) ?? e.nom,
      nomPere: Value(EncryptionService.dechiffrer(e.nomPere)),
      nomMere: Value(EncryptionService.dechiffrer(e.nomMere)),
      telephone: EncryptionService.dechiffrer(e.telephone),
      adress: EncryptionService.dechiffrer(e.adress) ?? e.adress,
    );
  }

  Stream<List<Eleve>> watchElevesActifs() {
    return (select(eleves)
          ..where((e) => e.actif.equals(true))
          ..orderBy([(e) => OrderingTerm.asc(e.prenom)]))
        .watch()
        .map((liste) => liste.map(_dechiffrerEleve).toList());
  }

  Stream<List<Eleve>> watchElevesArchives() {
    return (select(eleves)
          ..where((e) => e.actif.equals(false))
          ..orderBy([(e) => OrderingTerm.asc(e.prenom)]))
        .watch()
        .map((liste) => liste.map(_dechiffrerEleve).toList());
  }

  Stream<List<Eleve>> watchElevesHebdo() {
    return (select(eleves)
          ..where((e) => e.actif.equals(true) & e.hebdo.equals(true))
          ..orderBy([(e) => OrderingTerm.asc(e.prenom)]))
        .watch()
        .map((liste) => liste.map(_dechiffrerEleve).toList());
  }

  Future<Eleve?> getEleve(int id) async {
    final eleve = await (select(eleves)..where((e) => e.elevesId.equals(id)))
        .getSingleOrNull();
    return eleve == null ? null : _dechiffrerEleve(eleve);
  }

  Stream<List<Eleve>> searchEleves(String query,
      {bool inclureArchives = false}) {
    return (select(eleves)
          ..where((e) =>
              inclureArchives ? const Constant(true) : e.actif.equals(true))
          ..orderBy([(e) => OrderingTerm.asc(e.prenom)]))
        .watch()
        .map((liste) {
      final dechiffres = liste.map(_dechiffrerEleve).toList();
      final queryLower = query.toLowerCase();
      return dechiffres
          .where((e) =>
              e.prenom.toLowerCase().contains(queryLower) ||
              e.nom.toLowerCase().contains(queryLower) ||
              (e.adress.toLowerCase().contains(queryLower)) ||
              (e.telephone.toLowerCase().contains(queryLower)))
          .toList();
    });
  }

  Future<int> insertEleve(ElevesCompanion companion) {
    return into(eleves).insert(_chiffrerCompanion(companion));
  }

  Future<bool> updateEleve(ElevesCompanion companion) async {
    final id = companion.elevesId.value;
    final count = await (update(eleves)..where((e) => e.elevesId.equals(id)))
        .write(_chiffrerCompanion(companion));
    return count > 0;
  }

  Future<int> archiverEleve(int id) {
    return (update(eleves)..where((e) => e.elevesId.equals(id)))
        .write(const ElevesCompanion(actif: Value(false)));
  }

  Future<int> reactiverEleve(int id) {
    return (update(eleves)..where((e) => e.elevesId.equals(id)))
        .write(const ElevesCompanion(actif: Value(true)));
  }

  Future<int> deleteEleve(int id) {
    return (delete(eleves)..where((e) => e.elevesId.equals(id))).go();
  }
}
