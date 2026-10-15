import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../dashboard/providers/telemetry_provider.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _selectedTab = 0; // 0: Jour, 1: Semaine, 2: Mois

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final history = state.history;

    return Scaffold(
      backgroundColor: AppColors.blueDeep,
      appBar: AppBar(
        title: const Text('Historique & Analyse'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sélecteur de période
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('24 Heures')),
                ButtonSegment(value: 1, label: Text('7 Jours')),
                ButtonSegment(value: 2, label: Text('30 Jours')),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (val) {
                setState(() => _selectedTab = val.first);
              },
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
                    return AppColors.gold;
                  }
                  return AppColors.blueSurface;
                }),
                foregroundColor: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
                    return AppColors.blueDeep;
                  }
                  return AppColors.textPrimary;
                }),
              ),
            ),

            const SizedBox(height: 16),

            // Graphique de consommation
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Évolution de la masse restante (kg)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 220,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (val) => FlLine(
                            color: Colors.white12,
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 34,
                              getTitlesWidget: (val, meta) => Text(
                                '${val.toInt()}k',
                                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              getTitlesWidget: (val, meta) => Text(
                                '${val.toInt()}h',
                                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                              ),
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: 24,
                        minY: 0,
                        maxY: 15,
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              const FlSpot(0, 11.2),
                              const FlSpot(4, 11.2),
                              const FlSpot(8, 11.0),
                              const FlSpot(12, 10.6),
                              const FlSpot(16, 10.5),
                              const FlSpot(20, 9.8),
                              const FlSpot(24, 8.42),
                            ],
                            isCurved: true,
                            color: AppColors.gold,
                            barWidth: 3,
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.gold.withOpacity(0.35),
                                  AppColors.gold.withOpacity(0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Métriques financières et d'optimisation
            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Conso Moyenne', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        SizedBox(height: 6),
                        Text('340 g / jour', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Coût Estimé', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        SizedBox(height: 6),
                        Text('0.87 € / jour', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.yellow)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Conseil d'optimisation énergétique
            GlassCard(
              borderColor: AppColors.blueLight.withOpacity(0.5),
              child: Row(
                children: const [
                  Icon(Icons.lightbulb_outline, color: AppColors.yellow, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Astuce : Couvrez vos casseroles pendant la cuisson pour économiser jusqu\'à 25% de gaz GPL.',
                      style: TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Bouton Export
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Historique exporté au format CSV (téléchargement terminé).')),
                );
              },
              icon: const Icon(Icons.download),
              label: const Text('Exporter les Données en CSV'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.gold,
                side: const BorderSide(color: AppColors.gold),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
