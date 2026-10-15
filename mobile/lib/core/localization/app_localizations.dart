class AppLocalizations {
  final String locale;

  AppLocalizations(this.locale);

  static const Map<String, Map<String, String>> _localizedValues = {
    'fr': {
      'app_title': 'SMART GAS',
      'app_subtitle': 'Moniteur Intelligent GPL',
      'gas_remaining': 'Gaz restant',
      'bottle_sub': 'Bouteille 12.5 kg • Cuisine Principale',
      'gross_weight': 'Poids Brut',
      'gas_ppm': 'Gaz GPL',
      'temperature': 'Température',
      'valve': 'Électrovanne',
      'valve_open': 'OUVERTE',
      'valve_closed': 'FERMÉE',
      'prediction_title': "Estimation Prédictive d'Autonomie (IA)",
      'danger_title': 'DANGER !',
      'leak_detected': 'FUITE DE GAZ GPL DÉTECTÉE',
      'mute_buzzer': 'Mettre le Buzzer en Sourdine (120 s)',
      'close_valve_emergency': "Fermer Électrovanne d'Urgence",
      'tare': 'Tare (0 kg)',
      'calibrate': 'Étalonner (5 kg)',
      'demo_mode': 'Mode Démo (Simulateur)',
    },
    'en': {
      'app_title': 'SMART GAS',
      'app_subtitle': 'Intelligent LPG Monitor',
      'gas_remaining': 'Remaining Gas',
      'bottle_sub': '12.5 kg Cylinder • Main Kitchen',
      'gross_weight': 'Gross Weight',
      'gas_ppm': 'LPG Gas',
      'temperature': 'Temperature',
      'valve': 'Solenoid Valve',
      'valve_open': 'OPEN',
      'valve_closed': 'CLOSED',
      'prediction_title': 'Predictive Autonomy Estimation (AI)',
      'danger_title': 'DANGER !',
      'leak_detected': 'LPG GAS LEAK DETECTED',
      'mute_buzzer': 'Mute Buzzer (120 s)',
      'close_valve_emergency': 'Emergency Valve Cutoff',
      'tare': 'Tare (0 kg)',
      'calibrate': 'Calibrate (5 kg)',
      'demo_mode': 'Demo Mode (Simulator)',
    },
  };

  String text(String key) {
    return _localizedValues[locale]?[key] ?? _localizedValues['fr']?[key] ?? key;
  }
}
