import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/daos/eleves_dao.dart';
import '../database/daos/payeurs_dao.dart';
import '../validators/eleve_validator.dart';
import '../validators/payeur_validator.dart';
import 'import_models.dart';

class ImportService {
  ImportService._();

  static String _corrigerTelephone(String tel) {
    if (tel.isEmpty) return tel;
    
    // Nettoie les espaces et tirets
    final propre = tel.replaceAll(RegExp(r'[\s\-\.]'), '');
    
    // Si 9 chiffres → il manque le 0 initial
    if (RegExp(r'^\d{9}$').hasMatch(propre)) {
      return '0$propre';
    }
    
    // Si 10 chiffres commençant par 0 → OK
    if (RegExp(r'^0\d{9}$').hasMatch(propre)) {
      return propre;
    }
    
    // Format international +33 → 0
    if (RegExp(r'^\+33\d{9}$').hasMatch(propre)) {
      return '0${propre.substring(3)}';
    }
    
    // Autre format → retourne tel quel
    return propre;
  }

  // ── Validation ──────────────────────────────────────────────────────────

  static Map<String, String> validerLigne(
      ElevesCompanion eleve, PayeursCompanion? payeur) {
    final erreurs = <String, String>{};

    // ── Élève ──
    final errPrenom = EleveValidator.validatePrenom(
        eleve.prenom.present ? eleve.prenom.value : null);
    if (errPrenom != null) erreurs['eleve_prenom'] = errPrenom;

    final errNom = EleveValidator.validateNom(
        eleve.nom.present ? eleve.nom.value : null);
    if (errNom != null) erreurs['eleve_nom'] = errNom;

    final errAdresse = EleveValidator.validateAdresse(
        eleve.adress.present ? eleve.adress.value : null);
    if (errAdresse != null) erreurs['eleve_adresse'] = errAdresse;

    if (eleve.telephone.present && eleve.telephone.value.isNotEmpty) {
      final errTel = EleveValidator.validateTelephone(eleve.telephone.value);
      if (errTel != null) erreurs['eleve_telephone'] = errTel;
    }

    if (eleve.hebdo.present && eleve.hebdo.value) {
      final jourVal = eleve.jourSemaine.present ? eleve.jourSemaine.value : null;
      final errJour = jourVal == null
          ? 'Jour requis pour un cours hebdo'
          : EleveValidator.validateJourSemaine(jourVal);
      if (errJour != null) erreurs['eleve_jour'] = errJour;

      final heureVal = eleve.heureDebut.present ? eleve.heureDebut.value : null;
      if (heureVal == null || heureVal.isEmpty) {
        erreurs['eleve_heure'] = 'Heure requise pour un cours hebdo';
      }
    }

    // ── Payeur ──
    if (payeur != null) {
      final errPrenomP = PayeurValidator.validatePrenom(
          payeur.prenom.present ? payeur.prenom.value : null);
      if (errPrenomP != null) erreurs['payeur_prenom'] = errPrenomP;

      final errNomP = PayeurValidator.validateNom(
          payeur.nom.present ? payeur.nom.value : null);
      if (errNomP != null) erreurs['payeur_nom'] = errNomP;

      final errAdresseP = PayeurValidator.validateAdresse(
          payeur.adress.present ? payeur.adress.value : null);
      if (errAdresseP != null) erreurs['payeur_adresse'] = errAdresseP;

      if (payeur.telephone.present && payeur.telephone.value.isNotEmpty) {
        final errTelP = PayeurValidator.validateTelephone(payeur.telephone.value);
        if (errTelP != null) erreurs['payeur_telephone'] = errTelP;
      }
    }

    return erreurs;
  }

  // ── Parsing CSV ──────────────────────────────────────────────────────────

  static List<LigneImport> parserCsv(String contenu){
    final lignes = contenu
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
    
    if (lignes.isEmpty) return [];

    // Ignore le première ligne (en-tête)
    final resultats = <LigneImport>[];

    for (var i = 1; i < lignes.length; i++) {
      final numeroLigne  = i;
      try {
        final colonnes = _parserLigneCsv(lignes[i]);

        // Vérifie le nombre minimum de colonnes
        if (colonnes.length < 8) {
          resultats.add(LigneImport(
            numeroLigne: numeroLigne,
            eleve: const ElevesCompanion(),
            statut: StatutImport.erreur,
            message: 'Ligne incomplète — ${colonnes.length} colonnes trouvées, 8 minimum requises'
          ));
          continue;
        }

        // ── Parse élève ──
        final prenomEleve = colonnes[0].trim();
        final nomEleve = colonnes[1].trim();
        final telEleve = _corrigerTelephone(colonnes[2].trim());
        final adresseEleve = colonnes[3].trim();
        final hebdo = colonnes[4].trim().toLowerCase() == 'oui';
        final jourStr = colonnes[5].trim().toLowerCase();
        final heureStr = colonnes[6].trim();
        final dureeStr = colonnes[7].trim();

        if (prenomEleve.isEmpty || nomEleve.isEmpty) {
          resultats.add(LigneImport(
            numeroLigne: numeroLigne,
            eleve: const ElevesCompanion(),
            statut: StatutImport.erreur,
            message: 'Prénom ou nom de l\'élève manquant',
          ));
          continue;
        }

        // Parse jour de la semaine
        int? jourSemaine;
        if (jourStr.isNotEmpty) {
          final joursMap = {
            'lundi': 1, 'mardi': 2, 'mercredi': 3,
            'jeudi': 4, 'vendredi': 5, 'samedi': 6, 'dimanche': 7,
          };
          jourSemaine = joursMap[jourStr];
        }

        // Parse durée
        final duree = int.tryParse(dureeStr);

        final eleve = ElevesCompanion(
          prenom: Value(prenomEleve),
          nom: Value(nomEleve),
          telephone: Value(telEleve),
          adress: Value(adresseEleve),
          hebdo: Value(hebdo),
          jourSemaine: Value(jourSemaine),
          heureDebut: heureStr.isNotEmpty ? Value(heureStr) : const Value.absent(),
          dureeCours: duree != null ? Value(duree) : const Value.absent(),
        );

        // ── Parse payeur ──
        PayeursCompanion? payeur;
        if (colonnes.length >= 13) {
          final prenomPayeur = colonnes[8].trim();
          final nomPayeur = colonnes[9].trim();
          final telPayeur = _corrigerTelephone(colonnes[10].trim());
          final adressePayeur = colonnes[11].trim();
          final cesuPlus = colonnes[12].trim().toLowerCase() == 'oui';

          if (prenomPayeur.isNotEmpty && nomPayeur.isNotEmpty) {
            payeur = PayeursCompanion(
              prenom: Value(prenomPayeur),
              nom: Value(nomPayeur),
              telephone: Value(telPayeur),
              adress: Value(adressePayeur),
              cesuPlus: Value(cesuPlus),
            );
          }
        }

        final erreurs = validerLigne(eleve, payeur);

        resultats.add(LigneImport(
          numeroLigne: numeroLigne,
          eleve: eleve,
          payeur: payeur,
          statut: payeur == null
            ? StatutImport.payeurManquant
            : erreurs.isNotEmpty
              ? StatutImport.avertissement
              : StatutImport.ok,
          erreursValidation: erreurs,
        ));
      } catch (e) {
        resultats.add(LigneImport(
          numeroLigne: numeroLigne,
          eleve: const ElevesCompanion(),
          statut: StatutImport.erreur,
          message: 'Erreur de parsing : $e'
        ));
      }
    }

    return resultats;
  }

  // ── Détection des conflits ───────────────────────────────────────────────

  static Future<void> detecterConflits(
    List<LigneImport> lignes,
    ElevesDao elevesDao,
  ) async {
    final elevesExistants = await elevesDao
      .searchEleves('', inclureArchives: true)
      .first;
    
    for (final ligne in lignes) {
      if (ligne.statut != StatutImport.ok && ligne.statut != StatutImport.avertissement) continue;

      final prenomImport = ligne.eleve.prenom.value.toLowerCase();
      final nomImport = ligne.eleve.nom.value.toLowerCase();

      final doublon = elevesExistants.where((e) =>
        e.prenom.toLowerCase() == prenomImport &&
        e.nom.toLowerCase() == nomImport).firstOrNull;
      
      if (doublon != null) {
        ligne.statut = StatutImport.conflit;
        // On stocke l'élève existant pour l'afficher à l'utilisateur
        final ligneAvecDoublon = LigneImport(
          numeroLigne: ligne.numeroLigne,
          eleve: ligne.eleve,
          payeur: ligne.payeur,
          statut: StatutImport.conflit,
          message: 'Un élève "${doublon.prenom} ${doublon.nom}" existe déjà',
          eleveExistant: doublon,
          erreursValidation: ligne.erreursValidation,
        );
        lignes[lignes.indexOf(ligne)] = ligneAvecDoublon;
      }
    }
  }

  // ── Insertion ────────────────────────────────────────────────────────────

  static Future<ResultatImport> inserer(
    List<LigneImport> lignes,
    ElevesDao elevesDao,
    PayeursDao payeursDao,
  ) async {
    int nbOk = 0, nbIgnores = 0, nbErreurs = 0, nbConflits = 0;

    for (var ligne in lignes) {
      try {
        switch (ligne.statut) {
          case StatutImport.ok:
          case StatutImport.avertissement:
            await _insertLigne(ligne, elevesDao, payeursDao);
            nbOk++;
          
          case StatutImport.ignore:
            nbIgnores++;

          case StatutImport.erreur:
            nbErreurs++;

          case StatutImport.conflit:
          case StatutImport.payeurManquant:
            // Ces cas doivent être résolus avant l'insertion
            nbConflits++;
        }
      } catch (e) {
        nbErreurs++;
      }
    }

    return ResultatImport(
      nbOk: nbOk, 
      nbIgnores: nbIgnores, 
      nbErreurs: nbErreurs, 
      nbConflits: nbConflits
    );
  }

  static Future<void> _insertLigne(
    LigneImport ligne,
    ElevesDao elevesDao,
    PayeursDao payeursDao,
  ) async {
    final payeur = ligne.payeur!;
    final payeurId = await payeursDao.insertPayeur(payeur);
    await elevesDao.insertEleve(
      ligne.eleve.copyWith(payeurId: Value(payeurId)),
    );
  }

  // ── Helpers CSV ──────────────────────────────────────────────────────────

  // Parse une ligne CSV en gérant les guillemets
  static List<String> _parserLigneCsv(String ligne) {
    final colonnes = <String>[];
    final buffer = StringBuffer();
    bool dansGuillemets = false;

    for (var i = 0; i < ligne.length; i++) {
      final char = ligne[i];

      if (char == '"') {
        if (dansGuillemets && i+1 < ligne.length && ligne[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          dansGuillemets = !dansGuillemets;
        }
      } else if (char == ',' && !dansGuillemets) {
        colonnes.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    colonnes.add(buffer.toString());
    return colonnes;
  }

  // Génère un template CSV vide à télécharger
  static String genererTemplate() {
    return 'eleve_prenom,eleve_nom,eleve_telephone,eleve_adresse,hebdo,jour,heure,duree,payeur_prenom,payeur_nom,payeur_telephone,payeur_adresse,cesu_plus\n'
        'Marie,Dupont,0612345678,12 rue de la Paix,oui,lundi,17:00,60,Jean,Dupont,0698765432,12 rue de la Paix,non\n'
        'Paul,Martin,0687654321,5 avenue Victor Hugo,non,,,,Paul,Martin,0687654321,5 avenue Victor Hugo,oui\n';
  }
}