import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/glass_card.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({Key? key}) : super(key: key);

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  void _submitPairing() async {
    final pin = _pinController.text.trim();
    if (pin.length != 6) {
      setState(() => _errorMessage = 'Le code PIN doit comporter 6 chiffres.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = ApiClient();
      await client.pairDevice(pin);
      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Échec de l\'appairage : Code PIN invalide ou session expirée.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blueDeep,
      appBar: AppBar(
        title: const Text('Appairage SmartGas'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Center(
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 70,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Entrez le Code PIN',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.gold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Consultez l\'écran TFT physique de votre boîtier SmartGas et recopiez le code à 6 chiffres affiché.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),

              GlassCard(
                child: TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 12.0,
                    color: AppColors.yellow,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '------',
                    border: InputBorder.none,
                  ),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.alertRed, fontSize: 13),
                ),
              ],

              const Spacer(),

              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: AppColors.gold))
              else
                ElevatedButton(
                  onPressed: _submitPairing,
                  child: const Text('Valider l\'Appairage'),
                ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () {
                  // Contournement pour le mode démo ou test
                  context.go('/dashboard');
                },
                child: const Text(
                  'Continuer en mode démonstration sans boîtier',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
