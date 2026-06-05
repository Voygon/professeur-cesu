import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_provider.dart';
import 'import_models.dart';
import 'import_service.dart';
import 'preview_eleve_sheet.dart';
import '../database/app_database.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  List<LigneImport> _lignes = [];
  bool _chargement = false;

  // ── Sélection du fichier ─────────────────────────────────────────────────

  Future<void> _selectionnerFichier() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.single.path == null) return;

    setState(() => _chargement = true);
    try {
      final contenu = await File(result.files.single.path!).readAsString();
      final lignes = ImportService.parserCsv(contenu);

      // Détection des conflits
      final elevesDao = ref.read(elevesDaoProvider);
      await ImportService.detecterConflits(lignes, elevesDao);

      setState(() {
        _lignes = lignes;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lecture fichier : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  // ── Télécharger le template ──────────────────────────────────────────────

  Future<void> _telechargerTemplate() async {
    try {
      final dir = await FilePicker.platform.getDirectoryPath();
      if (dir == null) return;
      final file = File('$dir/template_import_eleves.csv');
      await file.writeAsString(ImportService.genererTemplate());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template sauvegardé dans $dir')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  // ── Résolution des conflits et payeurs manquants ─────────────────────────

  Future<void> _resoudreConflitsEtImporter() async {
    // Informe l'utilisateur des lignes impossibles à importer
    final lignesErreur =
        _lignes.where((l) => l.statut == StatutImport.erreur).toList();

    if (lignesErreur.isNotEmpty) {
      final continuer = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Lignes non importables'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${lignesErreur.length} ligne(s) ne peuvent pas être '
                  'importées car les données sont incomplètes ou illisibles. '
                  'Elles seront ignorées :',
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: lignesErreur.map((l) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '• Ligne ${l.numeroLigne} — ${l.message ?? 'Données invalides'}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      )).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuer sans ces lignes'),
            ),
          ],
        ),
      );
      if (continuer != true) return;
    }

    // Résout d'abord les payeurs manquants
    for (int i = 0; i < _lignes.length; i++) {
      final ligne = _lignes[i];
      if (ligne.statut != StatutImport.payeurManquant) continue;

      final choix = await _dialoguePayeurManquant(ligne);
      if (!mounted) return;

      if (choix == null) {
        // Annulation → ignore cette ligne
        setState(() => _lignes[i] = LigneImport(
          numeroLigne: ligne.numeroLigne,
          eleve: ligne.eleve,
          statut: StatutImport.ignore,
        ));
      } else {
        setState(() => _lignes[i] = LigneImport(
          numeroLigne: ligne.numeroLigne,
          eleve: ligne.eleve,
          payeur: choix,
          statut: StatutImport.ok,
        ));
      }
    }

    // Résout ensuite les conflits
    for (int i = 0; i < _lignes.length; i++) {
      final ligne = _lignes[i];
      if (ligne.statut != StatutImport.conflit) continue;

      final choix = await _dialogueConflit(ligne);
      if (!mounted) return;

      switch (choix) {
        case 'nouvel_eleve':
          // Ajoute ' 2' au prénom
          final prenomModifie = '${ligne.eleve.prenom.value} 2';
          setState(() => _lignes[i] = LigneImport(
            numeroLigne: ligne.numeroLigne,
            eleve: ligne.eleve.copyWith(
              prenom: Value(prenomModifie),
            ),
            payeur: ligne.payeur,
            statut: StatutImport.ok,
          ));
        case 'mettre_a_jour':
          // Marque pour mise à jour — à gérer dans l'insertion
          setState(() => _lignes[i] = LigneImport(
            numeroLigne: ligne.numeroLigne,
            eleve: ligne.eleve,
            payeur: ligne.payeur,
            statut: StatutImport.ok,
            eleveExistant: ligne.eleveExistant,
          ));
        default:
          // Ignorer
          setState(() => _lignes[i] = LigneImport(
            numeroLigne: ligne.numeroLigne,
            eleve: ligne.eleve,
            statut: StatutImport.ignore,
          ));
      }
    }

    // Correction des avertissements ligne par ligne
    final indicesAvertissements = [
      for (int i = 0; i < _lignes.length; i++)
        if (_lignes[i].statut == StatutImport.avertissement) i,
    ];
    final total = indicesAvertissements.length;

    for (int rang = 0; rang < indicesAvertissements.length; rang++) {
      if (!mounted) return;
      final i = indicesAvertissements[rang];
      final ligne = _lignes[i];

      final ligneCorrigee = await showModalBottomSheet<LigneImport>(
        context: context,
        isScrollControlled: true,
        builder: (_) => PreviewEleveSheet(
          ligne: ligne,
          titre: 'Données invalides — ${rang + 1} / $total',
        ),
      );
      if (!mounted) return;
      if (ligneCorrigee != null) {
        setState(() => _lignes[i] = ligneCorrigee);
      }
    }

    // Confirmation finale pour les avertissements non corrigés
    if (!mounted) return;
    final nbRestants =
        _lignes.where((l) => l.statut == StatutImport.avertissement).length;

    if (nbRestants > 0) {
      final continuer = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Données encore invalides'),
          content: Text(
            '$nbRestants ligne(s) ont encore des données invalides.\n'
            'Voulez-vous les importer quand même ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Importer quand même'),
            ),
          ],
        ),
      );
      if (continuer != true) return;
    }

    // Lance l'insertion
    setState(() => _chargement = true);
    try {
      final elevesDao = ref.read(elevesDaoProvider);
      final payeursDao = ref.read(payeursDaoProvider);
      final resultat = await ImportService.inserer(
          _lignes, elevesDao, payeursDao);

      if (mounted) _afficherResultat(resultat);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  // ── Dialogues ────────────────────────────────────────────────────────────

  Future<PayeursCompanion?> _dialoguePayeurManquant(
      LigneImport ligne) async {
    return showDialog<PayeursCompanion?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DialoguePayeurManquant(ligne: ligne),
    );
  }

  Future<String?> _dialogueConflit(LigneImport ligne) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Élève déjà existant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ligne.message ?? ''),
            const SizedBox(height: 16),
            const Text('Que voulez-vous faire ?',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'ignorer'),
            child: const Text('Ne rien faire'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'mettre_a_jour'),
            child: const Text('Mettre à jour'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'nouvel_eleve'),
            child: const Text('Nouvel élève'),
          ),
        ],
      ),
    );
  }

  void _afficherResultat(ResultatImport resultat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import terminé'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LigneResultat(
                icon: Icons.check_circle_outline,
                couleur: Colors.green,
                texte: '${resultat.nbOk} importés avec succès'),
            if (resultat.nbIgnores > 0)
              _LigneResultat(
                  icon: Icons.remove_circle_outline,
                  couleur: Colors.grey,
                  texte: '${resultat.nbIgnores} ignorés'),
            if (resultat.nbErreurs > 0)
              _LigneResultat(
                  icon: Icons.block_outlined,
                  couleur: Colors.red,
                  texte: '${resultat.nbErreurs} ligne(s) non importée(s)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Ferme l'écran d'import
            },
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final nbOk = _lignes.where((l) => l.statut == StatutImport.ok).length;
    final nbConflits =
        _lignes.where((l) => l.statut == StatutImport.conflit).length;
    final nbPayeursManquants =
        _lignes.where((l) => l.statut == StatutImport.payeurManquant).length;
    final nbErreurs =
        _lignes.where((l) => l.statut == StatutImport.erreur).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Importer des données')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Template ──
          Card(
            child: ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Télécharger le template'),
              subtitle: const Text('Fichier CSV pré-rempli avec un exemple'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _telechargerTemplate,
            ),
          ),
          const SizedBox(height: 24),

          // ── Sélection fichier ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _chargement ? null : _selectionnerFichier,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Sélectionner un fichier CSV'),
            ),
          ),

          // ── Rapport de parsing ──
          if (_lignes.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Rapport',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _LigneResultat(
                        icon: Icons.check_circle_outline,
                        couleur: Colors.green,
                        texte: '$nbOk lignes prêtes'),
                    if (nbConflits > 0)
                      _LigneResultat(
                          icon: Icons.warning_amber_outlined,
                          couleur: Colors.orange,
                          texte: '$nbConflits conflits à résoudre'),
                    if (nbPayeursManquants > 0)
                      _LigneResultat(
                          icon: Icons.person_add_outlined,
                          couleur: Colors.blue,
                          texte: '$nbPayeursManquants payeurs manquants'),
                    if (nbErreurs > 0)
                      _LigneResultat(
                          icon: Icons.block_outlined,
                          couleur: Colors.red,
                          texte: '$nbErreurs ligne(s) non importable(s)'),
                  ],
                ),
              ),
            ),

            // ── Liste des lignes ──
            const SizedBox(height: 16),
            ..._lignes.asMap().entries.map((e) => _CarteLigne(
              ligne: e.value,
              onModifie: (ligneModifiee) =>
                  setState(() => _lignes[e.key] = ligneModifiee),
            )),

            const SizedBox(height: 24),
            if (nbErreurs < _lignes.length)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      _chargement ? null : _resoudreConflitsEtImporter,
                  icon: _chargement
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_done_outlined),
                  label: Text(
                    nbConflits + nbPayeursManquants > 0
                        ? 'Résoudre et importer'
                        : 'Importer',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Widgets helpers ──────────────────────────────────────────────────────────

class _LigneResultat extends StatelessWidget {
  final IconData icon;
  final Color couleur;
  final String texte;

  const _LigneResultat({
    required this.icon,
    required this.couleur,
    required this.texte,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: couleur, size: 20),
          const SizedBox(width: 8),
          Text(texte),
        ],
      ),
    );
  }
}

class _CarteLigne extends StatelessWidget {
  final LigneImport ligne;
  final void Function(LigneImport) onModifie;
  const _CarteLigne({required this.ligne, required this.onModifie});

  @override
  Widget build(BuildContext context) {
    final (couleur, icon) = switch (ligne.statut) {
      StatutImport.ok => (Colors.green, Icons.check_circle_outline),
      StatutImport.avertissement => (Colors.orange, Icons.warning_amber_outlined),
      StatutImport.conflit => (Colors.orange, Icons.warning_amber_outlined),
      StatutImport.payeurManquant => (Colors.blue, Icons.person_add_outlined),
      StatutImport.erreur => (Colors.red, Icons.error_outline),
      StatutImport.ignore => (Colors.grey, Icons.remove_circle_outline),
    };

    final prenom = ligne.eleve.prenom.present ? ligne.eleve.prenom.value : '—';
    final nom = ligne.eleve.nom.present ? ligne.eleve.nom.value : '';
    final nbErreurs = ligne.erreursValidation.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: couleur),
        title: Text('Ligne ${ligne.numeroLigne} — $prenom $nom'),
        subtitle: nbErreurs > 0
            ? Text(
                '$nbErreurs champ(s) invalide(s)',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            : (ligne.message != null ? Text(ligne.message!) : null),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final result = await showModalBottomSheet<LigneImport>(
            context: context,
            isScrollControlled: true,
            builder: (_) => PreviewEleveSheet(ligne: ligne),
          );
          if (result != null) onModifie(result);
        },
      ),
    );
  }
}

// ── Dialogue payeur manquant ─────────────────────────────────────────────────

class _DialoguePayeurManquant extends StatefulWidget {
  final LigneImport ligne;
  const _DialoguePayeurManquant({required this.ligne});

  @override
  State<_DialoguePayeurManquant> createState() =>
      _DialoguePayeurManquantState();
}

class _DialoguePayeurManquantState
    extends State<_DialoguePayeurManquant> {
  final _prenomCtrl = TextEditingController();
  final _nomCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();
  bool _cesuPlus = false;
  bool _eleveEstPayeur = false;

  @override
  void dispose() {
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _telCtrl.dispose();
    _adresseCtrl.dispose();
    super.dispose();
  }

  void _remplirAvecEleve() {
    final e = widget.ligne.eleve;
    _prenomCtrl.text = e.prenom.present ? e.prenom.value : '';
    _nomCtrl.text = e.nom.present ? e.nom.value : '';
    _telCtrl.text = e.telephone.present ? e.telephone.value : '';
    _adresseCtrl.text = e.adress.present ? e.adress.value : '';
  }

  @override
  Widget build(BuildContext context) {
    final prenom = widget.ligne.eleve.prenom.present
        ? widget.ligne.eleve.prenom.value
        : '?';
    final nom =
        widget.ligne.eleve.nom.present ? widget.ligne.eleve.nom.value : '';

    return AlertDialog(
      title: Text('Payeur manquant — $prenom $nom'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Cet élève n\'a pas de payeur renseigné.'),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('L\'élève est son propre payeur'),
              value: _eleveEstPayeur,
              onChanged: (v) {
                setState(() => _eleveEstPayeur = v ?? false);
                if (_eleveEstPayeur) _remplirAvecEleve();
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _prenomCtrl,
              decoration: const InputDecoration(labelText: 'Prénom payeur'),
              enabled: !_eleveEstPayeur,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nomCtrl,
              decoration: const InputDecoration(labelText: 'Nom payeur'),
              enabled: !_eleveEstPayeur,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _telCtrl,
              decoration: const InputDecoration(labelText: 'Téléphone'),
              enabled: !_eleveEstPayeur,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _adresseCtrl,
              decoration: const InputDecoration(labelText: 'Adresse'),
              enabled: !_eleveEstPayeur,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('CESU+'),
              value: _cesuPlus,
              onChanged: (v) => setState(() => _cesuPlus = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Ignorer cet élève'),
        ),
        TextButton(
          onPressed: () {
            if (_prenomCtrl.text.isEmpty || _nomCtrl.text.isEmpty) return;
            Navigator.pop(
              context,
              PayeursCompanion(
                prenom: Value(_prenomCtrl.text.trim()),
                nom: Value(_nomCtrl.text.trim()),
                telephone: Value(_telCtrl.text.trim()),
                adress: Value(_adresseCtrl.text.trim()),
                cesuPlus: Value(_cesuPlus),
              ),
            );
          },
          child: const Text('Confirmer'),
        ),
      ],
    );
  }
}