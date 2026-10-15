class DeviceConfig {
  final String bottleType;
  final String bottleName;
  final double capacityKg;
  final double tareWeightKg;
  final int leakThresholdPpm;
  final double lowLevelThresholdPercent;
  final double criticalLevelThresholdPercent;
  final bool buzzerEnabled;
  final bool valveEnabled;
  final bool valveAutoCutoff;

  const DeviceConfig({
    this.bottleType = 'B12_5',
    this.bottleName = 'Cuisine Principale',
    this.capacityKg = 12.5,
    this.tareWeightKg = 13.0,
    this.leakThresholdPpm = 400,
    this.lowLevelThresholdPercent = 15.0,
    this.criticalLevelThresholdPercent = 5.0,
    this.buzzerEnabled = true,
    this.valveEnabled = false,
    this.valveAutoCutoff = true,
  });

  factory DeviceConfig.fromJson(Map<String, dynamic> json) {
    return DeviceConfig(
      bottleType: json['bottle_type'] ?? 'B12_5',
      bottleName: json['bottle_name'] ?? 'Cuisine Principale',
      capacityKg: (json['capacity_kg'] as num?)?.toDouble() ?? 12.5,
      tareWeightKg: (json['tare_weight_kg'] as num?)?.toDouble() ?? 13.0,
      leakThresholdPpm: json['leak_threshold_ppm'] ?? 400,
      lowLevelThresholdPercent: (json['low_level_threshold_percent'] as num?)?.toDouble() ?? 15.0,
      criticalLevelThresholdPercent: (json['critical_level_threshold_percent'] as num?)?.toDouble() ?? 5.0,
      buzzerEnabled: json['buzzer_enabled'] ?? true,
      valveEnabled: json['valve_enabled'] ?? false,
      valveAutoCutoff: json['valve_auto_cutoff'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bottle_type': bottleType,
      'bottle_name': bottleName,
      'capacity_kg': capacityKg,
      'tare_weight_kg': tareWeightKg,
      'leak_threshold_ppm': leakThresholdPpm,
      'low_level_threshold_percent': lowLevelThresholdPercent,
      'critical_level_threshold_percent': criticalLevelThresholdPercent,
      'buzzer_enabled': buzzerEnabled,
      'valve_enabled': valveEnabled,
      'valve_auto_cutoff': valveAutoCutoff,
    };
  }
}
