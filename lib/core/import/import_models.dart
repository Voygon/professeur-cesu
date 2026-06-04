import '../../core/database/app_database.dart';

enum StatutImport {
  ok,             // importé sans problème
  avertissement,  // importé mais avec données suspectes
  conflit,        // doublon détecté → attente choix utilisateur
  payeurManquant, // pas de payeur → attente choix utilisateur
  erreur,         // ligne mal formatée
  ignore,         // utilisateur a choisi de ne pas importer
}

class LigneImport {
  final int numeroLigne;
  final ElevesCompanion eleve;
  final PayeursCompanion? payeur;
  StatutImport statut;
  final String? message;
  final Eleve? eleveExistant;
  final Map<String, String> erreursValidation;

  LigneImport({
    required this.numeroLigne,
    required this.eleve,
    this.payeur,
    required this.statut,
    this.message,
    this.eleveExistant,
    this.erreursValidation = const {},
  });
}

class ResultatImport {
  final int nbOk;
  final int nbIgnores;
  final int nbErreurs;
  final int nbConflits;

  const ResultatImport({
    required this.nbOk,
    required this.nbIgnores,
    required this.nbErreurs,
    required this.nbConflits,
  });
}