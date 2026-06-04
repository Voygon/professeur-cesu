import 'dart:io';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/app_database.dart';
import '../database/daos/eleves_dao.dart';
import '../database/daos/payeurs_dao.dart';
import '../security/encryption_service.dart';

class BackupService {
  BackupService._();

  static const _entete = '#BACKUP:professeur_cesu:v1';

  // ── Export ────────────────────────────────────────────────────────────────

  static Future<void> exporterSauvegarde(
    AppDatabase db,
    ElevesDao elevesDao,
    PayeursDao payeursDao,
  ) async {
    final now = DateTime.now();
    final buf = StringBuffer();

    buf.writeln(_entete);
    buf.writeln('#DATE:${now.toIso8601String()}');
    buf.writeln();

    // ── Tarifs ──
    final tarifs = await db.select(db.tarifs).get();
    buf.writeln('#SECTION:tarifs');
    buf.writeln('tarifsId,duree,prix,dateDebut,dateFin');
    for (final t in tarifs) {
      buf.writeln([
        t.tarifsId,
        t.duree,
        t.prix,
        t.dateDebut.toIso8601String(),
        t.dateFin?.toIso8601String() ?? '',
      ].join(','));
    }
    buf.writeln();

    // ── Payeurs (déchiffrés par le DAO) ──
    final payeurs =
        await payeursDao.searchPayeurs('', inclureArchives: true).first;
    buf.writeln('#SECTION:payeurs');
    buf.writeln('payeurId,prenom,nom,telephone,adress,cesuPlus,actif');
    for (final p in payeurs) {
      buf.writeln([
        p.payeurId,
        _csv(p.prenom),
        _csv(p.nom),
        _csv(p.telephone),
        _csv(p.adress),
        p.cesuPlus,
        p.actif,
      ].join(','));
    }
    buf.writeln();

    // ── Élèves (déchiffrés par le DAO) ──
    final eleves =
        await elevesDao.searchEleves('', inclureArchives: true).first;
    buf.writeln('#SECTION:eleves');
    buf.writeln(
        'elevesId,prenom,nom,telephone,adress,hebdo,jourSemaine,heureDebut,dureeCours,payeurId,actif,nomPere,nomMere');
    for (final e in eleves) {
      buf.writeln([
        e.elevesId,
        _csv(e.prenom),
        _csv(e.nom),
        _csv(e.telephone),
        _csv(e.adress),
        e.hebdo,
        e.jourSemaine ?? '',
        _csv(e.heureDebut ?? ''),
        e.dureeCours ?? '',
        e.payeurId,
        e.actif,
        _csv(e.nomPere ?? ''),
        _csv(e.nomMere ?? ''),
      ].join(','));
    }
    buf.writeln();

    // ── Cours ──
    final cours = await db.select(db.cours).get();
    buf.writeln('#SECTION:cours');
    buf.writeln(
        'coursId,elevesId,datePrevue,dateReelle,dureeReelle,tarifsId,montant,paye,datePaiement,statut,exceptionnel,notes');
    for (final c in cours) {
      buf.writeln([
        c.coursId,
        c.elevesId,
        c.datePrevue.toIso8601String(),
        c.dateReelle?.toIso8601String() ?? '',
        c.dureeReelle ?? '',
        c.tarifsId ?? '',
        c.montant?.toStringAsFixed(4) ?? '',
        c.paye,
        c.datePaiement?.toIso8601String() ?? '',
        c.statut,
        c.exceptionnel,
        _csv(c.notes ?? ''),
      ].join(','));
    }

    // Partage via le système
    final dir = await getTemporaryDirectory();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final fichier = File('${dir.path}/sauvegarde_cesu_$dateStr.csv');
    await fichier.writeAsString(buf.toString());

    try {
      await Share.shareXFiles(
        [XFile(fichier.path, mimeType: 'text/csv')],
        subject: 'Sauvegarde Professeur CESU',
        text: 'Sauvegarde complète du $dateStr',
      );
    } finally {
      try {
        await fichier.delete();
      } catch (_) {}
    }
  }

  // ── Import ────────────────────────────────────────────────────────────────

  static Future<String?> choisirFichier() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.single.path == null) return null;
    return File(result.files.single.path!).readAsString();
  }

  static Future<void> importerSauvegarde(
      String contenu, AppDatabase db) async {
    final lignes =
        contenu.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);

    if (!lignes.first.startsWith('#BACKUP:professeur_cesu')) {
      throw const FormatException(
          'Ce fichier n\'est pas une sauvegarde Professeur CESU valide.');
    }

    // ── Parsing ──
    final tarifs = <_TarifRow>[];
    final payeurs = <_PayeurRow>[];
    final eleves = <_EleveRow>[];
    final cours = <_CoursRow>[];

    String? section;
    bool skipEntete = false;

    for (final ligne in lignes) {
      if (ligne.startsWith('#BACKUP:') || ligne.startsWith('#DATE:')) continue;

      if (ligne.startsWith('#SECTION:')) {
        section = ligne.substring('#SECTION:'.length);
        skipEntete = true;
        continue;
      }
      if (skipEntete) {
        skipEntete = false;
        continue; // ligne d'en-tête
      }
      if (section == null) continue;

      final cols = _parserLigne(ligne);
      if (cols.isEmpty) continue;

      switch (section) {
        case 'tarifs':
          if (cols.length >= 5) tarifs.add(_TarifRow.parse(cols));
        case 'payeurs':
          if (cols.length >= 7) payeurs.add(_PayeurRow.parse(cols));
        case 'eleves':
          if (cols.length >= 11) eleves.add(_EleveRow.parse(cols));
        case 'cours':
          if (cols.length >= 12) cours.add(_CoursRow.parse(cols));
      }
    }

    // ── Restauration en transaction ──
    await db.transaction(() async {
      // Suppression dans l'ordre des dépendances FK
      await db.delete(db.cours).go();
      await db.delete(db.eleves).go();
      await db.delete(db.payeurs).go();
      await db.delete(db.tarifs).go();

      for (final t in tarifs) {
        await db.into(db.tarifs).insert(TarifsCompanion(
              tarifsId: Value(t.id),
              duree: Value(t.duree),
              prix: Value(t.prix),
              dateDebut: Value(t.dateDebut),
              dateFin:
                  t.dateFin != null ? Value(t.dateFin) : const Value(null),
            ));
      }

      for (final p in payeurs) {
        await db.into(db.payeurs).insert(PayeursCompanion(
              payeurId: Value(p.id),
              prenom: Value(EncryptionService.chiffrer(p.prenom) ?? p.prenom),
              nom: Value(EncryptionService.chiffrer(p.nom) ?? p.nom),
              telephone:
                  Value(EncryptionService.chiffrer(p.telephone) ?? p.telephone),
              adress: Value(EncryptionService.chiffrer(p.adress) ?? p.adress),
              cesuPlus: Value(p.cesuPlus),
              actif: Value(p.actif),
            ));
      }

      for (final e in eleves) {
        await db.into(db.eleves).insert(ElevesCompanion(
              elevesId: Value(e.id),
              prenom: Value(EncryptionService.chiffrer(e.prenom) ?? e.prenom),
              nom: Value(EncryptionService.chiffrer(e.nom) ?? e.nom),
              telephone:
                  Value(EncryptionService.chiffrer(e.telephone) ?? e.telephone),
              adress: Value(EncryptionService.chiffrer(e.adress) ?? e.adress),
              hebdo: Value(e.hebdo),
              jourSemaine: Value(e.jourSemaine),
              heureDebut:
                  e.heureDebut != null ? Value(e.heureDebut) : const Value(null),
              dureeCours:
                  e.dureeCours != null ? Value(e.dureeCours) : const Value(null),
              payeurId: Value(e.payeurId),
              actif: Value(e.actif),
              nomPere: e.nomPere != null
                  ? Value(EncryptionService.chiffrer(e.nomPere))
                  : const Value(null),
              nomMere: e.nomMere != null
                  ? Value(EncryptionService.chiffrer(e.nomMere))
                  : const Value(null),
            ));
      }

      for (final c in cours) {
        await db.into(db.cours).insert(CoursCompanion(
              coursId: Value(c.id),
              elevesId: Value(c.elevesId),
              datePrevue: Value(c.datePrevue),
              dateReelle:
                  c.dateReelle != null ? Value(c.dateReelle) : const Value(null),
              dureeReelle: c.dureeReelle != null
                  ? Value(c.dureeReelle)
                  : const Value(null),
              tarifsId:
                  c.tarifsId != null ? Value(c.tarifsId) : const Value(null),
              montant: c.montant != null ? Value(c.montant) : const Value(null),
              paye: Value(c.paye),
              datePaiement: c.datePaiement != null
                  ? Value(c.datePaiement)
                  : const Value(null),
              statut: Value(c.statut),
              exceptionnel: Value(c.exceptionnel),
              notes: c.notes != null ? Value(c.notes) : const Value(null),
            ));
      }
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _csv(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static List<String> _parserLigne(String ligne) {
    final cols = <String>[];
    final buf = StringBuffer();
    bool dansGuillemets = false;

    for (int i = 0; i < ligne.length; i++) {
      final c = ligne[i];
      if (c == '"') {
        if (dansGuillemets && i + 1 < ligne.length && ligne[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          dansGuillemets = !dansGuillemets;
        }
      } else if (c == ',' && !dansGuillemets) {
        cols.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    cols.add(buf.toString());
    return cols;
  }

  static bool _parseBool(String v) =>
      v.trim().toLowerCase() == 'true' || v.trim().toLowerCase() == 'oui';

  static DateTime? _parseDate(String v) {
    if (v.isEmpty) return null;
    try {
      return DateTime.parse(v);
    } catch (_) {
      return null;
    }
  }
}

// ── Modèles de parsing internes ───────────────────────────────────────────────

class _TarifRow {
  final int id, duree;
  final double prix;
  final DateTime dateDebut;
  final DateTime? dateFin;

  _TarifRow(this.id, this.duree, this.prix, this.dateDebut, this.dateFin);

  factory _TarifRow.parse(List<String> c) => _TarifRow(
        int.parse(c[0]),
        int.parse(c[1]),
        double.parse(c[2]),
        DateTime.parse(c[3]),
        BackupService._parseDate(c[4]),
      );
}

class _PayeurRow {
  final int id;
  final String prenom, nom, telephone, adress;
  final bool cesuPlus, actif;

  _PayeurRow(this.id, this.prenom, this.nom, this.telephone, this.adress,
      this.cesuPlus, this.actif);

  factory _PayeurRow.parse(List<String> c) => _PayeurRow(
        int.parse(c[0]),
        c[1], c[2], c[3], c[4],
        BackupService._parseBool(c[5]),
        BackupService._parseBool(c[6]),
      );
}

class _EleveRow {
  final int id, payeurId;
  final String prenom, nom, telephone, adress;
  final bool hebdo, actif;
  final int? jourSemaine, dureeCours;
  final String? heureDebut, nomPere, nomMere;

  _EleveRow(this.id, this.prenom, this.nom, this.telephone, this.adress,
      this.hebdo, this.jourSemaine, this.heureDebut, this.dureeCours,
      this.payeurId, this.actif, this.nomPere, this.nomMere);

  factory _EleveRow.parse(List<String> c) => _EleveRow(
        int.parse(c[0]),
        c[1], c[2], c[3], c[4],
        BackupService._parseBool(c[5]),
        c[6].isNotEmpty ? int.tryParse(c[6]) : null,
        c[7].isNotEmpty ? c[7] : null,
        c[8].isNotEmpty ? int.tryParse(c[8]) : null,
        int.parse(c[9]),
        BackupService._parseBool(c[10]),
        c.length > 11 && c[11].isNotEmpty ? c[11] : null,
        c.length > 12 && c[12].isNotEmpty ? c[12] : null,
      );
}

class _CoursRow {
  final int id, elevesId;
  final DateTime datePrevue;
  final DateTime? dateReelle, datePaiement;
  final int? dureeReelle, tarifsId;
  final double? montant;
  final bool paye, exceptionnel;
  final String statut;
  final String? notes;

  _CoursRow(
      this.id, this.elevesId, this.datePrevue, this.dateReelle,
      this.dureeReelle, this.tarifsId, this.montant, this.paye,
      this.datePaiement, this.statut, this.exceptionnel, this.notes);

  factory _CoursRow.parse(List<String> c) => _CoursRow(
        int.parse(c[0]),
        int.parse(c[1]),
        DateTime.parse(c[2]),
        BackupService._parseDate(c[3]),
        c[4].isNotEmpty ? int.tryParse(c[4]) : null,
        c[5].isNotEmpty ? int.tryParse(c[5]) : null,
        c[6].isNotEmpty ? double.tryParse(c[6]) : null,
        BackupService._parseBool(c[7]),
        BackupService._parseDate(c[8]),
        c[9],
        BackupService._parseBool(c[10]),
        c[11].isNotEmpty ? c[11] : null,
      );
}
