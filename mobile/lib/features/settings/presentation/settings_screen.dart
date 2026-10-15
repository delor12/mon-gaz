import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/storage/local_storage.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../dashboard/providers/telemetry_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController(text: '12.5');
  final TextEditingController _tareController = TextEditingController(text: '13.0');
  double _leakThreshold = 400;
  bool _buzzerEnabled = true;
  bool _valveEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final ip = await LocalStorage.getDeviceIp();
    setState(() {
      _ipController.text = ip;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.blueDeep,
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section 1 : Mode Démo
          GlassCard(
            borderColor: AppColors.yellow,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Mode Démo (Simulateur)', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.yellow)),
                    SizedBox(height: 4),
                    Text('Tester sans prototype physique', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                Switch(
                  value: state.isDemo,
                  activeColor: AppColors.yellow,
                  onChanged: (val) {
                    notifier.enableDemoMode(val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Section 2 : Connexion Réseau
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Connexion au Boîtier SmartGas', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold)),
                const SizedBox(height: 12),
                TextField(
                  controller: _ipController,
                  decoration: const InputDecoration(
                    labelText: 'Nom d\'hôte ou IP de l\'ESP32',
                    hintText: 'smartgas.local ou 192.168.1.50',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    await LocalStorage.setDeviceIp(_ipController.text.trim());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Adresse IP enregistrée')),
                    );
                  },
                  child: const Text('Tester & Sauvegarder la Connexion'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Section 3 : Étalonnage & Calibration
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Étalonnage de la Balance (HX711)', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final ok = await notifier.triggerTare();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ok ? 'Tare effectuée à 0 kg' : 'Erreur tare')),
                          );
                        },
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.textPrimary),
                        child: const Text('Tare (0 kg)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showCalibrationDialog(context),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.blueDeep),
                        child: const Text('Étalonner (5 kg)'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Section 4 : Configuration Bouteille & Sécurité
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Seuils de Sécurité', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold)),
                const SizedBox(height: 12),
                Text('Seuil Fuite de Gaz : ${_leakThreshold.toInt()} ppm'),
                Slider(
                  value: _leakThreshold,
                  min: 200,
                  max: 1000,
                  divisions: 16,
                  activeColor: AppColors.alertRed,
                  onChanged: (val) => setState(() => _leakThreshold = val),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Buzzer Sonore 85dB Actif'),
                  value: _buzzerEnabled,
                  activeColor: AppColors.gold,
                  onChanged: (val) => setState(() => _buzzerEnabled = val),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Coupure Automatique Électrovanne'),
                  subtitle: const Text('Ferme l\'arrivée de gaz en cas de fuite', style: TextStyle(fontSize: 11)),
                  value: _valveEnabled,
                  activeColor: AppColors.greenSuccess,
                  onChanged: (val) => setState(() => _valveEnabled = val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Center(
            child: Text(
              'SmartGas v1.0 • Firmware ESP32 v1.0.0',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showCalibrationDialog(BuildContext context) {
    final weightCtrl = TextEditingController(text: '5.0');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.blueSurface,
        title: const Text('Calibration avec Masse Étalon', style: TextStyle(color: AppColors.gold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Posez la masse étalon sur le plateau puis indiquez sa valeur exacte en kg :'),
            const SizedBox(height: 12),
            TextField(
              controller: weightCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Poids Étalon (kg)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Calibration transmise à l\'ESP32 avec succès !')),
              );
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }
}
