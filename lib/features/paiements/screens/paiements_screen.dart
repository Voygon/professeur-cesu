import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/paiements_provider.dart';
import '../models/mois_info.dart';
import 'detail_mois_screen.dart';
import 'vue_par_eleve_screen.dart';

String _nomMois(DateTime date) {
  const noms = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];
  return '${noms[date.month - 1]} ${date.year}';
}

class PaiementsScreen extends ConsumerStatefulWidget {
  const PaiementsScreen({super.key});

  @override
  ConsumerState<PaiementsScreen> createState() => _PaiementsScreenState();
}

class _PaiementsScreenState extends ConsumerState<PaiementsScreen> {
  bool _vueParEleve = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_vueParEleve ? 'Par élève' : 'Paiements'),
        actions: [
          IconButton(
            tooltip:
                _vueParEleve ? 'Vue par mois' : 'Vue par élève',
            icon: Icon(
              _vueParEleve
                  ? Icons.calendar_month_outlined
                  : Icons.person_outlined,
            ),
            onPressed: () =>
                setState(() => _vueParEleve = !_vueParEleve),
          ),
        ],
      ),
      body: IndexedStack(
        index: _vueParEleve ? 1 : 0,
        children: const [
          _VueParMois(),
          VueParEleveScreen(),
        ],
      ),
    );
  }
}

// ── Vue 1 : liste des mois ──────────────────────────────────────────────────

class _VueParMois extends ConsumerWidget {
  const _VueParMois();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moisAsync = ref.watch(moisAvecCoursProvider);

    return moisAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) =>
          const Center(child: Text('Erreur de chargement')),
      data: (liste) => liste.isEmpty
          ? const Center(
              child: Text('Aucun cours validé pour le moment'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: liste.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _MoisTile(info: liste[i]),
            ),
    );
  }
}

class _MoisTile extends StatelessWidget {
  final MoisInfo info;
  const _MoisTile({required this.info});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: info.toutPaye ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(_nomMois(info.mois)),
        subtitle: info.toutPaye
            ? Text(
                '${info.nbCours} cours · ${info.montantTotal.toStringAsFixed(2)} € · Payé',
              )
            : Text(
                '${info.nbCours} cours · ${info.montantRestant.toStringAsFixed(2)} € restant',
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DetailMoisScreen(
            mois: info.mois.month,
            annee: info.mois.year,
          ),
        )),
      ),
    );
  }
}
