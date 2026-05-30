import '../../core/database/app_database.dart';

class EleveAvecPayeur {
  final Eleve eleve;
  final Payeur payeur;

  const EleveAvecPayeur({
    required this.eleve,
    required this.payeur,
  });
}
