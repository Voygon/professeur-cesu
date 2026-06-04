import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
