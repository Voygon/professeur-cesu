/// Conversion entre euros (affichage/saisie) et centimes (stockage interne).
/// Les centimes (int) évitent les erreurs d'arrondi flottant sur les montants.
int eurosToCentimes(double euros) => (euros * 100).round();

double centimesToEuros(int centimes) => centimes / 100;

String formatCentimes(int centimes) => centimesToEuros(centimes).toStringAsFixed(2);
