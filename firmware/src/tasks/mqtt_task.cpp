#include "mqtt_task.h"
#include "config.h"
#include "state.h"
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

static TaskHandle_t s_mqttTaskHandle = nullptr;
static WiFiClientSecure s_wifiClientSecure;
static PubSubClient s_mqttClient(s_wifiClientSecure);

static const char* TOPIC_TELEMETRY = "smartgas/ESP32-SMARTGAS-8A4F/telemetry";
static const char* TOPIC_STATUS    = "smartgas/ESP32-SMARTGAS-8A4F/status";
static const char* TOPIC_CMD       = "smartgas/ESP32-SMARTGAS-8A4F/cmd/#";

// Buffer de télémétrie hors ligne (Ring buffer de 10 points)
struct OfflineRecord {
    uint32_t ts;
    float weight;
    int ppm;
    bool leak;
};
static OfflineRecord s_offline_ring[10];
static int s_offline_count = 0;

static void onMqttMessage(char* topic, byte* payload, unsigned int length) {
    char msg[256];
    if (length >= sizeof(msg)) length = sizeof(msg) - 1;
    memcpy(msg, payload, length);
    msg[length] = '\0';

    Serial.printf("[MQTT] Message reçu sur topic [%s]: %s\n", topic, msg);

    StaticJsonDocument<256> doc;
    DeserializationError err = deserializeJson(doc, msg);
    if (!err) {
        if (doc.containsKey("action")) {
            const char* act = doc["action"];
            if (strcmp(act, "MUTE") == 0) {
                TelemetryState tel;
                getTelemetryCopy(&tel);
                tel.buzzer_muted = true;
                tel.mute_end_time_s = (millis() / 1000) + 120;
                updateTelemetry(&tel);
                Serial.println(F("[MQTT] Commande MUTE recue"));
            } else if (strcmp(act, "CLOSE_VALVE") == 0) {
                digitalWrite(PIN_RELAY_VALVE, LOW);
                TelemetryState tel;
                getTelemetryCopy(&tel);
                tel.valve_state = VALVE_STATE_CLOSED;
                updateTelemetry(&tel);
                Serial.println(F("[MQTT] Commande CLOSE_VALVE executee"));
            }
        }
    }
}

static void mqttTaskLoop(void* pvParameters) {
    (void)pvParameters;

    s_wifiClientSecure.setInsecure(); // Accepte certificat autosigné en dev / peut être configuré avec CA
    s_mqttClient.setCallback(onMqttMessage);

    uint32_t last_publish_ms = 0;

    for (;;) {
        SystemConfig cfg;
        getConfigCopy(&cfg);

        if (cfg.mqtt_enabled && WiFi.status() == WL_CONNECTED) {
            s_mqttClient.setServer(cfg.mqtt_broker, cfg.mqtt_port);

            if (!s_mqttClient.connected()) {
                Serial.printf("[MQTT] Connexion au broker %s:%d...\n", cfg.mqtt_broker, cfg.mqtt_port);
                
                // LWT (Last Will and Testament)
                if (s_mqttClient.connect("SmartGas-Device-8A4F", 
                                         TOPIC_STATUS, 1, true, "{\"online\":false}")) {
                    Serial.println(F("[MQTT] Connecté avec succès !"));
                    s_mqttClient.publish(TOPIC_STATUS, "{\"online\":true}", true);
                    s_mqttClient.subscribe(TOPIC_CMD);

                    // Rejeu du buffer hors ligne
                    while (s_offline_count > 0) {
                        s_offline_count--;
                        StaticJsonDocument<256> offDoc;
                        offDoc["timestamp"] = s_offline_ring[s_offline_count].ts;
                        offDoc["weight_kg"] = s_offline_ring[s_offline_count].weight;
                        offDoc["gas_ppm"] = s_offline_ring[s_offline_count].ppm;
                        offDoc["leak"] = s_offline_ring[s_offline_count].leak;
                        offDoc["offline_replay"] = true;

                        String out;
                        serializeJson(offDoc, out);
                        s_mqttClient.publish(TOPIC_TELEMETRY, out.c_str());
                    }
                }
            }

            if (s_mqttClient.connected()) {
                s_mqttClient.loop();

                uint32_t now = millis();
                TelemetryState tel;
                getTelemetryCopy(&tel);

                // Publication toutes les 10 secondes ou immédiatement si fuite
                if ((now - last_publish_ms >= 10000) || tel.leak) {
                    last_publish_ms = now;

                    StaticJsonDocument<512> doc;
                    doc["device_id"] = "ESP32-SMARTGAS-8A4F";
                    doc["weight_kg"] = tel.weight_kg;
                    doc["gross_weight_kg"] = tel.gross_weight_kg;
                    doc["level_percent"] = tel.level_percent;
                    doc["gas_ppm"] = tel.gas_ppm;
                    doc["leak"] = tel.leak;
                    doc["temperature_c"] = tel.temperature_c;
                    doc["valve_state"] = (tel.valve_state == VALVE_STATE_OPEN) ? "OPEN" : "CLOSED";
                    doc["timestamp"] = tel.timestamp;

                    String payload;
                    serializeJson(doc, payload);
                    s_mqttClient.publish(TOPIC_TELEMETRY, payload.c_str());
                }
            } else {
                // Bufferiser localement en mémoire tampon en cas de coupure
                TelemetryState tel;
                getTelemetryCopy(&tel);
                if (s_offline_count < 10) {
                    s_offline_ring[s_offline_count].ts = millis() / 1000;
                    s_offline_ring[s_offline_count].weight = tel.weight_kg;
                    s_offline_ring[s_offline_count].ppm = tel.gas_ppm;
                    s_offline_ring[s_offline_count].leak = tel.leak;
                    s_offline_count++;
                }
            }
        }

        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

void startMqttTask() {
    xTaskCreatePinnedToCore(
        mqttTaskLoop,
        "MqttTask",
        6144,
        nullptr,
        2, // Priorité normale
        &s_mqttTaskHandle,
        0  // Épinglé sur Core 0
    );
}
