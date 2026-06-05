import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart';
import '../../shared/models/enums.dart';

class CoursTile extends StatelessWidget {
  final Cour cours;
  final Eleve eleve;
  final bool enConflit;
  final int espacement;
  final bool enModeSelection;
  final bool estSelectionne;

  const CoursTile({
    super.key,
    required this.cours,
    required this.eleve,
    this.enConflit = false,
    this.espacement = 15,
    this.enModeSelection = false,
    this.estSelectionne = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final heure = DateFormat('HH:mm').format(cours.datePrevue);
    final duree = cours.dureeReelle ?? 60;
    final statut = StatutCours.fromDb(cours.statut);

    return Card(
      color: estSelectionne ? colorScheme.primaryContainer : null,
      shape: enConflit
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colorScheme.error, width: 2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (enModeSelection) ...[
              Icon(
                estSelectionne
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: estSelectionne
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        eleve.prenom,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      if (enConflit) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.schedule,
                            size: 16, color: colorScheme.error),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('dd/MM/yyyy').format(cours.datePrevue)} · $heure · $duree min',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  if (enConflit)
                    Text(
                      'Moins de $espacement min avec un autre cours',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.error,
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
