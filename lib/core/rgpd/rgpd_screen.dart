import 'package:flutter/material.dart';
import 'rgpd_service.dart';

class RgpdScreen extends StatelessWidget {
  final VoidCallback onAccepte;

  const RgpdScreen({super.key, required this.onAccepte});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const Icon(Icons.shield_outlined,
                  size: 48, color: Color(0xFF1565C0)),
              const SizedBox(height: 16),
              Text(
                'Vos données sont protégées',
                style:
                    Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Cette application collecte et stocke les données suivantes :',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _point(
                  'Informations des élèves (prénom, nom, adresse, téléphone)'),
              _point(
                  'Informations des payeurs (prénom, nom, adresse, téléphone)'),
              _point('Historique des cours et paiements'),
              const SizedBox(height: 24),
              const Text(
                'Ces données sont :',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _point('Stockées sur votre appareil et chiffrées avec AES-256'),
              _point(
                  'Synchronisées dans le cloud uniquement si vous créez un compte (optionnel)'),
              _point('Jamais partagées avec des tiers'),
              _point('Supprimables à tout moment'),
              const SizedBox(height: 24),
              Text(
                'Conformément au RGPD, vous avez le droit d\'accès, '
                'de rectification et de suppression de vos données.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await RgpdService.accepterConsentement();
                    onAccepte();
                  },
                  child: const Text('J\'accepte et je continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _point(String texte) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(texte)),
        ],
      ),
    );
  }
}
