import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/app_database.dart';

final coursDuJourProvider = StreamProvider<List<Cour>>((ref) {
  return ref.watch(coursDaoProvider).watchCoursDuJour();
});

final eleveParIdProvider = FutureProvider.family<Eleve?, int>((ref, id) {
  return ref.watch(elevesDaoProvider).getEleve(id);
});
