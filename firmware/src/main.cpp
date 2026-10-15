#include <Arduino.h>
#include <esp_task_wdt.h>
#include "config.h"
#include "state.h"
#include "services/storage_manager.h"
#include "tasks/alarm_task.h"
#include "tasks/sensor_task.h"
#include "tasks/display_task.h"
#include "tasks/network_task.h"
#include "tasks/mqtt_task.h"

#define WDT_TIMEOUT_SECONDS 8

void setup() {
    Serial.begin(115200);
    delay(500);

    Serial.println();
    Serial.println(F("=================================================="));
    Serial.println(F("   SMART GAS ESP32 FIRMWARE - INITIALISATION     "));
    Serial.println(F("=================================================="));

    // 1. Initialisation de la mémoire flash et de la persistance NVS
    initState();
    StorageManager::init();

    // 2. Chargement de la configuration persistée
    SystemConfig cfg;
    getConfigCopy(&cfg);
    StorageManager::loadConfig(&cfg);
    updateConfig(&cfg);
    Serial.printf("[SYSTEM] Configuration chargee pour bouteille: %s\n", cfg.bottle_name);

    // 3. Configuration du Watchdog matériel (TWDT)
    esp_task_wdt_init(WDT_TIMEOUT_SECONDS, true); // Reset automatique si blocage > 8s
    esp_task_wdt_add(nullptr);                    // Ajoute la tâche courante (loop)

    // 4. Lancement des tâches FreeRTOS prioritaires (Core 1 - Matériel)
    startAlarmTask();   // Sécurité autonome Buzzer / Relais (Priorité 5)
    startSensorTask();  // HX711, MQ-6, DHT22 (Priorité 4)

    // 5. Lancement des tâches réseau et interface (Core 0 - Réseau/UI)
    startDisplayTask(); // Écran TFT ST7789 (Priorité 2)
    startNetworkTask(); // Wi-Fi, mDNS, WebServer, WebSocket (Priorité 2)
    startMqttTask();    // MQTT/TLS distant (Priorité 2)

    Serial.println(F("[SYSTEM] Toutes les tâches FreeRTOS sont actives. Démarrage réussi."));
}

void loop() {
    // Nourrir le watchdog matériel
    esp_task_wdt_reset();
    vTaskDelay(pdMS_TO_TICKS(1000));
}
