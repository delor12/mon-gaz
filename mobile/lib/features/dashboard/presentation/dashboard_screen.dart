import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/circular_gauge.dart';
import '../../../shared/widgets/glass_card.dart';
import '../providers/telemetry_provider.dart';
import '../../demo/demo_service.dart';
import '../../alerts/presentation/critical_alert_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);
    final tel = state.telemetry;
    final pred = state.prediction;

    // Déclenchement automatique de l'écran critique si fuite de gaz
    ref.listen<DashboardState>(dashboardProvider, (prev, next) {
      if (next.telemetry.leak && !(prev?.telemetry.leak ?? false)) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CriticalAlertScreen()),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.blueDeep,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('🔥 ', style: TextStyle(fontSize: 20)),
            Text('SMART GAS'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart, color: AppColors.gold),
            tooltip: 'Historique & Analyses',
            onPressed: () => context.push('/analytics'),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.gold),
            tooltip: 'Paramètres',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Rafraîchissement manuel
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Pilule de statut de connexion
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: state.isConnected
                        ? AppColors.greenSuccess.withOpacity(0.15)
                        : AppColors.alertRed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: state.isConnected ? AppColors.greenSuccess : AppColors.alertRed,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: state.isConnected ? AppColors.greenSuccess : AppColors.alertRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        state.connectionType,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: state.isConnected ? AppColors.greenSuccess : AppColors.alertRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 2. Bannière d'alerte critique si fuite
              if (tel.leak)
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CriticalAlertScreen()),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.alertRed.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.alertRed, width: 2),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.warning, color: AppColors.alertRed, size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'FUITE DE GAZ DÉTECTÉE ! Appuyez ici pour afficher les consignes d\'urgence.',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, color: AppColors.alertRed, size: 16),
                      ],
                    ),
                  ),
                ),

              // 3. Jauge Principale Circulaire
              GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Column(
                  children: [
                    CircularGauge(
                      percent: tel.levelPercent,
                      weightKg: tel.weightKg,
                      size: 220,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Bouteille 12.5 kg • Cuisine Principale',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 4. Grille de Métriques Temps Réel (4 cases)
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Poids Brut',
                      value: '${tel.grossWeightKg.toStringAsFixed(2)} kg',
                      icon: Icons.scale,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      label: 'Gaz GPL',
                      value: '${tel.gasPpm} ppm',
                      icon: Icons.air,
                      valueColor: tel.leak ? AppColors.alertRed : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Température',
                      value: '${tel.temperatureC.toStringAsFixed(1)} °C',
                      icon: Icons.thermostat,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      label: 'Électrovanne',
                      value: (tel.valveState == 'OPEN') ? 'OUVERTE' : 'FERMÉE',
                      icon: Icons.security,
                      valueColor: (tel.valveState == 'OPEN') ? AppColors.greenSuccess : AppColors.alertRed,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 5. Carte Prédiction IA
              GlassCard(
                borderColor: AppColors.gold.withOpacity(0.4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.auto_awesome, color: AppColors.gold, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Estimation Prédictive d\'Autonomie (IA)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          pred?.displayStr ?? 'Calcul en cours...',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.blueSurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Fin: ${pred?.estimatedEmptyDate ?? '--/--'}',
                            style: const TextStyle(fontSize: 12, color: AppColors.yellow),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pred?.recommendation ?? 'Analyse des données en cours.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 6. Actions Rapides
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final ok = await notifier.triggerTare();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'Tare effectuée' : 'Échec de la tare')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.borderGold),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Tare (0 kg)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await notifier.toggleValve();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (tel.valveState == 'OPEN') ? AppColors.blueLight : AppColors.greenSuccess,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text((tel.valveState == 'OPEN') ? 'Fermer Vanne' : 'Ouvrir Vanne'),
                    ),
                  ),
                ],
              ),

              // Sélecteur Scénario Démo si actif
              if (state.isDemo) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.blueSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.yellow),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🎮 Scénarios du Mode Démo :',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.yellow, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Nominal'),
                            selected: state.demoScenario == DemoScenario.nominal,
                            onSelected: (_) => notifier.setDemoScenario(DemoScenario.nominal),
                          ),
                          ChoiceChip(
                            label: const Text('🚨 Fuite'),
                            selected: state.demoScenario == DemoScenario.gasLeak,
                            onSelected: (_) => notifier.setDemoScenario(DemoScenario.gasLeak),
                          ),
                          ChoiceChip(
                            label: const Text('Niveau Bas'),
                            selected: state.demoScenario == DemoScenario.lowLevel,
                            onSelected: (_) => notifier.setDemoScenario(DemoScenario.lowLevel),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Column(
        children: [
          Icon(icon, color: AppColors.gold, size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
