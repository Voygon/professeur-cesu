import 'package:drift/drift.dart';
import '../../../shared/models/recap_mois.dart';
import '../../../shared/models/enums.dart';
import '../app_database.dart';

part 'cours_dao.g.dart';

@DriftAccessor(tables: [Cours, Eleves])
class CoursDao extends DatabaseAccessor<AppDatabase> with _$CoursDaoMixin {
  CoursDao(super.db);

  Future<Cour?> getCours(int id) {
    return (select(cours)..where((c) => c.coursId.equals(id)))
        .getSingleOrNull();
  }

  Stream<List<Cour>> watchCoursDuJour({bool inclureAnnules = false}) {
    final maintenant = DateTime.now();
    final debutJour =
        DateTime(maintenant.year, maintenant.month, maintenant.day);
    final finJour = debutJour.add(const Duration(days: 1));

    final query = (select(cours)
      ..where((c) =>
          c.datePrevue.isBiggerOrEqualValue(debutJour) &
          c.datePrevue.isSmallerThanValue(finJour))
      ..orderBy([(c) => OrderingTerm.asc(c.datePrevue)]));

    if (!inclureAnnules) {
      query.where((c) => c.statut.isNotValue(StatutCours.annule.toDb()));
    }

    return query.watch();
  }

  Stream<List<Cour>> watchCoursSemaine(DateTime lundiSemaine,
      {bool inclureAnnules = false}) {
    final finSemaine = lundiSemaine.add(const Duration(days: 7));

    final query = (select(cours)
      ..where((c) =>
          c.datePrevue.isBiggerOrEqualValue(lundiSemaine) &
          c.datePrevue.isSmallerThanValue(finSemaine))
      ..orderBy([(c) => OrderingTerm.asc(c.datePrevue)]));

    if (!inclureAnnules) {
      query.where((c) => c.statut.isNotValue(StatutCours.annule.toDb()));
    }

    return query.watch();
  }

  Stream<List<Cour>> watchCoursEleve(int eleveId) {
    return (select(cours)
          ..where((c) => c.elevesId.equals(eleveId))
          ..orderBy([(c) => OrderingTerm.desc(c.datePrevue)]))
        .watch();
  }

  Stream<List<Cour>> watchCoursEnAttente() {
    return (select(cours)
          ..where((c) =>
              c.statut.equals(StatutCours.prevu.toDb()) &
              c.datePrevue.isSmallerThanValue(DateTime.now()))
          ..orderBy([(c) => OrderingTerm.asc(c.datePrevue)]))
        .watch();
  }

  Future<void> validerCours(int coursId,
      {required double montant, int? dureeReelle, int? tarifId}) async {
    await (update(cours)..where((c) => c.coursId.equals(coursId))).write(
      CoursCompanion(
        statut: Value(StatutCours.effectue.toDb()),
        montant: Value(montant),
        dureeReelle:
            dureeReelle != null ? Value(dureeReelle) : const Value.absent(),
        tarifsId: tarifId != null ? Value(tarifId) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> annulerCours(int coursId, {String? notes}) async {
    await (update(cours)..where((c) => c.coursId.equals(coursId))).write(
      CoursCompanion(
        statut: Value(StatutCours.annule.toDb()),
        notes: notes != null ? Value(notes) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> modifierCours(int coursId,
      {DateTime? nouvelleDate,
      int? nouvelleDuree,
      int? tarifId,
      String? notes}) async {
    await (update(cours)..where((c) => c.coursId.equals(coursId))).write(
      CoursCompanion(
        dateReelle:
            nouvelleDate != null ? Value(nouvelleDate) : const Value.absent(),
        dureeReelle:
            nouvelleDuree != null ? Value(nouvelleDuree) : const Value.absent(),
        tarifsId: tarifId != null ? Value(tarifId) : const Value.absent(),
        statut: Value(StatutCours.modifie.toDb()),
        notes: notes != null ? Value(notes) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<Cour>> getCoursValidesParMois(int eleveId, int mois, int annee) {
    final debutMois = DateTime(annee, mois, 1);
    final finMois = DateTime(annee, mois + 1, 1);

    return (select(cours)
          ..where((c) {
            final dateEffective =
                coalesce<DateTime>([c.dateReelle, c.datePrevue]);
            return c.elevesId.equals(eleveId) &
                (c.statut.equals(StatutCours.effectue.toDb()) |
                    c.statut.equals(StatutCours.modifie.toDb())) &
                dateEffective.isBiggerOrEqualValue(debutMois) &
                dateEffective.isSmallerThanValue(finMois);
          }))
        .get();
  }

  Future<bool> coursExisteDeja(int eleveId, DateTime datePrevue) async {
    final query = await (select(cours)
          ..where((c) =>
              c.elevesId.equals(eleveId) & c.datePrevue.equals(datePrevue))
          ..limit(1))
        .get();
    return query.isNotEmpty;
  }

  Future<bool> planifierCoursSemaine(Eleve eleve, DateTime lundiSemaine) async {
    if (eleve.jourSemaine == null || eleve.heureDebut == null) return false;

    try {
      final jourCours =
          lundiSemaine.add(Duration(days: eleve.jourSemaine! - 1));
      final parties = eleve.heureDebut!.split(':');

      // Vérifie que le format est bien HH:mm avant de parser
      if (parties.length != 2) return false;

      final heure = int.parse(parties[0]);
      final minute = int.parse(parties[1]);

      // Vérifie que les valeurs sont dans les bornes valides
      if (heure < 0 || heure > 23 || minute < 0 || minute > 59) return false;

      final datePrevue = DateTime(
          jourCours.year, jourCours.month, jourCours.day, heure, minute);

      if (await coursExisteDeja(eleve.elevesId, datePrevue)) return false;

      await into(cours).insert(CoursCompanion(
        elevesId: Value(eleve.elevesId),
        datePrevue: Value(datePrevue),
        statut: Value(StatutCours.prevu.toDb()),
      ));

      return true;
    } catch (e) {
      // Si une erreur inattendue survient (format invalide, overflow...),
      // on refuse silencieusement plutôt que de crasher l'app
      return false;
    }
  }

  Future<int> planifierCoursSemainePourTous(
      List<Eleve> eleveHebo, DateTime lundiSemaine) async {
    int nbCrees = 0;
    for (final eleve in eleveHebo) {
      if (await planifierCoursSemaine(eleve, lundiSemaine)) nbCrees++;
    }
    return nbCrees;
  }

  Future<bool> updateCours(CoursCompanion cour) {
    return update(cours).replace(cour);
  }

  Future<int> deleteCours(int id) {
    return (delete(cours)..where((c) => c.coursId.equals(id))).go();
  }

  Future<int> insertCoursExceptionnel(CoursCompanion companion) {
    return into(cours)
        .insert(companion.copyWith(exceptionnel: const Value(true)));
  }

  Future<void> marquerCoursPaye(int coursId) async {
    await (update(cours)..where((c) => c.coursId.equals(coursId)))
        .write(CoursCompanion(
      paye: const Value(true),
      datePaiement: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> marquerCoursNonPaye(int coursId) async {
    await (update(cours)..where((c) => c.coursId.equals(coursId)))
        .write(CoursCompanion(
      paye: const Value(false),
      datePaiement: const Value(null),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> marquerMoisPaye(int eleveId, int mois, int annee) async {
    final debutMois = DateTime(annee, mois, 1);
    final finMois = DateTime(annee, mois + 1, 1);
    await (update(cours)
          ..where((c) {
            final dateEffective =
                coalesce<DateTime>([c.dateReelle, c.datePrevue]);
            return c.elevesId.equals(eleveId) &
                (c.statut.equals(StatutCours.effectue.toDb()) |
                    c.statut.equals(StatutCours.modifie.toDb())) &
                dateEffective.isBiggerOrEqualValue(debutMois) &
                dateEffective.isSmallerThanValue(finMois);
          }))
        .write(CoursCompanion(
      paye: const Value(true),
      datePaiement: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Stream<List<Cour>> watchCoursNonPayes() {
    return (select(cours)
          ..where((c) =>
              (c.statut.equals(StatutCours.effectue.toDb()) |
                  c.statut.equals(StatutCours.modifie.toDb())) &
              c.paye.equals(false))
          ..orderBy([
            (c) {
              final dateEffective =
                  coalesce<DateTime>([c.dateReelle, c.datePrevue]);
              return OrderingTerm.asc(dateEffective);
            }
          ]))
        .watch();
  }

  Stream<List<Cour>> watchCoursPayesParMois(int eleveId, int mois, int annee) {
    final debutMois = DateTime(annee, mois, 1);
    final finMois = DateTime(annee, mois + 1, 1);

    return (select(cours)
          ..where((c) {
            final dateEffective =
                coalesce<DateTime>([c.dateReelle, c.datePrevue]);
            return c.elevesId.equals(eleveId) &
                (c.statut.equals(StatutCours.effectue.toDb()) |
                    c.statut.equals(StatutCours.modifie.toDb())) &
                dateEffective.isBiggerOrEqualValue(debutMois) &
                dateEffective.isSmallerThanValue(finMois) &
                c.paye.equals(true);
          }))
        .watch();
  }

  Future<RecapMois> getRecapMois(int eleveId, int mois, int annee) async {
    final debutMois = DateTime(annee, mois, 1);
    final finMois = DateTime(annee, mois + 1, 1);

    final nbCoursExpr = cours.coursId.count();
    final montantTotalExpr = cours.montant.sum();
    final nbPayesExpr = cours.coursId.count(filter: cours.paye.equals(true));
    final montantPayeExpr = cours.montant.sum(filter: cours.paye.equals(true));

    final query = selectOnly(cours)
      ..addColumns(
          [nbCoursExpr, montantTotalExpr, nbPayesExpr, montantPayeExpr])
      ..where(cours.elevesId.equals(eleveId) &
          (cours.statut.equals(StatutCours.effectue.toDb()) |
              cours.statut.equals(StatutCours.modifie.toDb())) &
          coalesce<DateTime>([cours.dateReelle, cours.datePrevue])
              .isBiggerOrEqualValue(debutMois) &
          coalesce<DateTime>([cours.dateReelle, cours.datePrevue])
              .isSmallerThanValue(finMois));

    // getSingleOrNull au lieu de getSingle — retourne null si erreur
    final result = await query.getSingleOrNull();

    // Si pas de résultat, on retourne un RecapMois vide plutôt que de crasher
    if (result == null) {
      return RecapMois(
        nbCoursValides: 0,
        nbCoursPayes: 0,
        montantTotal: 0.0,
        montantPaye: 0.0,
        montantRestant: 0.0,
        mois: mois,
        annee: annee,
      );
    }

    final montantTotal = result.read(montantTotalExpr) ?? 0.0;
    final montantPaye = result.read(montantPayeExpr) ?? 0.0;

    return RecapMois(
      nbCoursValides: result.read(nbCoursExpr) ?? 0,
      nbCoursPayes: result.read(nbPayesExpr) ?? 0,
      montantTotal: montantTotal,
      montantPaye: montantPaye,
      montantRestant: montantTotal - montantPaye,
      mois: mois,
      annee: annee,
    );
  }
}
