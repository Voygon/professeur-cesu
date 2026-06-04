import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../shared/models/enums.dart';
import '../database/app_database.dart';
import 'import_models.dart';
import 'import_service.dart';

class PreviewEleveSheet extends StatefulWidget {
  final LigneImport ligne;
  final String? titre;
  const PreviewEleveSheet({super.key, required this.ligne, this.titre});

  @override
  State<PreviewEleveSheet> createState() => _PreviewEleveSheetState();
}

class _PreviewEleveSheetState extends State<PreviewEleveSheet> {
  // ── Élève ──
  late final TextEditingController _prenomCtrl;
  late final TextEditingController _nomCtrl;
  late final TextEditingController _telCtrl;
  late final TextEditingController _adresseCtrl;
  late bool _hebdo;
  late int? _jourSemaine;
  late final TextEditingController _heureCtrl;
  late final TextEditingController _dureeCtrl;

  // ── Payeur ──
  late bool _hasPayeur;
  late final TextEditingController _prenomPayCtrl;
  late final TextEditingController _nomPayCtrl;
  late final TextEditingController _telPayCtrl;
  late final TextEditingController _adressePayCtrl;
  late bool _cesuPlus;

  late Map<String, String> _erreurs;

  @override
  void initState() {
    super.initState();
    final e = widget.ligne.eleve;
    final p = widget.ligne.payeur;

    _prenomCtrl = TextEditingController(text: e.prenom.present ? e.prenom.value : '');
    _nomCtrl    = TextEditingController(text: e.nom.present ? e.nom.value : '');
    _telCtrl    = TextEditingController(text: e.telephone.present ? e.telephone.value : '');
    _adresseCtrl = TextEditingController(text: e.adress.present ? e.adress.value : '');
    _hebdo      = e.hebdo.present ? e.hebdo.value : false;
    _jourSemaine = e.jourSemaine.present ? e.jourSemaine.value : null;
    _heureCtrl  = TextEditingController(
        text: e.heureDebut.present ? (e.heureDebut.value ?? '') : '');
    _dureeCtrl  = TextEditingController(
        text: e.dureeCours.present && e.dureeCours.value != null
            ? '${e.dureeCours.value}'
            : '');

    _hasPayeur     = p != null;
    _prenomPayCtrl = TextEditingController(text: p?.prenom.present == true ? p!.prenom.value : '');
    _nomPayCtrl    = TextEditingController(text: p?.nom.present == true ? p!.nom.value : '');
    _telPayCtrl    = TextEditingController(text: p?.telephone.present == true ? p!.telephone.value : '');
    _adressePayCtrl = TextEditingController(text: p?.adress.present == true ? p!.adress.value : '');
    _cesuPlus      = p != null && p.cesuPlus.present ? p.cesuPlus.value : false;

    _erreurs = Map.from(widget.ligne.erreursValidation);
  }

  @override
  void dispose() {
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _telCtrl.dispose();
    _adresseCtrl.dispose();
    _heureCtrl.dispose();
    _dureeCtrl.dispose();
    _prenomPayCtrl.dispose();
    _nomPayCtrl.dispose();
    _telPayCtrl.dispose();
    _adressePayCtrl.dispose();
    super.dispose();
  }

  void _sauvegarder() {
    final eleve = ElevesCompanion(
      prenom:     Value(_prenomCtrl.text.trim()),
      nom:        Value(_nomCtrl.text.trim()),
      telephone:  Value(_telCtrl.text.trim()),
      adress:     Value(_adresseCtrl.text.trim()),
      hebdo:      Value(_hebdo),
      jourSemaine: Value(_hebdo ? _jourSemaine : null),
      heureDebut: _hebdo && _heureCtrl.text.trim().isNotEmpty
          ? Value(_heureCtrl.text.trim())
          : const Value(null),
      dureeCours: _hebdo
          ? Value(int.tryParse(_dureeCtrl.text.trim()))
          : const Value(null),
    );

    PayeursCompanion? payeur;
    if (_hasPayeur &&
        _prenomPayCtrl.text.trim().isNotEmpty &&
        _nomPayCtrl.text.trim().isNotEmpty) {
      payeur = PayeursCompanion(
        prenom:    Value(_prenomPayCtrl.text.trim()),
        nom:       Value(_nomPayCtrl.text.trim()),
        telephone: Value(_telPayCtrl.text.trim()),
        adress:    Value(_adressePayCtrl.text.trim()),
        cesuPlus:  Value(_cesuPlus),
      );
    }

    final erreurs = ImportService.validerLigne(eleve, payeur);

    Navigator.pop(
      context,
      LigneImport(
        numeroLigne: widget.ligne.numeroLigne,
        eleve: eleve,
        payeur: payeur,
        statut: payeur == null
            ? StatutImport.payeurManquant
            : erreurs.isNotEmpty
                ? StatutImport.avertissement
                : StatutImport.ok,
        erreursValidation: erreurs,
      ),
    );
  }

  void _effacerErreur(String cle) {
    if (_erreurs.containsKey(cle)) setState(() => _erreurs.remove(cle));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) => Column(
        children: [
          // ── En-tête fixe ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.titre ?? 'Ligne ${widget.ligne.numeroLigne}',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (_erreurs.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_erreurs.length} champ(s) invalide(s) — corrigez les champs en rouge',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Formulaire scrollable ──
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                // ── Section élève ──
                _sectionTitre(context, 'Élève'),
                _champTexte('Prénom *', _prenomCtrl, 'eleve_prenom'),
                _champTexte('Nom *', _nomCtrl, 'eleve_nom'),
                _champTexte('Téléphone', _telCtrl, 'eleve_telephone',
                    type: TextInputType.phone),
                _champTexte('Adresse *', _adresseCtrl, 'eleve_adresse'),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cours hebdomadaire'),
                  value: _hebdo,
                  onChanged: (v) => setState(() {
                    _hebdo = v;
                    if (!v) _jourSemaine = null;
                  }),
                ),

                if (_hebdo) ...[
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int>(
                    initialValue: _jourSemaine,
                    decoration: InputDecoration(
                      labelText: 'Jour *',
                      border: const OutlineInputBorder(),
                      errorText: _erreurs['eleve_jour'],
                    ),
                    items: JourSemaine.values.map((j) {
                      final label = j.name[0].toUpperCase() + j.name.substring(1);
                      return DropdownMenuItem(value: j.valeur, child: Text(label));
                    }).toList(),
                    onChanged: (v) => setState(() {
                      _jourSemaine = v;
                      _effacerErreur('eleve_jour');
                    }),
                  ),
                  const SizedBox(height: 12),
                  _champTexte('Heure (ex : 17:00) *', _heureCtrl, 'eleve_heure'),
                  _champTexte('Durée (minutes)', _dureeCtrl, null,
                      type: TextInputType.number),
                ],

                // ── Section payeur ──
                _sectionTitre(context, 'Payeur'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Payeur renseigné'),
                  value: _hasPayeur,
                  onChanged: (v) => setState(() => _hasPayeur = v),
                ),

                if (_hasPayeur) ...[
                  _champTexte('Prénom payeur *', _prenomPayCtrl, 'payeur_prenom'),
                  _champTexte('Nom payeur *', _nomPayCtrl, 'payeur_nom'),
                  _champTexte('Téléphone payeur', _telPayCtrl, 'payeur_telephone',
                      type: TextInputType.phone),
                  _champTexte('Adresse payeur *', _adressePayCtrl, 'payeur_adresse'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('CESU+'),
                    value: _cesuPlus,
                    onChanged: (v) => setState(() => _cesuPlus = v),
                  ),
                ],

                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _sauvegarder,
                        child: const Text('Sauvegarder'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitre(BuildContext context, String titre) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: Text(
        titre,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _champTexte(
    String label,
    TextEditingController ctrl,
    String? erreurCle, {
    TextInputType? type,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        onChanged: erreurCle != null ? (_) => _effacerErreur(erreurCle) : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          errorText: erreurCle != null ? _erreurs[erreurCle] : null,
        ),
      ),
    );
  }
}
