import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dashboard/screens/dashboard_screen.dart';
import '../dashboard/screens/valider_cours_sheet.dart';
import '../eleves/screens/eleves_screen.dart';
import '../paiements/screens/paiements_screen.dart';
import '../parametres/screens/parametres_screen.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/database/database_provider.dart';
import '../../core/supabase/auth_supabase_service.dart';
import '../../core/supabase/sync_service.dart';
import '../parametres/providers/parametres_provider.dart';

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _selectedIndex = 0;
  StreamSubscription<int>? _tapSub;
  StreamSubscription<int>? _validerSub;

  static const List<Widget> _screens = [
    DashboardScreen(),
    ElevesScreen(),
    PaiementsScreen(),
    ParametresScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _tapSub = NotificationService.tapStream.listen(_ouvrirCours);
    _validerSub = NotificationService.validerStream.listen(_validerCours);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService.checkLaunchNotification();

      // Sync au démarrage si l'utilisateur est connecté à Supabase
      if (AuthSupabaseService.isConnected) {
        final dejaProposee = await SyncService.restaurationDejaProposee();
        final premiereSync = await SyncService.getDerniereSync() == null;

        // Premier lancement avec un compte connecté → propose de récupérer
        // les données existantes dans le cloud avant toute autre opération.
        if (!dejaProposee && premiereSync) {
          await SyncService.marquerRestaurationProposee();
          if (!mounted) return;
          final restaurer = await _demanderRestaurationCloud();
          if (restaurer != true) return;
        }

        try {
          await SyncService.synchroniser(
            ref.read(databaseProvider),
            ref.read(elevesDaoProvider),
            ref.read(payeursDaoProvider),
          );
        } catch (_) {
          // Erreur réseau au démarrage → on ignore silencieusement
        }
      }

      // Purge auto des cours annulés selon le délai configuré
      final delaiPurge = ref.read(purgeAnnulesProvider);
      if (delaiPurge != null) {
        if (delaiPurge == 0) {
          await ref.read(coursDaoProvider).purgerTousCoursAnnules();
        } else {
          await ref.read(coursDaoProvider).purgerCoursAnnulesAnciens(delaiPurge);
        }
      }
    });
  }

  @override
  void dispose() {
    _tapSub?.cancel();
    _validerSub?.cancel();
    super.dispose();
  }

  // Premier lancement avec un compte Supabase connecté : demande si les
  // données déjà présentes en ligne doivent être récupérées en local.
  Future<bool?> _demanderRestaurationCloud() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Récupérer les données ?'),
        content: const Text(
          'Un compte connecté à la synchronisation a été détecté. '
          'Voulez-vous récupérer les données déjà enregistrées en ligne '
          'et les enregistrer sur cet appareil ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Récupérer'),
          ),
        ],
      ),
    );
  }

  // Tap sur le corps de la notification → ouvre la fiche du cours
  Future<void> _ouvrirCours(int coursId) async {
    final cour = await ref.read(coursDaoProvider).getCours(coursId);
    if (cour == null || !mounted) return;
    final eleve = await ref.read(elevesDaoProvider).getEleve(cour.elevesId);
    if (eleve == null || !mounted) return;
    setState(() => _selectedIndex = 0);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ValiderCoursSheet(cours: cour, eleve: eleve),
    );
  }

  // Tap sur le bouton "Valider" → valide directement, sans ouvrir de fiche
  Future<void> _validerCours(int coursId) async {
    final cour = await ref.read(coursDaoProvider).getCours(coursId);
    if (cour == null || !mounted) return;
    final eleve = await ref.read(elevesDaoProvider).getEleve(cour.elevesId);
    if (eleve == null || !mounted) return;

    final montant = await ref
        .read(tarifsDaoProvider)
        .calculerMontant(cour.dureeReelle ?? eleve.dureeCours ?? 60);

    if (montant == null) {
      // Pas de tarif → ouvre la fiche pour saisie manuelle du montant
      await _ouvrirCours(coursId);
      return;
    }

    await ref
        .read(coursDaoProvider)
        .validerCours(coursId, montant: montant, eleve: eleve);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cours validé — ${eleve.prenom} ${eleve.nom}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Planning',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'Élèves',
          ),
          NavigationDestination(
            icon: Icon(Icons.euro_outlined),
            selectedIcon: Icon(Icons.euro),
            label: 'Paiements',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }
}
