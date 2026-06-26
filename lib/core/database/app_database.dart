import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'daos/eleves_dao.dart';
import 'daos/cours_dao.dart';
import 'daos/payeurs_dao.dart';
import 'daos/tarifs_dao.dart';

part 'app_database.g.dart';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final pathDB = p.join(dir.path, 'professeur_cesu.db');
    final file = File(pathDB);
    return NativeDatabase.createInBackground(file);
  });
}

class Eleves extends Table {
  IntColumn get elevesId => integer().autoIncrement()();
  TextColumn get prenom => text()();
  TextColumn get nom => text()();
  TextColumn get nomPere => text().nullable()();
  TextColumn get nomMere => text().nullable()();
  TextColumn get telephone => text()();
  TextColumn get adress => text()();
  // Soft-delete : archive l'élève sans supprimer son historique de cours.
  BoolColumn get actif => boolean().withDefault(const Constant(true))();
  BoolColumn get hebdo => boolean().withDefault(const Constant(false))();
  IntColumn get jourSemaine => integer()
      .nullable()
      // ignore: recursive_getters
      .check(jourSemaine.isBetweenValues(1, 7))();
  TextColumn get heureDebut => text().nullable()();
  IntColumn get payeurId => integer().references(Payeurs, #payeurId)();
  IntColumn get dureeCours => integer()
      .nullable()
      // ignore: recursive_getters
      .check(dureeCours.isBiggerThanValue(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Payeurs extends Table {
  IntColumn get payeurId => integer().autoIncrement()();
  TextColumn get prenom => text()();
  TextColumn get nom => text()();
  TextColumn get telephone => text()();
  TextColumn get adress => text()();
  BoolColumn get cesuPlus => boolean().withDefault(const Constant(false))();
  // Soft-delete : archive le payeur sans supprimer son historique.
  BoolColumn get actif => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Tarifs extends Table {
  IntColumn get tarifsId => integer().autoIncrement()();
  // ignore: recursive_getters
  IntColumn get duree => integer().check(duree.isBiggerThanValue(0))();
  // Prix en centimes (entier) pour éviter les erreurs d'arrondi flottant.
  // ignore: recursive_getters
  IntColumn get prix => integer().check(prix.isBiggerThanValue(0))();
  DateTimeColumn get dateDebut => dateTime()();
  // Plage de validité temporelle (pas un soft-delete) : dateFin = null
  // signifie "tarif encore en vigueur". Un tarif "fermé" n'est pas
  // supprimé, il a juste expiré — l'historique des prix est conservé.
  DateTimeColumn get dateFin => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Cours extends Table {
  IntColumn get coursId => integer().autoIncrement()();
  // Si l'élève est supprimé, ses cours le sont aussi (cohérent avec le
  // message affiché à l'utilisateur lors de la suppression d'un élève).
  IntColumn get elevesId => integer()
      .references(Eleves, #elevesId, onDelete: KeyAction.cascade)();
  DateTimeColumn get datePrevue => dateTime()();
  DateTimeColumn get dateReelle => dateTime().nullable()();
  IntColumn get dureeReelle => integer()
      .nullable()
      // ignore: recursive_getters
      .check(dureeReelle.isBiggerThanValue(0))();
  // Si le tarif est supprimé, le cours garde son montant déjà enregistré
  // mais perd la référence (plutôt que de bloquer la suppression du tarif).
  IntColumn get tarifsId => integer()
      .nullable()
      .references(Tarifs, #tarifsId, onDelete: KeyAction.setNull)();
  // Montant en centimes (entier) pour éviter les erreurs d'arrondi flottant.
  IntColumn get montant => integer()
      .nullable()
      // ignore: recursive_getters
      .check(montant.isBiggerOrEqualValue(0))();
  BoolColumn get paye => boolean().withDefault(const Constant(false))();
  BoolColumn get paiementEspeces => boolean().withDefault(const Constant(false))();
  DateTimeColumn get datePaiement => dateTime().nullable()();
  // État métier du cycle de vie du cours (pas un soft-delete) :
  // prevu → effectue, ou prevu → annule. Un cours "annulé" reste un fait
  // historique consultable, il n'est jamais masqué/supprimé par ce champ.
  TextColumn get statut => text().withDefault(const Constant('prevu'))();
  BoolColumn get exceptionnel => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(
    tables: [Eleves, Payeurs, Tarifs, Cours],
    daos: [ElevesDao, CoursDao, PayeursDao, TarifsDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(eleves, eleves.dureeCours);
          }
          if (from < 3) {
            await _createIndexes();
          }
          if (from < 4) {
            await m.addColumn(cours, cours.paiementEspeces);
          }
          if (from < 5) {
            await customStatement(
              "UPDATE cours SET statut = 'effectue' WHERE statut = 'modifie'",
            );
          }
          if (from < 6) {
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_eleves_actif ON eleves(actif)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_payeurs_actif ON payeurs(actif)',
            );
          }
          if (from < 7) {
            // Tarifs.prix et Cours.montant passent de REAL (euros) à
            // INTEGER (centimes) pour éviter les erreurs d'arrondi flottant
            // sur les montants. SQLite ne permet pas de changer le type
            // d'une colonne existante : on recrée la colonne avec le bon
            // type, on copie les valeurs converties, puis on supprime
            // l'ancienne colonne.
            await customStatement(
              'ALTER TABLE tarifs RENAME COLUMN prix TO prix_old',
            );
            await customStatement(
              'ALTER TABLE tarifs ADD COLUMN prix INTEGER NOT NULL DEFAULT 0',
            );
            await customStatement(
              'UPDATE tarifs SET prix = CAST(ROUND(prix_old * 100) AS INTEGER)',
            );
            await customStatement('ALTER TABLE tarifs DROP COLUMN prix_old');

            await customStatement(
              'ALTER TABLE cours RENAME COLUMN montant TO montant_old',
            );
            await customStatement(
              'ALTER TABLE cours ADD COLUMN montant INTEGER',
            );
            await customStatement(
              'UPDATE cours SET montant = CAST(ROUND(montant_old * 100) AS INTEGER) '
              'WHERE montant_old IS NOT NULL',
            );
            await customStatement('ALTER TABLE cours DROP COLUMN montant_old');
          }
          if (from < 8) {
            // Ajout de contraintes CHECK et de comportements ON DELETE sur
            // les clés étrangères. SQLite ne permet pas d'ajouter ces
            // contraintes à une table existante : on recrée chaque table
            // avec le schéma final, on y copie les données, puis on
            // supprime l'ancienne table.
            await customStatement('PRAGMA foreign_keys = OFF');

            await customStatement('''
              CREATE TABLE tarifs_new (
                tarifs_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                duree INTEGER NOT NULL CHECK (duree > 0),
                prix INTEGER NOT NULL CHECK (prix > 0),
                date_debut DATETIME NOT NULL,
                date_fin DATETIME,
                created_at DATETIME NOT NULL
              )
            ''');
            await customStatement(
              'INSERT INTO tarifs_new SELECT * FROM tarifs',
            );
            await customStatement('DROP TABLE tarifs');
            await customStatement('ALTER TABLE tarifs_new RENAME TO tarifs');

            await customStatement('''
              CREATE TABLE eleves_new (
                eleves_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                prenom TEXT NOT NULL,
                nom TEXT NOT NULL,
                nom_pere TEXT,
                nom_mere TEXT,
                telephone TEXT NOT NULL,
                adress TEXT NOT NULL,
                actif INTEGER NOT NULL DEFAULT 1,
                hebdo INTEGER NOT NULL DEFAULT 0,
                jour_semaine INTEGER CHECK (jour_semaine BETWEEN 1 AND 7),
                heure_debut TEXT,
                payeur_id INTEGER NOT NULL REFERENCES payeurs(payeur_id),
                duree_cours INTEGER CHECK (duree_cours > 0),
                created_at DATETIME NOT NULL,
                updated_at DATETIME NOT NULL
              )
            ''');
            await customStatement(
              'INSERT INTO eleves_new SELECT * FROM eleves',
            );
            await customStatement('DROP TABLE eleves');
            await customStatement('ALTER TABLE eleves_new RENAME TO eleves');

            // Nettoyage des doublons éventuels avant l'ajout de l'index
            // unique ci-dessous (garde la ligne la plus ancienne par
            // créneau dupliqué élève + date prévue).
            await customStatement('''
              DELETE FROM cours
              WHERE statut != 'annule'
              AND cours_id NOT IN (
                SELECT MIN(cours_id) FROM cours
                WHERE statut != 'annule'
                GROUP BY eleves_id, date_prevue
              )
            ''');

            await customStatement('''
              CREATE TABLE cours_new (
                cours_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                eleves_id INTEGER NOT NULL REFERENCES eleves(eleves_id) ON DELETE CASCADE,
                date_prevue DATETIME NOT NULL,
                date_reelle DATETIME,
                duree_reelle INTEGER CHECK (duree_reelle > 0),
                tarifs_id INTEGER REFERENCES tarifs(tarifs_id) ON DELETE SET NULL,
                montant INTEGER CHECK (montant >= 0),
                paye INTEGER NOT NULL DEFAULT 0,
                paiement_especes INTEGER NOT NULL DEFAULT 0,
                date_paiement DATETIME,
                statut TEXT NOT NULL DEFAULT 'prevu',
                exceptionnel INTEGER NOT NULL DEFAULT 0,
                notes TEXT,
                created_at DATETIME NOT NULL,
                updated_at DATETIME NOT NULL
              )
            ''');
            await customStatement(
              'INSERT INTO cours_new SELECT * FROM cours',
            );
            await customStatement('DROP TABLE cours');
            await customStatement('ALTER TABLE cours_new RENAME TO cours');

            await _createIndexes();
            await customStatement(
              "CREATE UNIQUE INDEX IF NOT EXISTS idx_cours_creneau_unique "
              "ON cours(eleves_id, date_prevue) WHERE statut != 'annule'",
            );

            await customStatement('PRAGMA foreign_keys = ON');
            // Vérifie qu'aucune référence orpheline ne subsiste après la
            // recréation des tables.
            await customStatement('PRAGMA foreign_key_check');
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cours_eleve ON cours(eleves_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cours_date ON cours(date_prevue)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cours_statut ON cours(statut)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cours_paye ON cours(paye)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_eleves_actif ON eleves(actif)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_payeurs_actif ON payeurs(actif)',
    );
    // Empêche le double-booking : un même élève ne peut pas avoir deux
    // cours non annulés au même créneau.
    await customStatement(
      "CREATE UNIQUE INDEX IF NOT EXISTS idx_cours_creneau_unique "
      "ON cours(eleves_id, date_prevue) WHERE statut != 'annule'",
    );
  }
}
