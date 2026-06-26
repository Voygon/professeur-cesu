import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/database/app_database.dart';
import '../../shared/utils/money.dart';

class ExportService {
  ExportService._();

  static Future<void> exporterTout({
    required List<Eleve> eleves,
    required List<Payeur> payeurs,
    required List<Cour> cours,
  }) async {
    final dir = await getTemporaryDirectory();
    final fichiers = <XFile>[];

    // ── Élèves ──
    final elevesFile = File('${dir.path}/eleves.csv');
    await elevesFile.writeAsString(_genererCsvEleves(eleves));
    fichiers.add(XFile(elevesFile.path));

    // ── Payeurs ──
    final payeursFile = File('${dir.path}/payeurs.csv');
    await payeursFile.writeAsString(_genererCsvPayeurs(payeurs));
    fichiers.add(XFile(payeursFile.path));

    // ── Cours ──
    final coursFile = File('${dir.path}/cours.csv');
    await coursFile.writeAsString(_genererCsvCours(cours));
    fichiers.add(XFile(coursFile.path));

    try {
      await Share.shareXFiles(
        fichiers,
        subject: 'Export Professeur CESU',
        text: 'Export de vos données — ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
      );
    } finally {
      // Supprime les fichiers temporaires après partage (quelle que soit l'issue)
      for (final xf in fichiers) {
        try {
          await File(xf.path).delete();
        } catch (_) {}
      }
    }
  }

  static String _genererCsvEleves(List<Eleve> eleves) {
    final buffer = StringBuffer();
    // En-tête
    buffer.writeln('ID,Prénom,Nom,Adresse,Téléphone,Hebdo,Jour,Heure,Durée habituelle,Actif');
    // Données
    for (final e in eleves) {
      buffer.writeln([
        e.elevesId,
        _echapper(e.prenom),
        _echapper(e.nom),
        _echapper(e.adress),
        _echapper(e.telephone),
        e.hebdo ? 'Oui' : 'Non',
        e.jourSemaine ?? '',
        _echapper(e.heureDebut ?? ''),
        e.dureeCours ?? '',
        e.actif ? 'Actif' : 'Archivé',
      ].join(','));
    }
    return buffer.toString();
  }

  static String _genererCsvPayeurs(List<Payeur> payeurs) {
    final buffer = StringBuffer();
    buffer.writeln('ID,Prénom,Nom,Adresse,Téléphone,CESU+,Actif');
    for (final p in payeurs) {
      buffer.writeln([
        p.payeurId,
        _echapper(p.prenom),
        _echapper(p.nom),
        _echapper(p.adress),
        _echapper(p.telephone),
        p.cesuPlus ? 'Oui' : 'Non',
        p.actif ? 'Actif' : 'Archivé',
      ].join(','));
    }
    return buffer.toString();
  }

  static String _genererCsvCours(List<Cour> cours) {
    final buffer = StringBuffer();
    buffer.writeln('ID,EleveID,Date prévue,Date réelle,Durée,Montant,Payé,Date paiement,Statut');
    for (final c in cours) {
      buffer.writeln([
        c.coursId,
        c.elevesId,
        _formaterDate(c.datePrevue),
        c.dateReelle != null ? _formaterDate(c.dateReelle!) : '',
        c.dureeReelle ?? '',
        c.montant != null ? centimesToEuros(c.montant!).toStringAsFixed(2) : '',
        c.paye ? 'Oui' : 'Non',
        c.datePaiement != null ? _formaterDate(c.datePaiement!) : '',
        c.statut,
      ].join(','));
    }
    return buffer.toString();
  }

  // Échappe les virgules et guillemets dans les valeurs CSV
  static String _echapper(String valeur) {
    if (valeur.contains(',') || valeur.contains('"') || valeur.contains('\n')) {
      return '"${valeur.replaceAll('"', '""')}"';
    }
    return valeur;
  }

  static String _formaterDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}