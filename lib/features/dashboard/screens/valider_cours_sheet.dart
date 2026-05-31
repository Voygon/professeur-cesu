import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../shared/models/enums.dart';
import '../../parametres/providers/tarifs_provider.dart';

class ValiderCoursSheet extends ConsumerStatefulWidget {
  final Cour cours;
  final Eleve eleve;

  const ValiderCoursSheet({
    super.key,
    required this.cours,
    required this.eleve,
  });

  @override
  ConsumerState<ValiderCoursSheet> createState() => _ValiderCoursSheetState();
}

class _ValiderCoursSheetState extends ConsumerState<ValiderCoursSheet> {
  late int _duree;
  bool _modeManuel = false;
  final _dureeManuelleCtrl = TextEditingController();
  double? _montant;
  bool _chargement = false;
  late DateTime _date;
  late TimeOfDay _heure;

  @override
  void initState() {
    super.initState();
    _duree = widget.cours.dureeReelle ?? widget.eleve.dureeCours ?? 60;
    _dureeManuelleCtrl.text = _duree.toString();
    _date = DateTime(
      widget.cours.datePrevue.year,
      widget.cours.datePrevue.month,
      widget.cours.datePrevue.day,
    );
    _heure = TimeOfDay(
      hour: widget.cours.datePrevue.hour,
      minute: widget.cours.datePrevue.minute,
    );
    _calculerMontant();
  }

  @override
  void dispose() {
    _dureeManuelleCtrl.dispose();
    super.dispose();
  }

  Future<void> _calculerMontant() async {
    final montant = await ref.read(tarifsDaoProvider).calculerMontant(_duree);
    if (mounted) setState(() => _montant = montant);
  }

  DateTime get _nouvelleDatePrevue => DateTime(
        _date.year, _date.month, _date.day, _heure.hour, _heure.minute,
      );

  Future<void> _sauvegarder() async {
    if (_montant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Aucun tarif défini — ajoutez un tarif dans les paramètres'),
        ),
      );
      return;
    }

    setState(() => _chargement = true);
    try {
      final nouvelleDatePrevue = _nouvelleDatePrevue;
      if (nouvelleDatePrevue != widget.cours.datePrevue) {
        await ref
            .read(coursDaoProvider)
            .deplacerCours(widget.cours.coursId, nouvelleDatePrevue);
      }
      await ref.read(coursDaoProvider).validerCours(
            widget.cours.coursId,
            montant: _montant!,
            dureeReelle: _duree,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _remettreEnAttente() async {
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la validation ?'),
        content: const Text(
            'Le cours repassera en "Prévu" et le montant sera effacé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Oui, annuler la validation'),
          ),
        ],
      ),
    );
    if (confirmer == true && mounted) {
      await ref.read(coursDaoProvider).remettreEnAttente(widget.cours.coursId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _annuler() async {
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler ce cours ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (confirmer == true && mounted) {
      await ref.read(coursDaoProvider).annulerCours(widget.cours.coursId);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statut = StatutCours.fromDb(widget.cours.statut);
    final estAnnule = statut == StatutCours.annule;
    final tarifs = ref.watch(tarifsEnCoursProvider).valueOrNull ?? [];

    // Si la durée actuelle ne correspond à aucun tarif, bascule en mode manuel
    final tarifCorrespond = tarifs.any((t) => t.duree == _duree);
    final showTextField = _modeManuel || (tarifs.isNotEmpty && !tarifCorrespond);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poignée
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

              // Titre + badge statut
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${widget.eleve.prenom} ${widget.eleve.nom}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statut.couleurFond,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statut.label,
                      style: TextStyle(
                        color: statut.couleur,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Date ──
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Date du cours'),
                subtitle: Text(
                    '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}'),
                enabled: !estAnnule,
                onTap: estAnnule
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
              ),

              // ── Heure ──
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time_outlined),
                title: const Text('Heure'),
                subtitle: Text(
                    '${_heure.hour.toString().padLeft(2, '0')}:${_heure.minute.toString().padLeft(2, '0')}'),
                enabled: !estAnnule,
                onTap: estAnnule
                    ? null
                    : () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _heure,
                          builder: (context, child) => MediaQuery(
                            data: MediaQuery.of(context)
                                .copyWith(alwaysUse24HourFormat: true),
                            child: child!,
                          ),
                        );
                        if (picked != null) setState(() => _heure = picked);
                      },
              ),

              if (!estAnnule) ...[
                const SizedBox(height: 8),

                // ── Durée — dropdown tarifs ──
                DropdownButtonFormField<int?>(
                  initialValue: showTextField
                      ? null
                      : (tarifCorrespond ? _duree : null),
                  decoration: const InputDecoration(labelText: 'Durée'),
                  hint: const Text('Choisir une durée'),
                  items: [
                    ...tarifs.map((t) => DropdownMenuItem<int?>(
                          value: t.duree,
                          child: Text(
                              '${t.duree} min — ${t.prix.toStringAsFixed(2)} €'),
                        )),
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Autre durée'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _duree = val;
                        _modeManuel = false;
                        _dureeManuelleCtrl.clear();
                      });
                      _calculerMontant();
                    } else {
                      setState(() {
                        _modeManuel = true;
                        _dureeManuelleCtrl.text = _duree.toString();
                      });
                    }
                  },
                ),

                // ── Champ texte durée manuelle ──
                if (showTextField) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _dureeManuelleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Durée personnalisée',
                      suffixText: 'min',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final d = int.tryParse(v);
                      if (d != null && d > 0) {
                        setState(() => _duree = d);
                        _calculerMontant();
                      }
                    },
                  ),
                ],

                const SizedBox(height: 16),

                // ── Montant ──
                Text(
                  _montant != null
                      ? 'Montant : ${_montant!.toStringAsFixed(2)} €'
                      : 'Aucun tarif défini',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _montant != null
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 24),

                // ── Boutons ──
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _chargement ? null : _sauvegarder,
                    icon: Icon(statut == StatutCours.prevu
                        ? Icons.check
                        : Icons.save_outlined),
                    label: _chargement
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(statut == StatutCours.prevu
                            ? 'Valider le cours'
                            : 'Enregistrer les corrections'),
                  ),
                ),
                if (statut == StatutCours.prevu) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _annuler,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Annuler le cours'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                if (statut == StatutCours.effectue ||
                    statut == StatutCours.modifie) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _remettreEnAttente,
                      icon: const Icon(Icons.undo_outlined),
                      label: const Text('Annuler la validation'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ] else ...[
                // Cours annulé — lecture seule
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fermer'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
