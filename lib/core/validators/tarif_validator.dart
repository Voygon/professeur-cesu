class TarifValidator {
  TarifValidator._();

  // Durées autorisées en minutes
  static const _dureesAutorisees = [30, 45, 60];

  static String? validateDuree(int? value) {
    if (value == null) return 'La durée est obligatoire';
    if (!_dureesAutorisees.contains(value)) {
      return 'Durée invalide — valeurs acceptées : 30, 45 ou 60 minutes';
    }
    return null;
  }

  static String? validatePrix(double? value) {
    if (value == null) return 'Le prix est obligatoire';
    if (value <= 0) return 'Le prix doit être supérieur à 0';
    if (value > 999) return 'Le prix semble incorrect (max 999€)';
    // Vérifie qu'on n'a pas plus de 2 décimales (ex: 25.123 est invalide)
    final arrondi = double.parse(value.toStringAsFixed(2));
    if (arrondi != value)
      return 'Le prix ne peut pas avoir plus de 2 décimales';
    return null;
  }

  static String? validateDateDebut(DateTime? value) {
    if (value == null) return 'La date de début est obligatoire';
    return null;
  }

  static String? validateDateFin(DateTime? dateFin, DateTime? dateDebut) {
    // dateFin est optionnelle — null = tarif encore en vigueur
    if (dateFin == null) return null;
    if (dateDebut == null) return null;
    // La date de fin doit être après la date de début
    if (!dateFin.isAfter(dateDebut)) {
      return 'La date de fin doit être après la date de début';
    }
    return null;
  }
}
