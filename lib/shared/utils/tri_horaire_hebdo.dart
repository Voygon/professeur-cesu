import '../models/enums.dart';

int heureEnMinutes(String? h) {
  if (h == null) return 9999;
  final p = h.split(':');
  if (p.length != 2) return 9999;
  return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
}

/// Trie [source] par jour de semaine puis heure de début pour les éléments
/// ayant un créneau hebdomadaire ; les autres passent en fin de liste,
/// triés entre eux par [compareSansCreneau].
List<T> trierParJourHebdo<T>(
  List<T> source, {
  required bool Function(T item) aCreneauHebdo,
  required int Function(T item) jourSemaine,
  required String? Function(T item) heureDebut,
  required int Function(T a, T b) compareSansCreneau,
}) {
  final copie = [...source];
  copie.sort((a, b) {
    final aHebdo = aCreneauHebdo(a);
    final bHebdo = aCreneauHebdo(b);
    if (!aHebdo && !bHebdo) return compareSansCreneau(a, b);
    if (!aHebdo) return 1;
    if (!bHebdo) return -1;
    final jourCmp = jourSemaine(a).compareTo(jourSemaine(b));
    if (jourCmp != 0) return jourCmp;
    return heureEnMinutes(heureDebut(a)).compareTo(heureEnMinutes(heureDebut(b)));
  });
  return copie;
}

/// Construit une liste plate avec séparateurs de jour (String) à partir
/// d'une liste déjà triée par [trierParJourHebdo].
List<Object> avecSeparateursJour<T>(
  List<T> source, {
  required bool Function(T item) aCreneauHebdo,
  required int Function(T item) jourSemaine,
}) {
  final items = <Object>[];
  int? currentJour;
  bool sansCreneau = false;

  for (final item in source) {
    if (aCreneauHebdo(item)) {
      final j = jourSemaine(item);
      if (j != currentJour) {
        currentJour = j;
        final jour = JourSemaine.fromValeur(j);
        items.add('${jour.name[0].toUpperCase()}${jour.name.substring(1)}');
      }
    } else {
      if (!sansCreneau) {
        sansCreneau = true;
        items.add('Sans créneau fixe');
      }
    }
    items.add(item as Object);
  }
  return items;
}
