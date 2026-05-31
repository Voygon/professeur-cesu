import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:professeur_cesu/shared/models/eleve_avec_payeur.dart';
import '../../../core/database/app_database.dart';
import '../../../core/validators/eleve_validator.dart';
import '../../../core/validators/payeur_validator.dart';
import '../../../shared/models/enums.dart';
import '../../eleves/providers/eleves_provider.dart';
import '../../../shared/models/eleve_avec_payeur.dart';

class AjouterEleveSheet extends ConsumerStatefulWidget {
  final EleveAvecPayeur? eleveAvecPayeur;
  const AjouterEleveSheet({
    super.key,
    this.eleveAvecPayeur,
  });

  @override
  ConsumerState<AjouterEleveSheet> createState() => _AjouterEleveSheetState();
}

class _AjouterEleveSheetState extends ConsumerState<AjouterEleveSheet> {
  @override
  void initState() {
    super.initState();
    final ep = widget.eleveAvecPayeur;
    if (ep != null) {
      // Pré-remplit les champs élève
      _prenomEleveCtrl.text = ep.eleve.prenom;
      _nomEleveCtrl.text = ep.eleve.nom;
      _adresseEleveCtrl.text = ep.eleve.adress;
      _telEleveCtrl.text = ep.eleve.telephone;
      _hebdo = ep.eleve.hebdo;
      if (ep.eleve.jourSemaine != null) {
        _jourSemaine = JourSemaine.fromValeur(ep.eleve.jourSemaine!);
      }
      if (ep.eleve.heureDebut != null) {
        final parties = ep.eleve.heureDebut!.split(':');
        _heureDebut = TimeOfDay(
          hour: int.parse(parties[0]),
          minute: int.parse(parties[1]),
        );
      }
      // Pré-remplit les champs payeur
      _prenomPayeurCtrl.text = ep.payeur.prenom;
      _nomPayeurCtrl.text = ep.payeur.nom;
      _adressePayeurCtrl.text = ep.payeur.adress;
      _telPayeurCtrl.text = ep.payeur.telephone;
      _cesuPlus = ep.payeur.cesuPlus;
    }
  }

  final _formKey = GlobalKey<FormState>();

  // ── Étape courante ─────────────────────────────────
  int _etape = 1; // 1 = élève, 2 = payeur

  // ── Contrôleurs élève ──────────────────────────────
  final _prenomEleveCtrl = TextEditingController();
  final _nomEleveCtrl = TextEditingController();
  final _adresseEleveCtrl = TextEditingController();
  final _telEleveCtrl = TextEditingController();
  TimeOfDay? _heureDebut;

  bool _hebdo = false;
  JourSemaine? _jourSemaine;

  // ── Payeur ─────────────────────────────────────────
  bool _eleveEstPayeur = false; // true = adulte qui paye pour lui-même
  final _prenomPayeurCtrl = TextEditingController();
  final _nomPayeurCtrl = TextEditingController();
  final _adressePayeurCtrl = TextEditingController();
  final _telPayeurCtrl = TextEditingController();
  bool _cesuPlus = false;

  bool _chargement = false;

  @override
  void dispose() {
    _prenomEleveCtrl.dispose();
    _nomEleveCtrl.dispose();
    _adresseEleveCtrl.dispose();
    _telEleveCtrl.dispose();
    _prenomPayeurCtrl.dispose();
    _nomPayeurCtrl.dispose();
    _adressePayeurCtrl.dispose();
    _telPayeurCtrl.dispose();
    super.dispose();
  }

  // Copie les infos de l'élève vers le payeur quand "élève est payeur"
  void _copierInfosEleveVersPayeur() {
    _prenomPayeurCtrl.text = _prenomEleveCtrl.text;
    _nomPayeurCtrl.text = _nomEleveCtrl.text;
    _adressePayeurCtrl.text = _adresseEleveCtrl.text;
    _telPayeurCtrl.text = _telEleveCtrl.text;
  }

  Future<void> _valider() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _chargement = true);

    try {
      final heureStr = _heureDebut != null
          ? '${_heureDebut!.hour.toString().padLeft(2, '0')}:${_heureDebut!.minute.toString().padLeft(2, '0')}'
          : null;

      final eleve = ElevesCompanion(
        // En modification, on garde l'id existant
        elevesId: widget.eleveAvecPayeur != null
            ? Value(widget.eleveAvecPayeur!.eleve.elevesId)
            : const Value.absent(),
        prenom: Value(_prenomEleveCtrl.text.trim()),
        nom: Value(_nomEleveCtrl.text.trim()),
        adress: Value(_adresseEleveCtrl.text.trim()),
        telephone: Value(_telEleveCtrl.text.trim()),
        hebdo: Value(_hebdo),
        jourSemaine: Value(_jourSemaine?.valeur),
        heureDebut: heureStr != null ? Value(heureStr) : const Value.absent(),
        payeurId: widget.eleveAvecPayeur != null
            ? Value(widget.eleveAvecPayeur!.eleve.payeurId)
            : const Value.absent(),
      );

      final payeur = PayeursCompanion(
        prenom: Value(_prenomPayeurCtrl.text.trim()),
        nom: Value(_nomPayeurCtrl.text.trim()),
        adress: Value(_adressePayeurCtrl.text.trim()),
        telephone: Value(_telPayeurCtrl.text.trim()),
        cesuPlus: Value(_cesuPlus),
      );

      if (widget.eleveAvecPayeur != null) {
        // Mode modification
        await ref.read(elevesServiceProvider).modifierEleve(
              eleve: eleve,
              payeur: payeur,
              payeurId: widget.eleveAvecPayeur!.payeur.payeurId,
            );
      } else {
        // Mode ajout
        await ref.read(elevesServiceProvider).ajouterEleveAvecPayeur(
              eleve: eleve,
              payeur: payeur,
            );
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Remonte le formulaire quand le clavier apparaît
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Form(
            key: _formKey,
            child: Column(
              children: [
                // Poignée de drag
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Titre + indicateur d'étape
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        _etape == 1
                            ? (widget.eleveAvecPayeur != null
                                ? 'Modifier l\'élève'
                                : 'Nouvel élève')
                            : 'Payeur',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        'Étape $_etape / ${_eleveEstPayeur ? 1 : 2}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Contenu scrollable
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: _etape == 1 ? _champsEleve() : _champsPayeur(),
                  ),
                ),
                // Boutons navigation
                // Boutons navigation
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Row(
                      children: [
                        if (_etape == 2)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() => _etape = 1),
                              child: const Text('Retour'),
                            ),
                          ),
                        if (_etape == 2) const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _chargement ? null : _boutonSuivant,
                            child: _chargement
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(_etape == 1 && !_eleveEstPayeur
                                    ? 'Suivant'
                                    : 'Enregistrer'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _boutonSuivant() {
    if (!_formKey.currentState!.validate()) return;

    // Validation manuelle de l'heure
    if (_hebdo && _heureDebut == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez sélectionner une heure de début')),
      );
      return;
    }

    if (_etape == 1) {
      if (_eleveEstPayeur) {
        // Copie les infos et sauvegarde directement
        _copierInfosEleveVersPayeur();
        _valider();
      } else {
        // Passe à l'étape payeur
        setState(() => _etape = 2);
      }
    } else {
      _valider();
    }
  }

  List<Widget> _champsEleve() {
    return [
      // Prénom
      TextFormField(
        controller: _prenomEleveCtrl,
        decoration: const InputDecoration(labelText: 'Prénom *'),
        textCapitalization: TextCapitalization.words,
        validator: EleveValidator.validatePrenom,
      ),
      const SizedBox(height: 16),
      // Nom
      TextFormField(
        controller: _nomEleveCtrl,
        decoration: const InputDecoration(labelText: 'Nom *'),
        textCapitalization: TextCapitalization.words,
        validator: EleveValidator.validateNom,
      ),
      const SizedBox(height: 16),
      // Adresse
      TextFormField(
        controller: _adresseEleveCtrl,
        decoration: const InputDecoration(labelText: 'Adresse *'),
        validator: EleveValidator.validateAdresse,
      ),
      const SizedBox(height: 16),
      // Téléphone
      TextFormField(
        controller: _telEleveCtrl,
        decoration: const InputDecoration(labelText: 'Téléphone'),
        keyboardType: TextInputType.phone,
        validator: EleveValidator.validateTelephone,
      ),
      const SizedBox(height: 24),
      // Cours hebdo
      SwitchListTile(
        title: const Text('Cours hebdomadaire'),
        subtitle: const Text('Même jour et heure chaque semaine'),
        value: _hebdo,
        onChanged: (val) => setState(() => _hebdo = val),
        contentPadding: EdgeInsets.zero,
      ),
      if (_hebdo) ...[
        const SizedBox(height: 16),
        // Jour de la semaine
        DropdownButtonFormField<JourSemaine>(
          value: _jourSemaine,
          decoration: const InputDecoration(labelText: 'Jour *'),
          items: JourSemaine.values.map((j) {
            return DropdownMenuItem(
              value: j,
              child: Text(j.name[0].toUpperCase() + j.name.substring(1)),
            );
          }).toList(),
          onChanged: (val) => setState(() => _jourSemaine = val),
          validator: (_) =>
              EleveValidator.validateJourSemaine(_jourSemaine?.valeur),
        ),
        const SizedBox(height: 16),
        // Heure de début
        // Heure de début — sélecteur natif
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Heure de début *'),
          subtitle: Text(
            _heureDebut != null
                ? '${_heureDebut!.hour.toString().padLeft(2, '0')}:${_heureDebut!.minute.toString().padLeft(2, '0')}'
                : 'Non définie',
            style: TextStyle(
              color: _heureDebut != null
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: const Icon(Icons.access_time),
          onTap: () async {
            final heure = await showTimePicker(
              context: context,
              initialTime: _heureDebut ?? const TimeOfDay(hour: 17, minute: 0),
              builder: (context, child) {
                // Force le format 24h
                return MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(alwaysUse24HourFormat: true),
                  child: child!,
                );
              },
            );
            if (heure != null) setState(() => _heureDebut = heure);
          },
        ),
      ],
      const SizedBox(height: 24),
      // Qui est le payeur
      Text(
        'Qui règle les cours ?',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 8),
      RadioListTile<bool>(
        title: const Text('Un parent ou une autre personne'),
        value: false,
        groupValue: _eleveEstPayeur,
        onChanged: (val) => setState(() => _eleveEstPayeur = val!),
        contentPadding: EdgeInsets.zero,
      ),
      RadioListTile<bool>(
        title: const Text('L\'élève lui-même (adulte)'),
        value: true,
        groupValue: _eleveEstPayeur,
        onChanged: (val) => setState(() => _eleveEstPayeur = val!),
        contentPadding: EdgeInsets.zero,
      ),
    ];
  }

  List<Widget> _champsPayeur() {
    return [
      // Même adresse ?
      CheckboxListTile(
        title: const Text('Même adresse que l\'élève'),
        value: _adressePayeurCtrl.text == _adresseEleveCtrl.text &&
            _adressePayeurCtrl.text.isNotEmpty,
        onChanged: (val) {
          setState(() {
            if (val == true) {
              _adressePayeurCtrl.text = _adresseEleveCtrl.text;
            } else {
              _adressePayeurCtrl.clear();
            }
          });
        },
        contentPadding: EdgeInsets.zero,
      ),
      const SizedBox(height: 8),
      // Prénom payeur
      TextFormField(
        controller: _prenomPayeurCtrl,
        decoration: const InputDecoration(labelText: 'Prénom *'),
        textCapitalization: TextCapitalization.words,
        validator: PayeurValidator.validatePrenom,
      ),
      const SizedBox(height: 16),
      // Nom payeur
      TextFormField(
        controller: _nomPayeurCtrl,
        decoration: const InputDecoration(labelText: 'Nom *'),
        textCapitalization: TextCapitalization.words,
        validator: PayeurValidator.validateNom,
      ),
      const SizedBox(height: 16),
      // Adresse payeur
      TextFormField(
        controller: _adressePayeurCtrl,
        decoration: const InputDecoration(labelText: 'Adresse *'),
        validator: PayeurValidator.validateAdresse,
      ),
      const SizedBox(height: 16),
      // Téléphone payeur
      TextFormField(
        controller: _telPayeurCtrl,
        decoration: const InputDecoration(labelText: 'Téléphone'),
        keyboardType: TextInputType.phone,
        validator: PayeurValidator.validateTelephone,
      ),
      const SizedBox(height: 24),
      // CESU+
      SwitchListTile(
        title: const Text('CESU+'),
        subtitle: const Text('Le payeur utilise CESU+'),
        value: _cesuPlus,
        onChanged: (val) => setState(() => _cesuPlus = val),
        contentPadding: EdgeInsets.zero,
      ),
    ];
  }
}
