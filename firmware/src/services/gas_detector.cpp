#include "gas_detector.h"
#include "config.h"
#include <cmath>

GasDetector::GasDetector(uint8_t analog_pin, float ro_kohm)
    : _pin(analog_pin), _ro(ro_kohm), _boot_time_ms(0), _leak_start_ms(0),
      _current_leak_state(false), _sensor_fault(false) {}

void GasDetector::begin() {
    pinMode(_pin, INPUT);
    analogSetPinAttenuation(_pin, ADC_11db); // Mesure jusqu'à ~3.3V
    _boot_time_ms = millis();
}

bool GasDetector::isWarmingUp() const {
    return (millis() - _boot_time_ms) < (MQ_PREHEAT_SECONDS * 1000UL);
}

int GasDetector::getPreheatRemainingSeconds() const {
    uint32_t elapsed = millis() - _boot_time_ms;
    uint32_t total = MQ_PREHEAT_SECONDS * 1000UL;
    if (elapsed >= total) return 0;
    return (int)((total - elapsed) / 1000UL);
}

bool GasDetector::isSensorFault() const {
    return _sensor_fault;
}

void GasDetector::setRo(float ro_kohm) {
    if (ro_kohm > 0.1f && ro_kohm < 500.0f) {
        _ro = ro_kohm;
    }
}

float GasDetector::getRo() const {
    return _ro;
}

int GasDetector::process(float temp_c, float humidity_pct) {
    int raw_adc = analogRead(_pin);

    // Détection panne matérielle (coupure de fil ou court-circuit)
    if (raw_adc < 30 || raw_adc > 4080) {
        _sensor_fault = true;
        return 0;
    }
    _sensor_fault = false;

    // Préchauffage en cours
    if (isWarmingUp()) {
        return 50; // Valeur nominale d'air pur pendant le préchauffage
    }

    // Calcul de la tension de sortie
    float v_out = ((float)raw_adc / 4095.0f) * 3.3f;
    if (v_out <= 0.05f) return 50;

    // Calcul de la résistance du capteur Rs = ((Vc - Vout) / Vout) * RL
    float rs = ((3.3f - v_out) / v_out) * MQ_RL_VALUE_KOHM;

    // Facteur de compensation température et humidité (norme constructeur MQ-6)
    // T nominale = 20°C, H nominale = 50%
    float temp_diff = temp_c - 20.0f;
    float hum_diff = humidity_pct - 50.0f;
    float compensation_factor = 1.0f - (0.005f * temp_diff) - (0.002f * hum_diff);
    if (compensation_factor < 0.5f) compensation_factor = 0.5f;
    if (compensation_factor > 1.6f) compensation_factor = 1.6f;

    float rs_compensated = rs / compensation_factor;
    float ratio = rs_compensated / _ro;
    if (ratio <= 0.01f) ratio = 0.01f;

    // Courbe de réponse MQ-6 GPL : ppm = 1000 * (Rs/Ro)^(-2.15)
    float ppm = 1000.0f * std::pow(ratio, -2.15f);

    // Bornage de sécurité
    if (ppm < 10.0f) ppm = 10.0f;
    if (ppm > 10000.0f) ppm = 10000.0f;

    return (int)ppm;
}

bool GasDetector::isLeakDetected(int ppm, int threshold_ppm) {
    if (isWarmingUp() || _sensor_fault) {
        return false;
    }

    uint32_t now = millis();

    // Condition de dépassement de seuil
    if (ppm >= threshold_ppm) {
        if (_leak_start_ms == 0) {
            _leak_start_ms = now;
        } else if (now - _leak_start_ms >= 2000) { // 2 secondes de persistance anti-faux-positifs
            _current_leak_state = true;
        }
    } else {
        // Hystérésis : ne repasser à faux que si la concentration chute sous 80% du seuil
        if (_current_leak_state) {
            if (ppm < (threshold_ppm * 0.8f)) {
                _current_leak_state = false;
                _leak_start_ms = 0;
            }
        } else {
            _leak_start_ms = 0;
        }
    }

    return _current_leak_state;
}
