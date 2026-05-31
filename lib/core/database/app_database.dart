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
  BoolColumn get actif => boolean().withDefault(const Constant(true))();
  BoolColumn get hebdo => boolean().withDefault(const Constant(false))();
  IntColumn get jourSemaine => integer().nullable()();
  TextColumn get heureDebut => text().nullable()();
  IntColumn get payeurId => integer().references(Payeurs, #payeurId)();
  IntColumn get dureeCours => integer().nullable()();
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
  BoolColumn get actif => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Tarifs extends Table {
  IntColumn get tarifsId => integer().autoIncrement()();
  IntColumn get duree => integer()();
  RealColumn get prix => real()();
  DateTimeColumn get dateDebut => dateTime()();
  DateTimeColumn get dateFin => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Cours extends Table {
  IntColumn get coursId => integer().autoIncrement()();
  IntColumn get elevesId => integer().references(Eleves, #elevesId)();
  DateTimeColumn get datePrevue => dateTime()();
  DateTimeColumn get dateReelle => dateTime().nullable()();
  IntColumn get dureeReelle => integer().nullable()();
  IntColumn get tarifsId =>
      integer().references(Tarifs, #tarifsId).nullable()();
  RealColumn get montant => real().nullable()();
  BoolColumn get paye => boolean().withDefault(const Constant(false))();
  DateTimeColumn get datePaiement => dateTime().nullable()();
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(eleves, eleves.dureeCours);
          }
        },
      );
}
