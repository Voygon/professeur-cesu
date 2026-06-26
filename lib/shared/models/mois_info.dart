class MoisInfo {
  final DateTime mois;
  final int nbCours;
  // Montants en centimes.
  final int montantTotal;
  final int montantPaye;

  const MoisInfo({
    required this.mois,
    required this.nbCours,
    required this.montantTotal,
    required this.montantPaye,
  });

  bool get toutPaye => nbCours > 0 && montantPaye >= montantTotal;
  int get montantRestant => montantTotal - montantPaye;
}
