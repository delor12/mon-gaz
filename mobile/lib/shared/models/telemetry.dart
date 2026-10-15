class Telemetry {
  final String deviceId;
  final double weightKg;
  final double grossWeightKg;
  final double levelPercent;
  final int gasPpm;
  final bool leak;
  final double temperatureC;
  final double humidityPercent;
  final String valveState;
  final bool buzzerMuted;
  final bool sensorFault;
  final int rssi;
  final int uptimeS;
  final int timestamp;

  const Telemetry({
    required this.deviceId,
    required this.weightKg,
    required this.grossWeightKg,
    required this.levelPercent,
    required this.gasPpm,
    required this.leak,
    required this.temperatureC,
    required this.humidityPercent,
    required this.valveState,
    required this.buzzerMuted,
    required this.sensorFault,
    required this.rssi,
    required this.uptimeS,
    required this.timestamp,
  });

  factory Telemetry.fromJson(Map<String, dynamic> json) {
    return Telemetry(
      deviceId: json['device_id'] ?? 'ESP32-SMARTGAS-8A4F',
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0.0,
      grossWeightKg: (json['gross_weight_kg'] as num?)?.toDouble() ?? 0.0,
      levelPercent: (json['level_percent'] as num?)?.toDouble() ?? 0.0,
      gasPpm: json['gas_ppm'] ?? 0,
      leak: json['leak'] ?? false,
      temperatureC: (json['temperature_c'] as num?)?.toDouble() ?? 20.0,
      humidityPercent: (json['humidity_percent'] as num?)?.toDouble() ?? 50.0,
      valveState: json['valve_state'] ?? 'OPEN',
      buzzerMuted: json['buzzer_muted'] ?? false,
      sensorFault: json['sensor_fault'] ?? false,
      rssi: json['rssi'] ?? -60,
      uptimeS: json['uptime_s'] ?? 0,
      timestamp: json['timestamp'] ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'weight_kg': weightKg,
      'gross_weight_kg': grossWeightKg,
      'level_percent': levelPercent,
      'gas_ppm': gasPpm,
      'leak': leak,
      'temperature_c': temperatureC,
      'humidity_percent': humidityPercent,
      'valve_state': valveState,
      'buzzer_muted': buzzerMuted,
      'sensor_fault': sensorFault,
      'rssi': rssi,
      'uptime_s': uptimeS,
      'timestamp': timestamp,
    };
  }

  Telemetry copyWith({
    double? weightKg,
    double? grossWeightKg,
    double? levelPercent,
    int? gasPpm,
    bool? leak,
    String? valveState,
  }) {
    return Telemetry(
      deviceId: deviceId,
      weightKg: weightKg ?? this.weightKg,
      grossWeightKg: grossWeightKg ?? this.grossWeightKg,
      levelPercent: levelPercent ?? this.levelPercent,
      gasPpm: gasPpm ?? this.gasPpm,
      leak: leak ?? this.leak,
      temperatureC: temperatureC,
      humidityPercent: humidityPercent,
      valveState: valveState ?? this.valveState,
      buzzerMuted: buzzerMuted,
      sensorFault: sensorFault,
      rssi: rssi,
      uptimeS: uptimeS,
      timestamp: timestamp,
    );
  }
}

class HistoryPoint {
  final int timestamp;
  final double weightKg;
  final double consumptionKg;

  const HistoryPoint({
    required this.timestamp,
    required this.weightKg,
    required this.consumptionKg,
  });

  factory HistoryPoint.fromJson(Map<String, dynamic> json) {
    return HistoryPoint(
      timestamp: json['timestamp'] ?? 0,
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0.0,
      consumptionKg: (json['consumption_kg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
