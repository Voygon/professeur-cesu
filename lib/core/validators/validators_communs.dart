class ValidatorsCommuns {
  ValidatorsCommuns._();

  static final regexTel = RegExp(r'^(\+33|0)[1-9][0-9]{8}$');
  static final regexHeure = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
}
