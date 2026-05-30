import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart';
import '../../shared/models/enums.dart';

class CoursTile extends StatelessWidget {
  final Cour cours;
  final Eleve eleve;

  const CoursTile({
    super.key,
    required this.cours,
    required this.eleve,
  });

  @override
  Widget build(BuildContext context) {
    final heure = DateFormat('HH:mm').format(cours.datePrevue);
    final duree = cours.dureeReelle ?? 60;
    final statut = StatutCours.fromDb(cours.statut);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eleve.prenom,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    '$heure · $duree min',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statut.couleurFond,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statut.label,
                style: TextStyle(
                  color: statut.couleur,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
