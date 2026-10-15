#pragma once

#include <Arduino.h>

// =============================================================================
// SMARTGAS FIRMWARE CONFIGURATION & GPIO PINOUT
// =============================================================================

#define SMARTGAS_FIRMWARE_VERSION "1.0.0"
#define SMARTGAS_DEVICE_PREFIX   "ESP32-SMARTGAS"
#define SMARTGAS_MDNS_HOST       "smartgas"
#define SMARTGAS_AP_SSID_PREFIX  "SmartGas-Setup"

// --- PINS CAPTEUR DE POIDS (HX711) ---
#define PIN_HX711_DOUT           21
#define PIN_HX711_SCK            22

// --- PINS CAPTEUR DE GAZ (MQ-6 / MQ-2) ---
// Utiliser impérativement ADC1 (GPIO 32-39) car ADC2 est utilisé par le Wi-Fi
#define PIN_MQ_ANALOG            34
#define MQ_PREHEAT_SECONDS       30    // Préchauffage initial du capteur MQ
#define MQ_ADC_RESOLUTION        4095  // Résolution 12-bit ESP32
#define MQ_RL_VALUE_KOHM         10.0f // Résistance de charge RL en kOhms
#define MQ_RO_DEFAULT            10.0f // Valeur Ro par défaut en air pur (kOhms)

// --- CAPTEUR ENVIRONNEMENTAL (DHT22 / BME280) ---
#define PIN_DHT22                32
#define DHTTYPE                  DHT22

// --- ALARMES MATÉRIELLES LOCALES (AUTONOMES) ---
#define PIN_BUZZER               25
#define PIN_LED_ALERT            26
#define PIN_RELAY_VALVE          27    // Électrovanne coupure gaz (Fail-Safe)
#define PIN_PAIR_BUTTON          33    // Bouton poussoir physique pour appairage

// --- ÉCRAN TFT (ST7789 / ILI9341 via SPI matériel) ---
#define PIN_TFT_MOSI             23
#define PIN_TFT_SCLK             18
#define PIN_TFT_CS               5
#define PIN_TFT_DC               2
#define PIN_TFT_RST              4
#define PIN_TFT_BL               15    // Rétroéclairage TFT (Backlight)

// --- PWM BUZZER (LEDC) ---
#define BUZZER_LEDC_CHANNEL      0
#define BUZZER_LEDC_TIMER        LEDC_TIMER_0
#define BUZZER_FREQ_HZ           2700  // Fréquence sonore stridente d'alarme (2.7 kHz)
#define BUZZER_RESOLUTION_BITS   8

// --- SEUILS DE SÉCURITÉ ET DE MESURE PAR DÉFAUT ---
#define DEFAULT_LEAK_PPM         400   // Seuil de fuite critique en ppm
#define DEFAULT_LOW_PERCENT      15.0f // Seuil alerte niveau bas (%)
#define DEFAULT_CRIT_PERCENT     5.0f  // Seuil alerte niveau critique (%)
#define DEFAULT_MUTE_TIMEOUT_S   120   // Sourdine temporaire (secondes)
#define BOTTLE_DETECT_DELTA_KG   8.0f  // Saut de poids positif détectant une nouvelle bouteille
#define MICRO_LEAK_RATE_KG_HR    0.020f // 20g/heure de perte anormale continue

// --- PRÉ-CONFIGURATIONS TYPES DE BOUTEILLES GPL ---
enum BottlePreset {
    BOTTLE_B6,    // Bouteille 6 kg (ex: Elfi, Malice, Calypso)
    BOTTLE_B12_5, // Bouteille 12.5 kg / 13 kg standard (Butane / Propane)
    BOTTLE_B35,   // Bouteille industrielle 35 kg
    BOTTLE_CUSTOM // Configuration sur-mesure utilisateur
};

struct BottleSpec {
    const char* name;
    float nominal_capacity_kg;
    float default_tare_kg;
};

static const BottleSpec BOTTLE_SPECS[] = {
    {"B6 (6 kg)", 6.0f, 7.2f},
    {"B12.5 (12.5 kg)", 12.5f, 13.0f},
    {"B35 (35 kg)", 35.0f, 32.0f},
    {"Personnalisée", 12.5f, 13.0f}
};
