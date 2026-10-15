import 'dart:async';
import '../../shared/models/telemetry.dart';

enum DemoScenario {
  nominal,
  gasLeak,
  lowLevel,
  criticalEmpty
}

class DemoService {
  static final StreamController<Telemetry> _controller = StreamController<Telemetry>.broadcast();
  static Timer? _timer;
  static DemoScenario currentScenario = DemoScenario.nominal;
  static double _simulatedWeight = 8.42;

  static Stream<Telemetry> get stream => _controller.stream;

  static void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      _controller.add(_getTelemetryForScenario(currentScenario));
    });
  }

  static void stop() {
    _timer?.cancel();
  }

  static void setScenario(DemoScenario scenario) {
    currentScenario = scenario;
    _controller.add(_getTelemetryForScenario(scenario));
  }

  static Telemetry _getTelemetryForScenario(DemoScenario scenario) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    switch (scenario) {
      case DemoScenario.gasLeak:
        return Telemetry(
          deviceId: 'DEMO-SMARTGAS-SIM',
          weightKg: 8.10,
          grossWeightKg: 21.10,
          levelPercent: 64.8,
          gasPpm: 850,
          leak: true,
          temperatureC: 22.4,
          humidityPercent: 49.0,
          valveState: 'CLOSED',
          buzzerMuted: false,
          sensorFault: false,
          rssi: -55,
          uptimeS: 3600,
          timestamp: now,
        );
      case DemoScenario.lowLevel:
        return Telemetry(
          deviceId: 'DEMO-SMARTGAS-SIM',
          weightKg: 1.50,
          grossWeightKg: 14.50,
          levelPercent: 12.0,
          gasPpm: 120,
          leak: false,
          temperatureC: 21.0,
          humidityPercent: 52.0,
          valveState: 'OPEN',
          buzzerMuted: false,
          sensorFault: false,
          rssi: -60,
          uptimeS: 7200,
          timestamp: now,
        );
      case DemoScenario.criticalEmpty:
        return Telemetry(
          deviceId: 'DEMO-SMARTGAS-SIM',
          weightKg: 0.35,
          grossWeightKg: 13.35,
          levelPercent: 2.8,
          gasPpm: 110,
          leak: false,
          temperatureC: 20.5,
          humidityPercent: 51.0,
          valveState: 'OPEN',
          buzzerMuted: false,
          sensorFault: false,
          rssi: -62,
          uptimeS: 10800,
          timestamp: now,
        );
      case DemoScenario.nominal:
      default:
        // Décroissance lente naturelle
        _simulatedWeight = (_simulatedWeight > 0.5) ? (_simulatedWeight - 0.0001) : 8.42;
        return Telemetry(
          deviceId: 'DEMO-SMARTGAS-SIM',
          weightKg: _simulatedWeight,
          grossWeightKg: _simulatedWeight + 13.0,
          levelPercent: (_simulatedWeight / 12.5) * 100.0,
          gasPpm: 145,
          leak: false,
          temperatureC: 21.8,
          humidityPercent: 48.5,
          valveState: 'OPEN',
          buzzerMuted: false,
          sensorFault: false,
          rssi: -58,
          uptimeS: 86420,
          timestamp: now,
        );
    }
  }
}
