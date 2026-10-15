#include "alarm_task.h"
#include "config.h"
#include "state.h"
#include "services/storage_manager.h"

static TaskHandle_t s_alarmTaskHandle = nullptr;

static void alarmTaskLoop(void* pvParameters) {
    (void)pvParameters;

    // Configuration des sorties matérielles de sécurité
    pinMode(PIN_LED_ALERT, OUTPUT);
    digitalWrite(PIN_LED_ALERT, LOW);

    pinMode(PIN_RELAY_VALVE, OUTPUT);
    digitalWrite(PIN_RELAY_VALVE, HIGH); // Par défaut vanne armée ouverte si activée

    pinMode(PIN_PAIR_BUTTON, INPUT_PULLUP);

    // Initialisation PWM LEDC pour le buzzer
    ledcSetup(BUZZER_LEDC_CHANNEL, BUZZER_FREQ_HZ, BUZZER_RESOLUTION_BITS);
    ledcAttachPin(PIN_BUZZER, BUZZER_LEDC_CHANNEL);
    ledcWrite(BUZZER_LEDC_CHANNEL, 0); // Éteint au démarrage

    bool buzzer_tone_phase = false;
    uint32_t last_toggle_ms = 0;
    uint32_t button_press_start_ms = 0;
    bool last_button_state = HIGH;
    bool valve_cutoff_executed = false;

    Serial.println(F("[SAFETY] Tâche d'alarme autonome FreeRTOS démarrée sur Core 1"));

    for (;;) {
        uint32_t now = millis();
        uint32_t now_s = now / 1000;

        TelemetryState tel;
        getTelemetryCopy(&tel);

        SystemConfig cfg;
        getConfigCopy(&cfg);

        // --- 1. GESTION DU MUTE TEMPORAIRE DU BUZZER ---
        if (tel.buzzer_muted && now_s >= tel.mute_end_time_s) {
            tel.buzzer_muted = false;
            updateTelemetry(&tel);
            Serial.println(F("[ALARM] Expiration du mute. Buzzer réactivé."));
        }

        // --- 2. TRAITEMENT DE LA FUITE DE GAZ CRITIQUE ---
        if (tel.leak) {
            // A. Coupure automatique immédiate de l'électrovanne (Fail-Safe)
            if (cfg.valve_enabled && cfg.valve_auto_cutoff && !valve_cutoff_executed) {
                digitalWrite(PIN_RELAY_VALVE, LOW); // Coupe le relais (ferme l'arrivée de gaz)
                tel.valve_state = VALVE_STATE_CLOSED;
                updateTelemetry(&tel);
                valve_cutoff_executed = true;
                Serial.println(F("[SAFETY] COUPURE D'URGENCE DE L'ÉLECTROVANNE EXÉCUTÉE !"));
                postSystemEvent("valve_closed", SEV_CRITICAL, "Électrovanne coupée automatiquement suite à fuite.");
            }

            // B. Flash stroboscopique LED rouge (150ms on / 150ms off)
            if (now - last_toggle_ms >= 150) {
                last_toggle_ms = now;
                buzzer_tone_phase = !buzzer_tone_phase;
                digitalWrite(PIN_LED_ALERT, buzzer_tone_phase ? HIGH : LOW);

                // C. Buzzer strident (sauf si muet ou désactivé)
                if (cfg.buzzer_enabled && !tel.buzzer_muted) {
                    ledcWrite(BUZZER_LEDC_CHANNEL, buzzer_tone_phase ? 128 : 0);
                } else {
                    ledcWrite(BUZZER_LEDC_CHANNEL, 0);
                }
            }
        } else {
            // Fuite terminée : extinction des avertisseurs physiques
            valve_cutoff_executed = false;
            digitalWrite(PIN_LED_ALERT, LOW);
            ledcWrite(BUZZER_LEDC_CHANNEL, 0);

            // Bip discret si niveau critique de gaz
            if (tel.level_percent <= cfg.critical_level_percent && tel.level_percent > 0.0f) {
                // Flash lent toutes les 2 secondes
                if ((now / 1000) % 2 == 0) {
                    digitalWrite(PIN_LED_ALERT, HIGH);
                } else {
                    digitalWrite(PIN_LED_ALERT, LOW);
                }
            }
        }

        // --- 3. GESTION DU BOUTON PHYSIQUE D'APPAIRAGE ---
        bool current_btn = digitalRead(PIN_PAIR_BUTTON);
        if (current_btn == LOW && last_button_state == HIGH) {
            button_press_start_ms = now;
        } else if (current_btn == LOW && last_button_state == LOW) {
            // Si maintenu plus de 2 secondes
            if (button_press_start_ms > 0 && (now - button_press_start_ms >= 2000)) {
                button_press_start_ms = 0; // Reset
                char new_pin[7];
                StorageManager::generateNewPairingPin(new_pin);
                Serial.printf("[AUTH] Mode appairage activé par bouton physique ! Nouveau PIN : %s\n", new_pin);
                postSystemEvent("pairing_started", SEV_INFO, "Session d'appairage ouverte");
                // Petit bip de confirmation
                ledcWrite(BUZZER_LEDC_CHANNEL, 128);
                vTaskDelay(pdMS_TO_TICKS(150));
                ledcWrite(BUZZER_LEDC_CHANNEL, 0);
            }
        }
        last_button_state = current_btn;

        // Période d'exécution réactive de 50ms
        vTaskDelay(pdMS_TO_TICKS(50));
    }
}

void startAlarmTask() {
    xTaskCreatePinnedToCore(
        alarmTaskLoop,
        "AlarmTask",
        4096,
        nullptr,
        5, // Priorité maximale
        &s_alarmTaskHandle,
        1  // Épinglé sur Core 1 (matériel autonome)
    );
}
