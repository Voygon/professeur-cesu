import 'validators_communs.dart';

class PayeurValidator {
  PayeurValidator._();

  static String? validatePrenom(String? value) {
    if (value == null || value.trim().isEmpty)
      return 'Le prénom est obligatoire';
    final trimmed = value.trim();
    if (trimmed.length < 2)
      return 'Le prénom doit contenir au moins 2 caractères';
    if (trimmed.length > 50)
      return 'Le prénom ne peut pas dépasser 50 caractères';
    return null;
  }

  static String? validateNom(String? value) {
    if (value == null || value.trim().isEmpty) return 'Le nom est obligatoire';
    final trimmed = value.trim();
    if (trimmed.length < 2) return 'Le nom doit contenir au moins 2 caractères';
    if (trimmed.length > 50) return 'Le nom ne peut pas dépasser 50 caractères';
    return null;
  }

  static String? validateTelephone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final cleaned = value.replaceAll(RegExp(r'[\s\-]'), '');
    if (!ValidatorsCommuns.regexTel.hasMatch(cleaned)) {
      return 'Format invalide — ex: 0612345678 ou +33612345678';
    }
    return null;
  }

  static String? validateAdresse(String? value) {
    if (value == null || value.trim().isEmpty)
      return 'L\'adresse est obligatoire';
    if (value.trim().length < 5)
      return 'L\'adresse doit contenir au moins 5 caractères';
    return null;
  }
}
