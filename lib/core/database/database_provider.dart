import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';
import 'daos/eleves_dao.dart';
import 'daos/payeurs_dao.dart';
import 'daos/cours_dao.dart';
import 'daos/tarifs_dao.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(() => database.close());
  return database;
});

final elevesDaoProvider = Provider<ElevesDao>((ref) {
  return ref.watch(databaseProvider).elevesDao;
});

final payeursDaoProvider = Provider<PayeursDao>((ref) {
  return ref.watch(databaseProvider).payeursDao;
});

final coursDaoProvider = Provider<CoursDao>((ref) {
  return ref.watch(databaseProvider).coursDao;
});

final tarifsDaoProvider = Provider<TarifsDao>((ref) {
  return ref.watch(databaseProvider).tarifsDao;
});
