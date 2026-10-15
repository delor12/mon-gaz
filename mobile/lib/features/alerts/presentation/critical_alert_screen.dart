import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';
import '../../../core/constants/app_colors.dart';
import '../../dashboard/providers/telemetry_provider.dart';

class CriticalAlertScreen extends ConsumerStatefulWidget {
  const CriticalAlertScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CriticalAlertScreen> createState() => _CriticalAlertScreenState();
}

class _CriticalAlertScreenState extends ConsumerState<CriticalAlertScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _triggerVibration();
  }

  void _triggerVibration() async {
    final hasVib = await Vibration.hasVibrator();
    if (hasVib ?? false) {
      Vibration.vibrate(pattern: [500, 200, 500, 200], repeat: 0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    Vibration.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final tel = state.telemetry;

    return Scaffold(
      backgroundColor: AppColors.alertRedDeep,
      body: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          final flashColor = Color.lerp(
            AppColors.alertRedDeep,
            AppColors.alertRed,
            _animController.value,
          )!;

          return Container(
            color: flashColor,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 90,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'DANGER !',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const Text(
                      'FUITE DE GAZ GPL DÉTECTÉE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.yellow,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Concentration : ${tel.gasPpm} ppm (Seuil : 400 ppm)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Consignes de sécurité vitales
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: ListView(
                          children: const [
                            Text(
                              'CONSIGNES DE SÉCURITÉ IMMÉDIATES :',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 16),
                            _SafetyStep(
                              number: '1',
                              text: 'Ne touchez à AUCUN interrupteur, téléphone, ni appareil électrique.',
                            ),
                            _SafetyStep(
                              number: '2',
                              text: 'Éteignez immédiatement toute flamme vive ou braise.',
                            ),
                            _SafetyStep(
                              number: '3',
                              text: 'Fermez le robinet d\'arrivée de la bouteille de gaz.',
                            ),
                            _SafetyStep(
                              number: '4',
                              text: 'Ouvrez grandement portes et fenêtres pour aérer.',
                            ),
                            _SafetyStep(
                              number: '5',
                              text: 'Si l\'odeur persiste, évacuez les lieux et appelez les pompiers (18 ou 112).',
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Bouton Sourdine Buzzer
                    ElevatedButton.icon(
                      onPressed: () async {
                        await ref.read(dashboardProvider.notifier).muteAlarm();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Buzzer local mis en sourdine pendant 2 min.')),
                        );
                      },
                      icon: const Icon(Icons.volume_off),
                      label: const Text('Mettre le Buzzer en Sourdine (120 s)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.yellow,
                        foregroundColor: AppColors.blueDeep,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Bouton Coupure Vanne
                    OutlinedButton.icon(
                      onPressed: () async {
                        await ref.read(dashboardProvider.notifier).toggleValve();
                      },
                      icon: const Icon(Icons.power_settings_new),
                      label: Text(
                        (tel.valveState == 'OPEN') ? 'Fermer Électrovanne d\'Urgence' : 'Électrovanne Déjà Coupée',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Fermer cet avertissement',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SafetyStep extends StatelessWidget {
  final String number;
  final String text;

  const _SafetyStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.yellow,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: AppColors.blueDeep,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
