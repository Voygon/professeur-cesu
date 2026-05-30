class RecapMois {
  final int nbCoursValides;
  final int nbCoursPayes;
  final double montantTotal;
  final double montantPaye;
  final double montantRestant;
  final int mois;
  final int annee;

  const RecapMois({
    required this.nbCoursValides,
    required this.nbCoursPayes,
    required this.montantTotal,
    required this.montantPaye,
    required this.montantRestant,
    required this.mois,
    required this.annee,
  });
}
