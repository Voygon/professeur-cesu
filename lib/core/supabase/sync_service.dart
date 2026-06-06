import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';
import '../database/daos/eleves_dao.dart';
import '../database/daos/payeurs_dao.dart';
import '../security/encryption_service.dart';
import 'auth_supabase_service.dart';

class SyncService {
  SyncService._();

  static final _client = Supabase.instance.client;
  static const _cleDernierSync = 'derniere_sync';

  // ── Dernière sync ─────────────────────────────────────────────────────────

  static Future<DateTime?> getDerniereSync() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_cleDernierSync);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  static Future<void> _saveDerniereSync(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cleDernierSync, date.toIso8601String());
  }

  // ── Sync complète ─────────────────────────────────────────────────────────

  static Future<void> synchroniser(
    AppDatabase db,
    ElevesDao elevesDao,
    PayeursDao payeursDao,
  ) async {
    if (!AuthSupabaseService.isConnected) return;
    final userId = AuthSupabaseService.userId!;
    final maintenant = DateTime.now();

    await _uploadTarifs(db, userId);
    await _uploadPayeurs(payeursDao, userId);
    await _uploadEleves(elevesDao, userId);
    await _uploadCours(db, userId);

    await _downloadTarifs(db, userId);
    await _downloadPayeurs(db, userId);
    await _downloadEleves(db, userId);
    await _downloadCours(db, userId);

    await _saveDerniereSync(maintenant);
  }

  // ── Upload ────────────────────────────────────────────────────────────────

  static Future<void> _uploadTarifs(AppDatabase db, String userId) async {
    final tarifs = await db.select(db.tarifs).get();
    for (final t in tarifs) {
      await _client.from('tarifs').upsert({
        'tarifs_id': t.tarifsId,
        'user_id': userId,
        'duree': t.duree,
        'prix': t.prix,
        'date_debut': t.dateDebut.toUtc().toIso8601String(),
        'date_fin': t.dateFin?.toUtc().toIso8601String(),
        'created_at': t.createdAt.toUtc().toIso8601String(),
      }, onConflict: 'tarifs_id,user_id');
    }
  }

  static Future<void> _uploadPayeurs(
    PayeursDao payeursDao,
    String userId,
  ) async {
    // searchPayeurs retourne des données déjà déchiffrées — envoi en clair vers Supabase
    final payeurs =
        await payeursDao.searchPayeurs('', inclureArchives: true).first;
    for (final p in payeurs) {
      await _client.from('payeurs').upsert({
        'payeur_id': p.payeurId,
        'user_id': userId,
        'prenom': p.prenom,
        'nom': p.nom,
        'telephone': p.telephone,
        'adress': p.adress,
        'cesu_plus': p.cesuPlus,
        'actif': p.actif,
        'created_at': p.createdAt.toUtc().toIso8601String(),
        'updated_at': p.updatedAt.toUtc().toIso8601String(),
      }, onConflict: 'payeur_id,user_id');
    }
  }

  static Future<void> _uploadEleves(
    ElevesDao elevesDao,
    String userId,
  ) async {
    final eleves =
        await elevesDao.searchEleves('', inclureArchives: true).first;
    for (final e in eleves) {
      await _client.from('eleves').upsert({
        'eleves_id': e.elevesId,
        'user_id': userId,
        'prenom': e.prenom,
        'nom': e.nom,
        'telephone': e.telephone,
        'adress': e.adress,
        'actif': e.actif,
        'hebdo': e.hebdo,
        'jour_semaine': e.jourSemaine,
        'heure_debut': e.heureDebut,
        'duree_cours': e.dureeCours,
        'payeur_id': e.payeurId,
        'nom_pere': e.nomPere,
        'nom_mere': e.nomMere,
        'created_at': e.createdAt.toUtc().toIso8601String(),
        'updated_at': e.updatedAt.toUtc().toIso8601String(),
      }, onConflict: 'eleves_id,user_id');
    }
  }

  static Future<void> _uploadCours(AppDatabase db, String userId) async {
    final coursList = await db.select(db.cours).get();

    for (final c in coursList) {
      await _client.from('cours').upsert({
        'cours_id': c.coursId,
        'user_id': userId,
        'eleves_id': c.elevesId,
        'date_prevue': c.datePrevue.toUtc().toIso8601String(),
        'date_reelle': c.dateReelle?.toUtc().toIso8601String(),
        'duree_reelle': c.dureeReelle,
        'tarifs_id': c.tarifsId,
        'montant': c.montant,
        'paye': c.paye,
        'date_paiement': c.datePaiement?.toUtc().toIso8601String(),
        'statut': c.statut,
        'exceptionnel': c.exceptionnel,
        'notes': c.notes,
        'created_at': c.createdAt.toUtc().toIso8601String(),
        'updated_at': c.updatedAt.toUtc().toIso8601String(),
      }, onConflict: 'cours_id,user_id');
    }

    // Propage les suppressions locales vers Supabase :
    // tout cours présent dans Supabase mais absent en local a été hard-deleté.
    final supRows = await _client
        .from('cours')
        .select('cours_id')
        .eq('user_id', userId);
    final supIds = supRows.map<int>((r) => r['cours_id'] as int).toSet();
    final localIds = coursList.map((c) => c.coursId).toSet();
    final aSupprimer = supIds.difference(localIds);
    for (final id in aSupprimer) {
      await _client
          .from('cours')
          .delete()
          .eq('cours_id', id)
          .eq('user_id', userId);
    }
  }

  // ── Download ──────────────────────────────────────────────────────────────

  static Future<void> _downloadTarifs(AppDatabase db, String userId) async {
    final rows =
        await _client.from('tarifs').select().eq('user_id', userId);

    await db.transaction(() async {
      for (final row in rows) {
        await db.into(db.tarifs).insertOnConflictUpdate(TarifsCompanion(
          tarifsId: Value(row['tarifs_id'] as int),
          duree: Value(row['duree'] as int),
          prix: Value((row['prix'] as num).toDouble()),
          dateDebut: Value(DateTime.parse(row['date_debut'] as String).toLocal()),
          dateFin: row['date_fin'] != null
              ? Value(DateTime.parse(row['date_fin'] as String).toLocal())
              : const Value<DateTime?>(null),
        ));
      }
    });
  }

  static Future<void> _downloadPayeurs(AppDatabase db, String userId) async {
    final rows =
        await _client.from('payeurs').select().eq('user_id', userId);

    await db.transaction(() async {
      for (final row in rows) {
        // Re-chiffre les données avant insertion locale
        final tel = (row['telephone'] as String?) ?? '';
        final adr = (row['adress'] as String?) ?? '';
        await db.into(db.payeurs).insertOnConflictUpdate(PayeursCompanion(
          payeurId: Value(row['payeur_id'] as int),
          prenom: Value(
              EncryptionService.chiffrer(row['prenom'] as String) ?? ''),
          nom: Value(EncryptionService.chiffrer(row['nom'] as String) ?? ''),
          telephone: Value(EncryptionService.chiffrer(tel) ?? ''),
          adress: Value(EncryptionService.chiffrer(adr) ?? ''),
          cesuPlus: Value(row['cesu_plus'] as bool),
          actif: Value(row['actif'] as bool),
        ));
      }
    });
  }

  static Future<void> _downloadEleves(AppDatabase db, String userId) async {
    final rows =
        await _client.from('eleves').select().eq('user_id', userId);

    await db.transaction(() async {
      for (final row in rows) {
        final tel = (row['telephone'] as String?) ?? '';
        final adr = (row['adress'] as String?) ?? '';
        await db.into(db.eleves).insertOnConflictUpdate(ElevesCompanion(
          elevesId: Value(row['eleves_id'] as int),
          prenom: Value(
              EncryptionService.chiffrer(row['prenom'] as String) ?? ''),
          nom: Value(EncryptionService.chiffrer(row['nom'] as String) ?? ''),
          telephone: Value(EncryptionService.chiffrer(tel) ?? ''),
          adress: Value(EncryptionService.chiffrer(adr) ?? ''),
          actif: Value(row['actif'] as bool),
          hebdo: Value(row['hebdo'] as bool),
          jourSemaine: Value(row['jour_semaine'] as int?),
          heureDebut: Value(row['heure_debut'] as String?),
          dureeCours: Value(row['duree_cours'] as int?),
          payeurId: Value(row['payeur_id'] as int),
          nomPere: Value(row['nom_pere'] != null
              ? EncryptionService.chiffrer(row['nom_pere'] as String)
              : null),
          nomMere: Value(row['nom_mere'] != null
              ? EncryptionService.chiffrer(row['nom_mere'] as String)
              : null),
        ));
      }
    });
  }

  static Future<void> _downloadCours(AppDatabase db, String userId) async {
    final rows =
        await _client.from('cours').select().eq('user_id', userId);

    await db.transaction(() async {
      for (final row in rows) {
        await db.into(db.cours).insertOnConflictUpdate(CoursCompanion(
          coursId: Value(row['cours_id'] as int),
          elevesId: Value(row['eleves_id'] as int),
          datePrevue: Value(DateTime.parse(row['date_prevue'] as String).toLocal()),
          dateReelle: Value(row['date_reelle'] != null
              ? DateTime.parse(row['date_reelle'] as String).toLocal()
              : null),
          dureeReelle: Value(row['duree_reelle'] as int?),
          tarifsId: Value(row['tarifs_id'] as int?),
          montant: Value(row['montant'] != null
              ? (row['montant'] as num).toDouble()
              : null),
          paye: Value(row['paye'] as bool),
          datePaiement: Value(row['date_paiement'] != null
              ? DateTime.parse(row['date_paiement'] as String).toLocal()
              : null),
          statut: Value(row['statut'] as String),
          exceptionnel: Value(row['exceptionnel'] as bool),
          notes: Value(row['notes'] as String?),
        ));
      }
    });
  }
}
