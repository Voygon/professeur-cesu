class MoisInfo {
  final DateTime mois;
  final int nbCours;
  final double montantTotal;
  final double montantPaye;

  const MoisInfo({
    required this.mois,
    required this.nbCours,
    required this.montantTotal,
    required this.montantPaye,
  });

  bool get toutPaye => nbCours > 0 && montantPaye >= montantTotal;
  double get montantRestant => montantTotal - montantPaye;
}
