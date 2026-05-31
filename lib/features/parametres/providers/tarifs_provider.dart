import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';

final tarifsEnCoursProvider = StreamProvider<List<Tarif>>((ref) {
  return ref.watch(tarifsDaoProvider).watchTarifEnCours();
});

final tarifsArchivesProvider = StreamProvider<List<Tarif>>((ref) {
  return ref.watch(tarifsDaoProvider).watchTarifsArchives();
});
