#pragma once

#include <Arduino.h>
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>
#include <freertos/queue.h>
#include "config.h"

// =============================================================================
// THREAD-SAFE STATE & CONFIGURATION DATA STRUCTURES
// =============================================================================

enum ValveState {
    VALVE_STATE_CLOSED = 0,
    VALVE_STATE_OPEN = 1,
    VALVE_STATE_DISABLED = 2
};

enum EventSeverity {
    SEV_INFO,
    SEV_WARNING,
    SEV_CRITICAL
};

struct SystemEvent {
    char event_type[32];   // "leak_critical", "level_low", "bottle_replaced", etc.
    EventSeverity severity;
    uint32_t timestamp;
    char message[128];
    float value1;
    float value2;
};

struct TelemetryState {
    float weight_kg;          // Poids net restant de gaz (kg)
    float gross_weight_kg;    // Poids brut total sur le plateau (kg)
    float level_percent;      // Pourcentage 0.0 - 100.0%
    int   gas_ppm;            // Concentration de gaz en ppm
    bool  leak;               // Fuite active détectée
    float temperature_c;      // Température ambiante (°C)
    float humidity_percent;   // Humidité ambiante (%)
    ValveState valve_state;   // État de l'électrovanne
    bool  buzzer_muted;       // Sourdine temporaire active
    uint32_t mute_end_time_s; // Heure de fin de la sourdine
    bool  sensor_fault;       // Panne détectée sur capteur HX711 ou MQ
    int   wifi_rssi;          // Force du signal Wi-Fi
    uint32_t uptime_s;        // Secondes depuis démarrage
    uint32_t timestamp;       // Timestamp Unix UTC ou local
    bool  in_pairing_mode;    // Si mode appairage PIN actif
    char  pairing_pin[7];     // Code PIN à 6 chiffres affiché sur TFT
    uint32_t pairing_expiry_s;// Expiration du code PIN
};

struct SystemConfig {
    char bottle_name[32];
    BottlePreset bottle_type;
    float capacity_kg;
    float tare_weight_kg;
    float calibration_scale;   // Facteur d'échelle du HX711 (ticks par kg)
    long  tare_offset;         // Offset zéro du HX711
    int   leak_threshold_ppm;
    float low_level_percent;
    float critical_level_percent;
    bool  buzzer_enabled;
    bool  valve_enabled;
    bool  valve_auto_cutoff;
    bool  mqtt_enabled;
    char  mqtt_broker[64];
    int   mqtt_port;
    char  mqtt_user[32];
    char  mqtt_pass[32];
    char  auth_token[48];      // Jeton Bearer sécurisé pour l'API REST
    char  wifi_ssid[33];
    char  wifi_password[65];
};

// Accesseurs thread-safe protégés par sémaphores FreeRTOS
void initState();
void getTelemetryCopy(TelemetryState* dest);
void updateTelemetry(const TelemetryState* src);

void getConfigCopy(SystemConfig* dest);
void updateConfig(const SystemConfig* src);

// Queue d'événements asynchrones
extern QueueHandle_t g_eventQueue;
bool postSystemEvent(const char* type, EventSeverity sev, const char* msg, float val1 = 0, float val2 = 0);
