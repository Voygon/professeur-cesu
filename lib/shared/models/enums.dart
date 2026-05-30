import 'package:flutter/material.dart';

enum StatutCours {
  prevu,
  effectue,
  annule,
  modifie;

  String toDb() => name;

  static StatutCours fromDb(String value) {
    return StatutCours.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StatutCours.prevu,
    );
  }

  // Label affiché dans l'UI
  String get label => switch (this) {
        StatutCours.prevu => 'Prévu',
        StatutCours.effectue => 'Effectué',
        StatutCours.annule => 'Annulé',
        StatutCours.modifie => 'Modifié',
      };

  // Couleur du texte du badge
  Color get couleur => switch (this) {
        StatutCours.prevu => const Color(0xFF1565C0),
        StatutCours.effectue => const Color(0xFF2E7D32),
        StatutCours.annule => const Color(0xFFC62828),
        StatutCours.modifie => const Color(0xFFE65100),
      };

  // Couleur de fond du badge
  Color get couleurFond => switch (this) {
        StatutCours.prevu => const Color(0xFFE3F2FD),
        StatutCours.effectue => const Color(0xFFE8F5E9),
        StatutCours.annule => const Color(0xFFFFEBEE),
        StatutCours.modifie => const Color(0xFFFFF3E0),
      };
}

enum TypePaiement {
  cesu,
  espece;

  String toDb() => name;

  static TypePaiement fromDb(String value) {
    return TypePaiement.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TypePaiement.cesu,
    );
  }
}

enum JourSemaine {
  lundi(1),
  mardi(2),
  mercredi(3),
  jeudi(4),
  vendredi(5),
  samedi(6),
  dimanche(7);

  final int valeur;
  const JourSemaine(this.valeur);

  static JourSemaine fromValeur(int valeur) {
    return JourSemaine.values.firstWhere(
      (j) => j.valeur == valeur,
      orElse: () => JourSemaine.lundi,
    );
  }
}
