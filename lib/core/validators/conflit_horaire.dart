import 'package:flutter/material.dart';
import '../database/app_database.dart';

class ConflitHoraire {
  const ConflitHoraire._();

  // ── Conflits entre cours planifiés ────────────────────────────────────────

  /// Retourne les IDs des cours impliqués dans au moins un conflit d'horaire.
  /// Deux cours sont en conflit si l'écart entre la fin de l'un et le début
  /// de l'autre est inférieur à [espacement] minutes.
  static Set<int> detecterConflitsCours(List<Cour> cours,
      {int espacement = 15}) {
    final conflits = <int>{};

    final parJour = <String, List<Cour>>{};
    for (final c in cours) {
      final date = c.dateReelle ?? c.datePrevue;
      final cle = '${date.year}-${date.month}-${date.day}';
      (parJour[cle] ??= []).add(c);
    }

    for (final groupe in parJour.values) {
      for (int i = 0; i < groupe.length; i++) {
        for (int j = i + 1; j < groupe.length; j++) {
          if (_coursEnConflit(groupe[i], groupe[j], espacement)) {
            conflits.add(groupe[i].coursId);
            conflits.add(groupe[j].coursId);
          }
        }
      }
    }

    return conflits;
  }

  static bool _coursEnConflit(Cour a, Cour b, int espacement) {
    final debutA = a.dateReelle ?? a.datePrevue;
    final debutB = b.dateReelle ?? b.datePrevue;
    final dureeA = a.dureeReelle ?? 60;
    final dureeB = b.dureeReelle ?? 60;
    final finA = debutA.add(Duration(minutes: dureeA));
    final finB = debutB.add(Duration(minutes: dureeB));

    return finA.add(Duration(minutes: espacement)).isAfter(debutB) &&
        finB.add(Duration(minutes: espacement)).isAfter(debutA);
  }

  // ── Conflits hebdomadaires ─────────────────────────────────────────────────

  /// Retourne les élèves dont le créneau hebdo entre en conflit avec
  /// [jourSemaine] / [heureDebut] / [duree].
  /// [excludeEleveId] permet d'exclure l'élève en cours de modification.
  static List<Eleve> detecterConflitsHebdo(
    int jourSemaine,
    TimeOfDay heureDebut,
    int duree,
    List<Eleve> elevesExistants, {
    int? excludeEleveId,
    int espacement = 15,
  }) {
    final ref = DateTime(2000, 1, 1, heureDebut.hour, heureDebut.minute);
    final finRef = ref.add(Duration(minutes: duree));

    return elevesExistants.where((e) {
      if (!e.hebdo) return false;
      if (e.jourSemaine != jourSemaine) return false;
      if (e.heureDebut == null || e.dureeCours == null) return false;
      if (excludeEleveId != null && e.elevesId == excludeEleveId) return false;

      final parties = e.heureDebut!.split(':');
      final debutE =
          DateTime(2000, 1, 1, int.parse(parties[0]), int.parse(parties[1]));
      final finE = debutE.add(Duration(minutes: e.dureeCours!));

      return finRef.add(Duration(minutes: espacement)).isAfter(debutE) &&
          finE.add(Duration(minutes: espacement)).isAfter(ref);
    }).toList();
  }

  // ── Conflits dans la liste des élèves ────────────────────────────────────

  /// Retourne les IDs des élèves hebdo impliqués dans au moins un conflit.
  static Set<int> detecterConflitsElevesHebdo(List<Eleve> eleves,
      {int espacement = 15}) {
    final conflits = <int>{};
    final hebdos = eleves
        .where((e) =>
            e.hebdo &&
            e.jourSemaine != null &&
            e.heureDebut != null &&
            e.dureeCours != null)
        .toList();

    for (int i = 0; i < hebdos.length; i++) {
      for (int j = i + 1; j < hebdos.length; j++) {
        if (_elevesEnConflit(hebdos[i], hebdos[j], espacement)) {
          conflits.add(hebdos[i].elevesId);
          conflits.add(hebdos[j].elevesId);
        }
      }
    }
    return conflits;
  }

  static bool _elevesEnConflit(Eleve a, Eleve b, int espacement) {
    if (a.jourSemaine != b.jourSemaine) return false;
    final debutA = _parseHeure(a.heureDebut!);
    final debutB = _parseHeure(b.heureDebut!);
    final finA = debutA.add(Duration(minutes: a.dureeCours!));
    final finB = debutB.add(Duration(minutes: b.dureeCours!));
    return finA.add(Duration(minutes: espacement)).isAfter(debutB) &&
        finB.add(Duration(minutes: espacement)).isAfter(debutA);
  }

  static DateTime _parseHeure(String heure) {
    final p = heure.split(':');
    return DateTime(2000, 1, 1, int.parse(p[0]), int.parse(p[1]));
  }

  // ── Formatage ──────────────────────────────────────────────────────────────

  static String descriptionConflitsHebdo(List<Eleve> conflits) {
    return conflits.map((e) {
      final h = e.heureDebut ?? '?';
      final d = e.dureeCours != null ? '${e.dureeCours} min' : '';
      return '• ${e.prenom} ${e.nom} — $h${d.isNotEmpty ? ' ($d)' : ''}';
    }).join('\n');
  }
}
