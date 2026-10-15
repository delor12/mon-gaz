#include "sensor_task.h"
#include "config.h"
#include "state.h"
#include "services/weight_filter.h"
#include "services/gas_detector.h"
#include "services/storage_manager.h"
#include <HX711.h>
#include <DHT.h>

static TaskHandle_t s_sensorTaskHandle = nullptr;
static HX711 s_scale;
static DHT s_dht(PIN_DHT22, DHTTYPE);
static GasDetector s_gasDetector(PIN_MQ_ANALOG, MQ_RO_DEFAULT);
static WeightFilter s_weightFilter(9);

static void sensorTaskLoop(void* pvParameters) {
    (void)pvParameters;

    // Initialisation HX711
    s_scale.begin(PIN_HX711_DOUT, PIN_HX711_SCK);
    s_scale.power_up();

    // Initialisation DHT
    s_dht.begin();

    // Initialisation capteur de gaz
    s_gasDetector.begin();

    Serial.println(F("[SENSORS] Capteurs initialisés (HX711, DHT22, MQ-6)"));

    uint32_t last_1hz_tick = 0;
    uint32_t last_dht_tick = 0;
    uint32_t last_history_record_tick = 0;
    float last_recorded_weight = 0.0f;
    bool previous_leak_state = false;

    for (;;) {
        uint32_t now = millis();
        SystemConfig cfg;
        getConfigCopy(&cfg);

        TelemetryState tel;
        getTelemetryCopy(&tel);

        // --- 1. LECTURE CELLULE DE CHARGE HX711 (10 Hz = 100ms) ---
        if (s_scale.is_ready()) {
            long raw_reading = s_scale.read(); // Lecture brute
            float scale_factor = (cfg.calibration_scale != 0.0f) ? cfg.calibration_scale : -22450.0f;
            float raw_weight_kg = (float)(raw_reading - cfg.tare_offset) / scale_factor;

            // Filtrage médian et anti-bruit
            float filtered_gross_kg = s_weightFilter.process(raw_weight_kg);
            tel.gross_weight_kg = filtered_gross_kg;

            // Calcul du poids net de gaz restant
            float net_kg = filtered_gross_kg - cfg.tare_weight_kg;
            if (net_kg < 0.0f) net_kg = 0.0f;
            tel.weight_kg = net_kg;

            // Calcul du pourcentage
            if (cfg.capacity_kg > 0.0f) {
                float pct = (net_kg / cfg.capacity_kg) * 100.0f;
                if (pct > 100.0f) pct = 100.0f;
                if (pct < 0.0f) pct = 0.0f;
                tel.level_percent = std::round(pct * 10.0f) / 10.0f;
            }

            // Détection automatique de remplacement de bouteille
            float delta_jump = 0.0f;
            if (s_weightFilter.checkBottleReplaced(filtered_gross_kg, &delta_jump)) {
                Serial.printf("[SENSORS] Bouteille remplacée détectée (+%.2f kg) !\n", delta_jump);
                postSystemEvent("bottle_replaced", SEV_INFO, "Bouteille changée détectée", net_kg, delta_jump);
            }
        }

        // --- 2. LECTURE TEMPÉRATURE & HUMIDITÉ (Toutes les 2 secondes) ---
        if (now - last_dht_tick >= 2000) {
            last_dht_tick = now;
            float t = s_dht.readTemperature();
            float h = s_dht.readHumidity();
            if (!isnan(t) && !isnan(h)) {
                tel.temperature_c = std::round(t * 10.0f) / 10.0f;
                tel.humidity_percent = std::round(h * 10.0f) / 10.0f;
            } else {
                tel.temperature_c = 21.5f; // Valeur par défaut
                tel.humidity_percent = 50.0f;
            }
        }

        // --- 3. LECTURE DU CAPTEUR DE GAZ MQ (Cadence 1 Hz = 1000ms) ---
        if (now - last_1hz_tick >= 1000) {
            last_1hz_tick = now;

            tel.uptime_s = now / 1000;
            tel.timestamp = tel.uptime_s; // Ou synchro NTP si disponible

            int ppm = s_gasDetector.process(tel.temperature_c, tel.humidity_percent);
            tel.gas_ppm = ppm;
            tel.sensor_fault = s_gasDetector.isSensorFault();

            bool is_leak = s_gasDetector.isLeakDetected(ppm, cfg.leak_threshold_ppm);
            tel.leak = is_leak;

            // Détection de transition vers état de fuite
            if (is_leak && !previous_leak_state) {
                Serial.printf("[ALARM] ALERTE FUITE DE GAZ CRITIQUE : %d ppm !\n", ppm);
                postSystemEvent("leak_critical", SEV_CRITICAL, "Fuite critique de gaz GPL détectée !", (float)ppm, (float)cfg.leak_threshold_ppm);
            }
            previous_leak_state = is_leak;

            // Détection seuil de niveau bas
            if (tel.level_percent <= cfg.low_level_percent && tel.level_percent > cfg.critical_level_percent) {
                static uint32_t last_low_warn = 0;
                if (now - last_low_warn >= 3600000UL) { // Rappel horaire
                    last_low_warn = now;
                    postSystemEvent("level_low", SEV_WARNING, "Niveau de gaz faible", tel.level_percent);
                }
            }

            // Enregistrement horaire pour l'historique
            if (now - last_history_record_tick >= 3600000UL) {
                float consumption = (last_recorded_weight > tel.weight_kg) ? (last_recorded_weight - tel.weight_kg) : 0.0f;
                last_recorded_weight = tel.weight_kg;
                last_history_record_tick = now;
                StorageManager::recordHistoryPoint(now / 1000, tel.weight_kg, consumption);
            }
        }

        updateTelemetry(&tel);

        // Sommeil de 100ms pour correspondre au taux 10 Hz du HX711
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

void startSensorTask() {
    xTaskCreatePinnedToCore(
        sensorTaskLoop,
        "SensorTask",
        4096,
        nullptr,
        4, // Priorité haute
        &s_sensorTaskHandle,
        1  // Épinglé sur Core 1 (matériel)
    );
}
