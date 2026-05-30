import 'package:drift/drift.dart';
import '../app_database.dart';
import '../../../shared/models/eleve_avec_payeur.dart';
import '../../../core/security/encryption_service.dart';

part 'payeurs_dao.g.dart';

@DriftAccessor(tables: [Payeurs, Eleves])
class PayeursDao extends DatabaseAccessor<AppDatabase> with _$PayeursDaoMixin {
  PayeursDao(super.db);

  // ── Helpers privés ────────────────────────────────

  PayeursCompanion _chiffrerCompanion(PayeursCompanion p) {
    return p.copyWith(
      prenom: p.prenom.present
          ? Value(EncryptionService.chiffrer(p.prenom.value) ?? '')
          : const Value.absent(),
      nom: p.nom.present
          ? Value(EncryptionService.chiffrer(p.nom.value) ?? '')
          : const Value.absent(),
      telephone: p.telephone.present
          ? Value(EncryptionService.chiffrer(p.telephone.value) ?? '')
          : const Value.absent(),
      adress: p.adress.present
          ? Value(EncryptionService.chiffrer(p.adress.value) ?? '')
          : const Value.absent(),
    );
  }

  Payeur _dechiffrerPayeur(Payeur p) {
    return p.copyWith(
      prenom: EncryptionService.dechiffrer(p.prenom) ?? p.prenom,
      nom: EncryptionService.dechiffrer(p.nom) ?? p.nom,
      telephone: EncryptionService.dechiffrer(p.telephone) ?? p.telephone,
      adress: EncryptionService.dechiffrer(p.adress) ?? p.adress,
    );
  }

  // ── Lectures ──────────────────────────────────────

  Stream<List<Payeur>> watchPayeursActifs() {
    return (select(payeurs)
          ..where((p) => p.actif.equals(true))
          ..orderBy([(p) => OrderingTerm.asc(p.prenom)]))
        .watch()
        .map((liste) => liste.map(_dechiffrerPayeur).toList());
  }

  Stream<List<Payeur>> watchPayeursCesuPlus() {
    return (select(payeurs)
          ..where((p) => p.cesuPlus.equals(true))
          ..orderBy([(p) => OrderingTerm.asc(p.prenom)]))
        .watch()
        .map((liste) => liste.map(_dechiffrerPayeur).toList());
  }

  Future<Payeur?> getPayeur(int id) async {
    final payeur = await (select(payeurs)..where((p) => p.payeurId.equals(id)))
        .getSingleOrNull();
    return payeur == null ? null : _dechiffrerPayeur(payeur);
  }

  Future<Payeur?> getPayeurByEleve(int eleveId) async {
    final eleve = await (select(eleves)
          ..where((e) => e.elevesId.equals(eleveId)))
        .getSingleOrNull();
    if (eleve == null) return null;

    final payeur = await (select(payeurs)
          ..where((p) => p.payeurId.equals(eleve.payeurId)))
        .getSingleOrNull();
    return payeur == null ? null : _dechiffrerPayeur(payeur);
  }

  Stream<List<Eleve>> watchElevesByPayeur(int payeurId) {
    return (select(eleves)
          ..where((e) => e.payeurId.equals(payeurId))
          ..orderBy([(e) => OrderingTerm.asc(e.prenom)]))
        .watch();
  }

  // Recherche en Dart après déchiffrement — SQL ne peut pas chercher
  // dans des données chiffrées
  Stream<List<Payeur>> searchPayeurs(String query,
      {bool inclureArchives = false}) {
    return (select(payeurs)
          ..where((p) =>
              inclureArchives ? const Constant(true) : p.actif.equals(true))
          ..orderBy([(p) => OrderingTerm.asc(p.prenom)]))
        .watch()
        .map((liste) {
      final dechiffres = liste.map(_dechiffrerPayeur).toList();
      final queryLower = query.toLowerCase();
      return dechiffres
          .where((p) =>
              p.prenom.toLowerCase().contains(queryLower) ||
              p.nom.toLowerCase().contains(queryLower) ||
              p.adress.toLowerCase().contains(queryLower) ||
              p.telephone.toLowerCase().contains(queryLower))
          .toList();
    });
  }

  Future<EleveAvecPayeur?> getEleveAvecPayeur(int eleveId) async {
    final query = select(eleves).join([
      innerJoin(payeurs, payeurs.payeurId.equalsExp(eleves.payeurId)),
    ])
      ..where(eleves.elevesId.equals(eleveId));

    final row = await query.getSingleOrNull();
    if (row == null) return null;

    return EleveAvecPayeur(
      eleve: row.readTable(eleves),
      payeur: _dechiffrerPayeur(row.readTable(payeurs)),
    );
  }

  // ── Écritures ─────────────────────────────────────

  Future<int> insertPayeur(PayeursCompanion companion) {
    return into(payeurs).insert(_chiffrerCompanion(companion));
  }

  Future<bool> updatePayeur(PayeursCompanion companion) {
    return update(payeurs).replace(_chiffrerCompanion(companion));
  }

  Future<int> archiverPayeur(int id) {
    return (update(payeurs)..where((p) => p.payeurId.equals(id)))
        .write(const PayeursCompanion(actif: Value(false)));
  }

  Future<int> reactiverPayeur(int id) {
    return (update(payeurs)..where((p) => p.payeurId.equals(id)))
        .write(const PayeursCompanion(actif: Value(true)));
  }

  Future<int> deletePayeur(int id) {
    return (delete(payeurs)..where((p) => p.payeurId.equals(id))).go();
  }
}
