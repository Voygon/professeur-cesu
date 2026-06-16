import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/database_provider.dart';

// ── Rappel avant les cours ───────────────────────────────────────────────────

const _cleRappel = 'rappel_minutes_avant';
const _rappelDefaut = 30;

final rappelMinutesProvider =
    StateNotifierProvider<RappelMinutesNotifier, int>(
        (_) => RappelMinutesNotifier());

class RappelMinutesNotifier extends StateNotifier<int> {
  RappelMinutesNotifier() : super(_rappelDefaut) {
    _charger();
  }

  Future<void> _charger() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_cleRappel) ?? _rappelDefaut;
  }

  Future<void> setRappel(int minutes) async {
    state = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_cleRappel, minutes);
  }
}

// ── Espacement minimum entre cours ───────────────────────────────────────────

const _cleEspacementMinCours = 'espacement_min_cours';
const _espacementDefaut = 15;

final espacementProvider =
    StateNotifierProvider<EspacementNotifier, int>((_) => EspacementNotifier());

class EspacementNotifier extends StateNotifier<int> {
  EspacementNotifier() : super(_espacementDefaut) {
    _charger();
  }

  Future<void> _charger() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_cleEspacementMinCours) ?? _espacementDefaut;
  }

  Future<void> setEspacement(int valeur) async {
    state = valeur;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_cleEspacementMinCours, valeur);
  }
}

// ── Purge automatique des cours annulés ──────────────────────────────────────

const _clePurgeAnnules = 'purge_annules_jours';

// null = jamais, sinon nombre de jours avant suppression automatique
final purgeAnnulesProvider =
    StateNotifierProvider<PurgeAnnulesNotifier, int?>(
        (_) => PurgeAnnulesNotifier());

class PurgeAnnulesNotifier extends StateNotifier<int?> {
  PurgeAnnulesNotifier() : super(null) {
    _charger();
  }

  Future<void> _charger() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_clePurgeAnnules);
  }

  Future<void> setDelai(int? jours) async {
    state = jours;
    final prefs = await SharedPreferences.getInstance();
    if (jours == null) {
      await prefs.remove(_clePurgeAnnules);
    } else {
      await prefs.setInt(_clePurgeAnnules, jours);
    }
  }
}

// Compte les cours annulés — affiché dans la tuile paramètres
final nbCoursAnnulesProvider = StreamProvider<int>((ref) {
  return ref
      .watch(coursDaoProvider)
      .watchCoursAnnules()
      .map((liste) => liste.length);
});

