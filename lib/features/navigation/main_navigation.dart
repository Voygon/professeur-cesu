import 'package:flutter/material.dart';
import '../dashboard/screens/dashboard_screen.dart';
import '../eleves/screens/eleves_screen.dart';
import '../parametres/screens/parametres_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  // Index de l'onglet actif — 0 = Dashboard par défaut
  int _selectedIndex = 0;

  // Liste des 4 écrans dans le bon ordre
  static const List<Widget> _screens = [
    DashboardScreen(),
    ElevesScreen(),
    _PaiementsScreen(),
    ParametresScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Affiche l'écran correspondant à l'onglet actif
      body: _screens[_selectedIndex],

      bottomNavigationBar: NavigationBar(
        // Onglet actuellement sélectionné
        selectedIndex: _selectedIndex,

        // Appelé quand l'utilisateur clique sur un onglet
        // setState() demande à Flutter de reconstruire le widget
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },

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

class _PaiementsScreen extends StatelessWidget {
  const _PaiementsScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Paiements')),
    );
  }
}
