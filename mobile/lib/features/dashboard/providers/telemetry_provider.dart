import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/network/websocket_client.dart';
import '../../core/storage/local_storage.dart';
import '../../shared/models/telemetry.dart';
import '../demo/demo_service.dart';
import '../prediction/prediction_engine.dart';

class DashboardState {
  final Telemetry telemetry;
  final bool isConnected;
  final bool isDemo;
  final DemoScenario demoScenario;
  final List<HistoryPoint> history;
  final PredictionResult? prediction;
  final String connectionType; // "LOCAL_WS", "CLOUD_MQTT", "DEMO"

  const DashboardState({
    required this.telemetry,
    this.isConnected = false,
    this.isDemo = false,
    this.demoScenario = DemoScenario.nominal,
    this.history = const [],
    this.prediction,
    this.connectionType = "LOCAL_WS",
  });

  DashboardState copyWith({
    Telemetry? telemetry,
    bool? isConnected,
    bool? isDemo,
    DemoScenario? demoScenario,
    List<HistoryPoint>? history,
    PredictionResult? prediction,
    String? connectionType,
  }) {
    return DashboardState(
      telemetry: telemetry ?? this.telemetry,
      isConnected: isConnected ?? this.isConnected,
      isDemo: isDemo ?? this.isDemo,
      demoScenario: demoScenario ?? this.demoScenario,
      history: history ?? this.history,
      prediction: prediction ?? this.prediction,
      connectionType: connectionType ?? this.connectionType,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final ApiClient _apiClient = ApiClient();
  final WebSocketClient _wsClient = WebSocketClient();
  StreamSubscription? _telSub;
  StreamSubscription? _connSub;
  StreamSubscription? _demoSub;

  DashboardNotifier()
      : super(DashboardState(
          telemetry: Telemetry(
            deviceId: 'ESP32-SMARTGAS-8A4F',
            weightKg: 8.42,
            grossWeightKg: 21.42,
            levelPercent: 67.36,
            gasPpm: 145,
            leak: false,
            temperatureC: 21.8,
            humidityPercent: 48.5,
            valveState: 'OPEN',
            buzzerMuted: false,
            sensorFault: false,
            rssi: -60,
            uptimeS: 0,
            timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        )) {
    _init();
  }

  void _init() async {
    final demo = await LocalStorage.isDemoMode();
    if (demo) {
      enableDemoMode(true);
    } else {
      _connectLive();
    }
  }

  void _connectLive() {
    _demoSub?.cancel();
    DemoService.stop();

    _wsClient.connect();

    _connSub = _wsClient.isConnectedStream.listen((connected) {
      state = state.copyWith(
        isConnected: connected,
        connectionType: connected ? "LOCAL_WS" : "HORS LIGNE",
      );
    });

    _telSub = _wsClient.telemetryStream.listen((tel) {
      _updateTelemetry(tel);
    });

    _loadHistory();
  }

  void _updateTelemetry(Telemetry tel) {
    final pred = PredictionEngine.compute(
      currentWeightKg: tel.weightKg,
      capacityKg: 12.5,
      history: state.history,
    );
    state = state.copyWith(telemetry: tel, prediction: pred);
  }

  Future<void> _loadHistory() async {
    try {
      final h = await _apiClient.fetchHistory(range: 'day', resolution: 'hour');
      state = state.copyWith(history: h);
    } catch (e) {
      // Historical fallback
    }
  }

  void enableDemoMode(bool enabled) async {
    await LocalStorage.setDemoMode(enabled);
    if (enabled) {
      _wsClient.disconnect();
      _telSub?.cancel();
      _connSub?.cancel();

      DemoService.start();
      _demoSub = DemoService.stream.listen((tel) {
        _updateTelemetry(tel);
      });

      state = state.copyWith(
        isDemo: true,
        isConnected: true,
        connectionType: "MODE DEMO",
      );
    } else {
      state = state.copyWith(isDemo: false);
      _connectLive();
    }
  }

  void setDemoScenario(DemoScenario scenario) {
    if (!state.isDemo) return;
    DemoService.setScenario(scenario);
    state = state.copyWith(demoScenario: scenario);
  }

  Future<bool> toggleValve() async {
    final newAction = (state.telemetry.valveState == 'OPEN') ? 'CLOSE' : 'OPEN';
    if (state.isDemo) {
      final updated = state.telemetry.copyWith(valveState: (newAction == 'OPEN') ? 'OPEN' : 'CLOSED');
      state = state.copyWith(telemetry: updated);
      return true;
    }

    try {
      final res = await _apiClient.controlValve(newAction);
      final updated = state.telemetry.copyWith(valveState: res);
      state = state.copyWith(telemetry: updated);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> muteAlarm() async {
    if (state.isDemo) return true;
    try {
      return await _apiClient.muteAlarm(durationSeconds: 120);
    } catch (e) {
      return false;
    }
  }

  Future<bool> triggerTare() async {
    if (state.isDemo) return true;
    try {
      return await _apiClient.tare();
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _wsClient.dispose();
    _telSub?.cancel();
    _connSub?.cancel();
    _demoSub?.cancel();
    super.dispose();
  }
}

final dashboardProvider = StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier();
});
