import 'validators_communs.dart';

class EleveValidator {
  EleveValidator._();

  static String? validatePrenom(String? value) {
    // Cas null ou vide — champ obligatoire
    if (value == null || value.trim().isEmpty) {
      return 'Le prénom est obligatoire';
    }

    final trimmed = value.trim();

    if (trimmed.length < 2) {
      return 'Le prénom doit contenir au moins 2 caractères';
    }

    if (trimmed.length > 50) {
      return 'Le prénom ne peut pas dépasser 50 caractères';
    }

    return null;
  }

  static String? validateNom(String? value) {
    // Cas null ou vide — champ obligatoire
    if (value == null || value.trim().isEmpty) {
      return 'Le nom est obligatoire';
    }

    final trimmed = value.trim();

    if (trimmed.length < 2) {
      return 'Le nom doit contenir au moins 2 caractères';
    }

    if (trimmed.length > 50) {
      return 'Le nom ne peut pas dépasser 50 caractères';
    }

    return null;
  }

  static String? validateAdresse(String? value) {
    // Cas null ou vide — champ obligatoire
    if (value == null || value.trim().isEmpty) {
      return 'L\'adresse est obligatoire';
    }

    final trimmed = value.trim();

    if (trimmed.length < 5) {
      return 'L\'adresse doit contenir au moins 5 caractères';
    }

    return null;
  }

  static String? validateTelephone(String? value) {
    // Optionnel — si vide on accepte
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    // Retire les espaces et tirets que l'utilisateur aurait pu saisir
    // Ex: "06 12 34 56 78" → "0612345678"
    final cleaned = value.replaceAll(RegExp(r'[\s\-]'), '');

    if (!ValidatorsCommuns.regexTel.hasMatch(cleaned)) {
      return 'Format invalide — ex: 0612345678 ou +33612345678';
    }

    return null;
  }

  static String? validateNomPere(String? value) {
    // Cas null ou vide — champ obligatoire
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final trimmed = value.trim();

    if (trimmed.length > 50) {
      return 'Le nom ne peut pas dépasser 50 caractères';
    }

    return null;
  }

  static String? validateNomMere(String? value) {
    // Cas null ou vide — champ obligatoire
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final trimmed = value.trim();

    if (trimmed.length > 50) {
      return 'Le nom ne peut pas dépasser 50 caractères';
    }

    return null;
  }

  static String? validateJourSemaine(int? value) {
    // Cas null ou vide — champ obligatoire
    if (value == null) return null;

    if (value < 1 || value > 7) {
      return 'Jour invalide (1 = Lundi, 7 = Dimanche)';
    }
    return null;
  }

  static String? validateHeureDebut(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!ValidatorsCommuns.regexHeure.hasMatch(value.trim())) {
      return 'Format invalide — ex: 17:30';
    }
    return null;
  }

  static String? validateCoherenceHebdo(
      bool hebdo, int? jourSemaine, String? heureDebut) {
    if (!hebdo) return null;
    if (jourSemaine == null) {
      return 'Le jour est requis pour un élève hebdomadaire';
    }
    if (heureDebut == null || heureDebut.isEmpty) {
      return 'L\'heure est requise pour un élève hebdomadaire';
    }
    return null;
  }
}
