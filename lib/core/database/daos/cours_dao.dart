import 'package:drift/drift.dart';
import '../../../shared/models/recap_mois.dart';
import '../../../shared/models/mois_info.dart';
import '../../../shared/models/enums.dart';
import '../../notifications/notification_service.dart';
import '../app_database.dart';

part 'cours_dao.g.dart';

@DriftAccessor(tables: [Cours, Eleves])
class CoursDao extends DatabaseAccessor<AppDatabase> with _$CoursDaoMixin {
  CoursDao(super.db);

  Future<Cour?> getCours(int id) {
    return (select(cours)..where((c) => c.coursId.equals(id)))
        .getSingleOrNull();
  }

  // Planifie la notification si le cours n'est pas annulé.
  Future<void> planifierNotifSiNecessaire(int coursId, Eleve eleve) async {
    final cour = await getCours(coursId);
    if (cour == null) return;
    if (cour.statut == StatutCours.annule.toDb()) return;
    await NotificationService.planifierNotificationCours(cour, eleve);
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

  Future<void> validerCours(
    int coursId, {
    required int montant,
    int? dureeReelle,
    int? tarifId,
    required Eleve eleve,
    bool paiementEspeces = false,
  }) async {
    await (update(cours)..where((c) => c.coursId.equals(coursId))).write(
      CoursCompanion(
        statut: Value(StatutCours.effectue.toDb()),
        montant: Value(montant),
        dureeReelle:
            dureeReelle != null ? Value(dureeReelle) : const Value.absent(),
        tarifsId: tarifId != null ? Value(tarifId) : const Value.absent(),
        paiementEspeces: Value(paiementEspeces),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await planifierNotifSiNecessaire(coursId, eleve);
  }

  Future<void> remettreEnAttente(int coursId, {required Eleve eleve}) async {
    await (update(cours)..where((c) => c.coursId.equals(coursId))).write(
      CoursCompanion(
        statut: Value(StatutCours.prevu.toDb()),
        montant: const Value(null),
        paye: const Value(false),
        paiementEspeces: const Value(false),
        datePaiement: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await planifierNotifSiNecessaire(coursId, eleve);
  }

  Future<void> annulerCours(int coursId, {String? notes}) async {
    await (update(cours)..where((c) => c.coursId.equals(coursId))).write(
      CoursCompanion(
        statut: Value(StatutCours.annule.toDb()),
        notes: notes != null ? Value(notes) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await NotificationService.annulerNotificationCours(coursId);
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
        statut: Value(StatutCours.effectue.toDb()),
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
                c.statut.equals(StatutCours.effectue.toDb()) &
                dateEffective.isBiggerOrEqualValue(debutMois) &
                dateEffective.isSmallerThanValue(finMois);
          }))
        .get();
  }

  Future<bool> coursExisteDeja(int eleveId, DateTime datePrevue) async {
    final query = await (select(cours)
          ..where((c) =>
              c.elevesId.equals(eleveId) &
              c.datePrevue.equals(datePrevue) &
              c.statut.isNotValue(StatutCours.annule.toDb()))
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

      if (parties.length != 2) return false;

      final heure = int.parse(parties[0]);
      final minute = int.parse(parties[1]);

      if (heure < 0 || heure > 23 || minute < 0 || minute > 59) return false;

      final datePrevue = DateTime(
          jourCours.year, jourCours.month, jourCours.day, heure, minute);

      if (await coursExisteDeja(eleve.elevesId, datePrevue)) return false;

      final id = await into(cours).insert(CoursCompanion(
        elevesId: Value(eleve.elevesId),
        datePrevue: Value(datePrevue),
        statut: Value(StatutCours.prevu.toDb()),
        dureeReelle: eleve.dureeCours != null
            ? Value(eleve.dureeCours)
            : const Value.absent(),
      ));

      final cour = await getCours(id);
      if (cour != null) {
        await NotificationService.planifierNotificationCours(cour, eleve);
      }

      return true;
    } catch (e) {
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

  Future<void> deplacerCours(
    int coursId,
    DateTime nouvelleDatePrevue, {
    required Eleve eleve,
  }) async {
    await (update(cours)..where((c) => c.coursId.equals(coursId))).write(
        CoursCompanion(datePrevue: Value(nouvelleDatePrevue)));
    await planifierNotifSiNecessaire(coursId, eleve);
  }

  /// Met à jour date et durée d'un cours prévu sans changer son statut.
  Future<void> mettreAJourCoursPrevus(
    int coursId, {
    required DateTime datePrevue,
    required int duree,
    required Eleve eleve,
  }) async {
    await (update(cours)..where((c) => c.coursId.equals(coursId))).write(
      CoursCompanion(
        datePrevue: Value(datePrevue),
        dureeReelle: Value(duree),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await planifierNotifSiNecessaire(coursId, eleve);
  }

  Future<bool> updateCours(CoursCompanion cour) {
    return update(cours).replace(cour);
  }

  Future<int> deleteCours(int id) async {
    await NotificationService.annulerNotificationCours(id);
    return (delete(cours)..where((c) => c.coursId.equals(id))).go();
  }

  Future<int> deleteCoursEleve(int eleveId) {
    return (delete(cours)..where((c) => c.elevesId.equals(eleveId))).go();
  }

  Future<int> insertCoursExceptionnel(
    CoursCompanion companion, {
    required Eleve eleve,
  }) async {
    final id = await into(cours).insert(
      companion.copyWith(exceptionnel: const Value(true)),
    );
    final cour = await getCours(id);
    if (cour != null) {
      await NotificationService.planifierNotificationCours(cour, eleve);
    }
    return id;
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
                c.statut.equals(StatutCours.effectue.toDb()) &
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
              c.statut.equals(StatutCours.effectue.toDb()) &
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
                c.statut.equals(StatutCours.effectue.toDb()) &
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
          cours.statut.equals(StatutCours.effectue.toDb()) &
          coalesce<DateTime>([cours.dateReelle, cours.datePrevue])
              .isBiggerOrEqualValue(debutMois) &
          coalesce<DateTime>([cours.dateReelle, cours.datePrevue])
              .isSmallerThanValue(finMois));

    final result = await query.getSingleOrNull();

    if (result == null) {
      return RecapMois(
        nbCoursValides: 0,
        nbCoursPayes: 0,
        montantTotal: 0,
        montantPaye: 0,
        montantRestant: 0,
        mois: mois,
        annee: annee,
      );
    }

    final montantTotal = result.read(montantTotalExpr) ?? 0;
    final montantPaye = result.read(montantPayeExpr) ?? 0;

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

  Stream<List<Cour>> watchCoursPeriode(DateTime debut, DateTime fin,
      {bool inclureAnnules = false}) {
    final query = select(cours)
      ..where((c) =>
          c.datePrevue.isBiggerOrEqualValue(debut) &
          c.datePrevue.isSmallerThanValue(fin))
      ..orderBy([(c) => OrderingTerm.asc(c.datePrevue)]);

    if (!inclureAnnules) {
      query.where((c) => c.statut.isNotValue(StatutCours.annule.toDb()));
    }
    return query.watch();
  }

  // ── Paiements ──────────────────────────────────────────────────────────────

  Stream<List<Cour>> watchCoursValides() {
    return (select(cours)
          ..where((c) => c.statut.equals(StatutCours.effectue.toDb())))
        .watch();
  }

  // Récap par mois agrégé en SQL (GROUP BY) plutôt que de charger tout
  // l'historique des cours en mémoire pour le regrouper côté Dart.
  Stream<List<MoisInfo>> watchMoisAvecCours() {
    final dateExpr = coalesce<DateTime>([cours.dateReelle, cours.datePrevue]);
    final anneeExpr = dateExpr.year;
    final moisExpr = dateExpr.month;
    final nbExpr = cours.coursId.count();
    final totalExpr = cours.montant.sum();
    final payeExpr = cours.montant.sum(filter: cours.paye.equals(true));

    final query = selectOnly(cours)
      ..addColumns([anneeExpr, moisExpr, nbExpr, totalExpr, payeExpr])
      ..where(cours.statut.equals(StatutCours.effectue.toDb()))
      ..groupBy([anneeExpr, moisExpr]);

    return query.watch().map((rows) {
      return rows.map((r) {
        final annee = r.read(anneeExpr)!;
        final mois = r.read(moisExpr)!;
        return MoisInfo(
          mois: DateTime(annee, mois, 1),
          nbCours: r.read(nbExpr) ?? 0,
          montantTotal: r.read(totalExpr) ?? 0,
          montantPaye: r.read(payeExpr) ?? 0,
        );
      }).toList()
        ..sort((a, b) => b.mois.compareTo(a.mois));
    });
  }

  Stream<List<Cour>> watchCoursParMois(int mois, int annee) {
    final debut = DateTime(annee, mois, 1);
    final fin = DateTime(annee, mois + 1, 1);
    return (select(cours)
          ..where((c) {
            final d = coalesce<DateTime>([c.dateReelle, c.datePrevue]);
            return c.statut.equals(StatutCours.effectue.toDb()) &
                d.isBiggerOrEqualValue(debut) &
                d.isSmallerThanValue(fin);
          })
          ..orderBy([(c) => OrderingTerm.asc(c.elevesId)]))
        .watch();
  }

  Stream<List<Cour>> watchCoursEleveParPeriode(
      int eleveId, DateTime debut, DateTime fin) {
    return (select(cours)
          ..where((c) {
            final d = coalesce<DateTime>([c.dateReelle, c.datePrevue]);
            return c.elevesId.equals(eleveId) &
                c.statut.equals(StatutCours.effectue.toDb()) &
                d.isBiggerOrEqualValue(debut) &
                d.isSmallerThanValue(fin);
          })
          ..orderBy([(c) {
            final d = coalesce<DateTime>([c.dateReelle, c.datePrevue]);
            return OrderingTerm.asc(d);
          }]))
        .watch();
  }

  Stream<List<Cour>> watchCoursParPeriodeTous(DateTime debut, DateTime fin) {
    return (select(cours)
          ..where((c) {
            final d = coalesce<DateTime>([c.dateReelle, c.datePrevue]);
            return c.statut.equals(StatutCours.effectue.toDb()) &
                d.isBiggerOrEqualValue(debut) &
                d.isSmallerThanValue(fin);
          })
          ..orderBy([(c) {
            final d = coalesce<DateTime>([c.dateReelle, c.datePrevue]);
            return OrderingTerm.asc(d);
          }]))
        .watch();
  }

  Stream<RecapMois> watchRecapPeriode(
      int eleveId, DateTime debut, DateTime fin) {
    final nbExpr = cours.coursId.count();
    final totalExpr = cours.montant.sum();
    final nbPayesExpr = cours.coursId.count(filter: cours.paye.equals(true));
    final payeExpr = cours.montant.sum(filter: cours.paye.equals(true));

    final query = selectOnly(cours)
      ..addColumns([nbExpr, totalExpr, nbPayesExpr, payeExpr])
      ..where(cours.elevesId.equals(eleveId) &
          cours.statut.equals(StatutCours.effectue.toDb()) &
          coalesce<DateTime>([cours.dateReelle, cours.datePrevue])
              .isBiggerOrEqualValue(debut) &
          coalesce<DateTime>([cours.dateReelle, cours.datePrevue])
              .isSmallerThanValue(fin));

    return query.watchSingleOrNull().map((r) {
      if (r == null) {
        return RecapMois(
          nbCoursValides: 0, nbCoursPayes: 0,
          montantTotal: 0, montantPaye: 0, montantRestant: 0,
          mois: debut.month, annee: debut.year,
        );
      }
      final total = r.read(totalExpr) ?? 0;
      final paye = r.read(payeExpr) ?? 0;
      return RecapMois(
        nbCoursValides: r.read(nbExpr) ?? 0,
        nbCoursPayes: r.read(nbPayesExpr) ?? 0,
        montantTotal: total,
        montantPaye: paye,
        montantRestant: total - paye,
        mois: debut.month,
        annee: debut.year,
      );
    });
  }

  Stream<RecapMois> watchRecapPeriodeTous(DateTime debut, DateTime fin) {
    final nbExpr     = cours.coursId.count();
    final totalExpr  = cours.montant.sum();
    final nbPayesExpr = cours.coursId.count(filter: cours.paye.equals(true));
    final payeExpr   = cours.montant.sum(filter: cours.paye.equals(true));

    final query = selectOnly(cours)
      ..addColumns([nbExpr, totalExpr, nbPayesExpr, payeExpr])
      ..where(
          cours.statut.equals(StatutCours.effectue.toDb()) &
          coalesce<DateTime>([cours.dateReelle, cours.datePrevue])
              .isBiggerOrEqualValue(debut) &
          coalesce<DateTime>([cours.dateReelle, cours.datePrevue])
              .isSmallerThanValue(fin));

    return query.watchSingleOrNull().map((r) {
      if (r == null) {
        return RecapMois(
          nbCoursValides: 0, nbCoursPayes: 0,
          montantTotal: 0, montantPaye: 0, montantRestant: 0,
          mois: debut.month, annee: debut.year,
        );
      }
      final total = r.read(totalExpr) ?? 0;
      final paye  = r.read(payeExpr)  ?? 0;
      return RecapMois(
        nbCoursValides: r.read(nbExpr)      ?? 0,
        nbCoursPayes:   r.read(nbPayesExpr) ?? 0,
        montantTotal:   total,
        montantPaye:    paye,
        montantRestant: total - paye,
        mois: debut.month, annee: debut.year,
      );
    });
  }

  Stream<List<Cour>> watchCoursAnnules() {
    return (select(cours)
          ..where((c) => c.statut.equals(StatutCours.annule.toDb()))
          ..orderBy([(c) => OrderingTerm.desc(c.datePrevue)]))
        .watch();
  }

  Future<int> purgerCoursAnnulesAnciens(int jours) {
    final limite = DateTime.now().subtract(Duration(days: jours));
    return (delete(cours)
          ..where((c) =>
              c.statut.equals(StatutCours.annule.toDb()) &
              c.datePrevue.isSmallerThanValue(limite)))
        .go();
  }

  Future<int> purgerTousCoursAnnules() {
    return (delete(cours)
          ..where((c) => c.statut.equals(StatutCours.annule.toDb())))
        .go();
  }

  Future<void> marquerMoisNonPaye(int eleveId, int mois, int annee) async {
    final debut = DateTime(annee, mois, 1);
    final fin = DateTime(annee, mois + 1, 1);
    await (update(cours)
          ..where((c) {
            final d = coalesce<DateTime>([c.dateReelle, c.datePrevue]);
            return c.elevesId.equals(eleveId) &
                c.statut.equals(StatutCours.effectue.toDb()) &
                d.isBiggerOrEqualValue(debut) &
                d.isSmallerThanValue(fin);
          }))
        .write(CoursCompanion(
          paye: const Value(false),
          datePaiement: const Value(null),
          updatedAt: Value(DateTime.now()),
        ));
  }
}
