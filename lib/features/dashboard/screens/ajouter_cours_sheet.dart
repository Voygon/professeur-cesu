import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/heure_picker.dart';
import '../../eleves/providers/eleves_provider.dart';
import '../../parametres/providers/tarifs_provider.dart';
import '../../../shared/utils/money.dart';

class AjouterCoursSheet extends ConsumerStatefulWidget {
  const AjouterCoursSheet({super.key});

  @override
  ConsumerState<AjouterCoursSheet> createState() =>
      _AjouterCoursSheetState();
}

class _AjouterCoursSheetState extends ConsumerState<AjouterCoursSheet> {
  Eleve? _eleve;
  DateTime _date = DateTime.now();
  TimeOfDay _heure = TimeOfDay.now();
  int? _duree;
  bool _modeManuel = false;
  final _dureeManuelleCtrl = TextEditingController();
  StatutCours _statut = StatutCours.prevu;
  int? _montant;
  bool _chargement = false;

  @override
  void dispose() {
    _dureeManuelleCtrl.dispose();
    super.dispose();
  }

  Future<void> _calculerMontant() async {
    if (_duree == null) {
      setState(() => _montant = null);
      return;
    }
    final montant =
        await ref.read(tarifsDaoProvider).calculerMontant(_duree!);
    if (mounted) setState(() => _montant = montant);
  }

  Future<void> _enregistrer() async {
    if (_eleve == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez un élève')),
      );
      return;
    }

    final needsMontant = _statut == StatutCours.effectue;
    if (needsMontant && _montant == null) {
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
      final datePrevue = DateTime(
        _date.year, _date.month, _date.day, _heure.hour, _heure.minute,
      );
      await ref.read(coursDaoProvider).insertCoursExceptionnel(
            CoursCompanion(
              elevesId: Value(_eleve!.elevesId),
              datePrevue: Value(datePrevue),
              statut: Value(_statut.toDb()),
              dureeReelle: _duree != null
                  ? Value(_duree)
                  : const Value.absent(),
              montant: _montant != null
                  ? Value(_montant!)
                  : const Value.absent(),
            ),
            eleve: _eleve!,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        final dejaExistant = e.toString().contains('UNIQUE constraint');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(dejaExistant
                ? 'Un cours existe déjà pour cet élève à ce créneau'
                : 'Erreur lors de l\'enregistrement'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final elevesAsync = ref.watch(elevesActifsProvider);
    final tarifs = ref.watch(tarifsEnCoursProvider).valueOrNull ?? [];

    final tarifCorrespond =
        _duree != null && tarifs.any((t) => t.duree == _duree);
    final showTextField =
        _modeManuel || (tarifs.isNotEmpty && _duree != null && !tarifCorrespond);

    final needsMontant = _statut == StatutCours.effectue;

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
                    color:
                        Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Ajouter un cours',
                style:
                    Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
              ),
              const SizedBox(height: 24),

              // ── Élève ──
              elevesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Erreur'),
                data: (eleves) => DropdownButtonFormField<Eleve?>(
                  initialValue: _eleve,
                  decoration:
                      const InputDecoration(labelText: 'Élève *'),
                  hint: const Text('Sélectionner un élève'),
                  items: eleves
                      .map((e) => DropdownMenuItem<Eleve?>(
                            value: e,
                            child: Text('${e.prenom} ${e.nom}'),
                          ))
                      .toList(),
                  onChanged: (e) => setState(() => _eleve = e),
                ),
              ),
              const SizedBox(height: 16),

              // ── Date ──
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Date'),
                subtitle: Text(
                    '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}'),
                onTap: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (p != null) setState(() => _date = p);
                },
              ),

              // ── Heure ──
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time_outlined),
                title: const Text('Heure'),
                subtitle: Text(
                    '${_heure.hour.toString().padLeft(2, '0')}:${_heure.minute.toString().padLeft(2, '0')}'),
                onTap: () async {
                  final p = await showHeureScrollPicker(
                    context,
                    initialTime: _heure,
                  );
                  if (p != null) setState(() => _heure = p);
                },
              ),
              const SizedBox(height: 8),

              // ── Durée ──
              DropdownButtonFormField<int?>(
                initialValue:
                    tarifCorrespond && !_modeManuel ? _duree : null,
                decoration:
                    const InputDecoration(labelText: 'Durée'),
                hint: const Text('Choisir une durée'),
                items: [
                  ...tarifs.map((t) => DropdownMenuItem<int?>(
                        value: t.duree,
                        child: Text(
                            '${t.duree} min — ${formatCentimes(t.prix)} €'),
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
                      _dureeManuelleCtrl.text = _duree?.toString() ?? '';
                    });
                  }
                },
              ),
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

              // ── Statut ──
              DropdownButtonFormField<StatutCours>(
                initialValue: _statut,
                decoration:
                    const InputDecoration(labelText: 'Statut'),
                items: StatutCours.values
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.label),
                        ))
                    .toList(),
                onChanged: (s) {
                  if (s != null) setState(() => _statut = s);
                },
              ),

              // ── Montant calculé (si effectué) ──
              if (needsMontant) ...[
                const SizedBox(height: 16),
                Text(
                  _montant != null
                      ? 'Montant : ${formatCentimes(_montant!)} €'
                      : 'Aucun tarif défini',
                  style:
                      Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _montant != null
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                ),
              ],
              const SizedBox(height: 24),

              // ── Bouton ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _chargement ? null : _enregistrer,
                  icon: const Icon(Icons.add),
                  label: _chargement
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2),
                        )
                      : const Text('Ajouter le cours'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
