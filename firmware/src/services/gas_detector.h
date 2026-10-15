#pragma once

#include <Arduino.h>

class GasDetector {
public:
    GasDetector(uint8_t analog_pin = 34, float ro_kohm = 10.0f);

    void begin();

    // Traite une lecture ADC et renvoie les ppm calculés
    int process(float temp_c = 20.0f, float humidity_pct = 50.0f);

    // Évalue l'état de fuite avec hystérésis et temporisation anti-faux-positifs
    bool isLeakDetected(int ppm, int threshold_ppm);

    // Indique si le capteur est encore en préchauffage
    bool isWarmingUp() const;
    int  getPreheatRemainingSeconds() const;

    // Détecte une déconnexion physique ou un court-circuit du capteur
    bool isSensorFault() const;

    void setRo(float ro_kohm);
    float getRo() const;

private:
    uint8_t _pin;
    float   _ro;
    uint32_t _boot_time_ms;
    uint32_t _leak_start_ms;
    bool    _current_leak_state;
    bool    _sensor_fault;
};
