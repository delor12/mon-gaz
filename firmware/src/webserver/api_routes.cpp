#include "api_routes.h"
#include "state.h"
#include "services/storage_manager.h"
#include <ArduinoJson.h>
#include <LittleFS.h>
#include <esp_system.h>
#include <AsyncJson.h>

static bool isAuthorized(AsyncWebServerRequest* request) {
    SystemConfig cfg;
    getConfigCopy(&cfg);
    if (!request->hasHeader("Authorization")) return false;
    String auth = request->getHeader("Authorization")->value();
    if (!auth.startsWith("Bearer ")) return false;
    String token = auth.substring(7);
    return (token.equals(cfg.auth_token));
}

static void sendJsonError(AsyncWebServerRequest* request, int httpCode, const char* code, const char* msg) {
    StaticJsonDocument<256> doc;
    doc["code"] = code;
    doc["message"] = msg;
    String out;
    serializeJson(doc, out);
    request->send(httpCode, "application/json", out);
}

void registerApiRoutes(AsyncWebServer& server) {
    // OPTIONS handler pour CORS pre-flight
    server.onNotFound([](AsyncWebServerRequest* request) {
        if (request->method() == HTTP_OPTIONS) {
            request->send(200);
        } else {
            request->send(404, "application/json", "{\"code\":\"NOT_FOUND\",\"message\":\"Route non trouvee\"}");
        }
    });

    // 1. POST /api/v1/auth/pair
    AsyncCallbackJsonWebHandler* pairHandler = new AsyncCallbackJsonWebHandler(
        "/api/v1/auth/pair",
        [](AsyncWebServerRequest* request, JsonVariant& json) {
            JsonObject obj = json.as<JsonObject>();
            const char* pin = obj["pin_code"];
            if (!pin || strlen(pin) != 6) {
                sendJsonError(request, 400, "INVALID_PIN_FORMAT", "Le code PIN doit comporter 6 chiffres");
                return;
            }

            TelemetryState tel;
            getTelemetryCopy(&tel);
            uint32_t now_s = millis() / 1000;

            if (!tel.in_pairing_mode || now_s > tel.pairing_expiry_s) {
                sendJsonError(request, 401, "PAIRING_SESSION_EXPIRED", "Aucune session d'appairage active. Appuyez sur le bouton physique");
                return;
            }

            if (strncmp(pin, tel.pairing_pin, 6) != 0) {
                sendJsonError(request, 401, "INVALID_PIN_CODE", "Code PIN incorrect");
                return;
            }

            // Génération d'un nouveau jeton Bearer
            char new_token[48];
            snprintf(new_token, sizeof(new_token), "sg_sec_%08x%08x%08x", 
                     esp_random(), esp_random(), esp_random());
            StorageManager::saveAuthToken(new_token);

            // Fin du mode appairage
            tel.in_pairing_mode = false;
            updateTelemetry(&tel);

            StaticJsonDocument<256> doc;
            doc["token"] = new_token;
            doc["device_id"] = "ESP32-SMARTGAS-8A4F";
            doc["expires_in_days"] = 365;

            String out;
            serializeJson(doc, out);
            request->send(200, "application/json", out);
        }
    );
    server.addHandler(pairHandler);

    // 2. GET /api/v1/data
    server.on("/api/v1/data", HTTP_GET, [](AsyncWebServerRequest* request) {
        TelemetryState tel;
        getTelemetryCopy(&tel);

        StaticJsonDocument<512> doc;
        doc["device_id"] = "ESP32-SMARTGAS-8A4F";
        doc["weight_kg"] = tel.weight_kg;
        doc["gross_weight_kg"] = tel.gross_weight_kg;
        doc["level_percent"] = tel.level_percent;
        doc["gas_ppm"] = tel.gas_ppm;
        doc["leak"] = tel.leak;
        doc["temperature_c"] = tel.temperature_c;
        doc["humidity_percent"] = tel.humidity_percent;
        doc["valve_state"] = (tel.valve_state == VALVE_STATE_OPEN) ? "OPEN" :
                             (tel.valve_state == VALVE_STATE_CLOSED) ? "CLOSED" : "DISABLED";
        doc["buzzer_muted"] = tel.buzzer_muted;
        doc["sensor_fault"] = tel.sensor_fault;
        doc["rssi"] = tel.wifi_rssi;
        doc["uptime_s"] = tel.uptime_s;
        doc["firmware"] = SMARTGAS_FIRMWARE_VERSION;
        doc["timestamp"] = tel.timestamp;

        String out;
        serializeJson(doc, out);
        request->send(200, "application/json", out);
    });

    // 3. GET /api/v1/history
    server.on("/api/v1/history", HTTP_GET, [](AsyncWebServerRequest* request) {
        String range = request->hasParam("range") ? request->getParam("range")->value() : "day";
        String res = request->hasParam("resolution") ? request->getParam("resolution")->value() : "hour";
        String out = StorageManager::getHistoryJson(range, res);
        request->send(200, "application/json", out);
    });

    // 4. POST /api/v1/tare
    server.on("/api/v1/tare", HTTP_POST, [](AsyncWebServerRequest* request) {
        if (!isAuthorized(request)) {
            sendJsonError(request, 401, "UNAUTHORIZED", "Jeton d'autorisation Bearer invalide ou manquant");
            return;
        }

        TelemetryState tel;
        getTelemetryCopy(&tel);
        SystemConfig cfg;
        getConfigCopy(&cfg);

        // Mise à jour de l'offset de tare avec la lecture courante
        long new_tare = (long)(tel.gross_weight_kg * cfg.calibration_scale) + cfg.tare_offset;
        StorageManager::saveCalibration(new_tare, cfg.calibration_scale);

        StaticJsonDocument<256> doc;
        doc["success"] = true;
        doc["tare_offset"] = new_tare;
        doc["message"] = "Tare effectuee avec succes";

        String out;
        serializeJson(doc, out);
        request->send(200, "application/json", out);
    });

    // 5. POST /api/v1/calibrate
    AsyncCallbackJsonWebHandler* calHandler = new AsyncCallbackJsonWebHandler(
        "/api/v1/calibrate",
        [](AsyncWebServerRequest* request, JsonVariant& json) {
            if (!isAuthorized(request)) {
                sendJsonError(request, 401, "UNAUTHORIZED", "Jeton d'autorisation Bearer invalide");
                return;
            }

            JsonObject obj = json.as<JsonObject>();
            if (!obj.containsKey("known_weight_kg")) {
                sendJsonError(request, 400, "MISSING_PARAM", "Le champ 'known_weight_kg' est requis");
                return;
            }

            float known_weight = obj["known_weight_kg"].as<float>();
            if (known_weight < 0.2f || known_weight > 50.0f) {
                sendJsonError(request, 400, "INVALID_WEIGHT", "Poids connu hors des limites raisonnables (0.2 à 50 kg)");
                return;
            }

            TelemetryState tel;
            getTelemetryCopy(&tel);
            SystemConfig cfg;
            getConfigCopy(&cfg);

            // Équation de calcul du facteur d'échelle : scale = ticks / kg
            long raw_relative_ticks = (long)(tel.gross_weight_kg * cfg.calibration_scale);
            float new_scale = (float)raw_relative_ticks / known_weight;

            StorageManager::saveCalibration(cfg.tare_offset, new_scale);

            StaticJsonDocument<256> doc;
            doc["success"] = true;
            doc["calibration_factor"] = new_scale;
            doc["measured_weight_kg"] = known_weight;

            String out;
            serializeJson(doc, out);
            request->send(200, "application/json", out);
        }
    );
    server.addHandler(calHandler);

    // 6. GET /api/v1/config
    server.on("/api/v1/config", HTTP_GET, [](AsyncWebServerRequest* request) {
        SystemConfig cfg;
        getConfigCopy(&cfg);

        StaticJsonDocument<512> doc;
        doc["bottle_type"] = (cfg.bottle_type == BOTTLE_B6) ? "B6" :
                             (cfg.bottle_type == BOTTLE_B12_5) ? "B12_5" :
                             (cfg.bottle_type == BOTTLE_B35) ? "B35" : "CUSTOM";
        doc["bottle_name"] = cfg.bottle_name;
        doc["capacity_kg"] = cfg.capacity_kg;
        doc["tare_weight_kg"] = cfg.tare_weight_kg;
        doc["leak_threshold_ppm"] = cfg.leak_threshold_ppm;
        doc["low_level_threshold_percent"] = cfg.low_level_percent;
        doc["critical_level_threshold_percent"] = cfg.critical_level_percent;
        doc["buzzer_enabled"] = cfg.buzzer_enabled;
        doc["valve_enabled"] = cfg.valve_enabled;
        doc["valve_auto_cutoff"] = cfg.valve_auto_cutoff;
        doc["mqtt_enabled"] = cfg.mqtt_enabled;
        doc["mqtt_broker"] = cfg.mqtt_broker;
        doc["mqtt_port"] = cfg.mqtt_port;

        String out;
        serializeJson(doc, out);
        request->send(200, "application/json", out);
    });

    // 7. PUT /api/v1/config
    AsyncCallbackJsonWebHandler* cfgPutHandler = new AsyncCallbackJsonWebHandler(
        "/api/v1/config",
        [](AsyncWebServerRequest* request, JsonVariant& json) {
            if (!isAuthorized(request)) {
                sendJsonError(request, 401, "UNAUTHORIZED", "Jeton d'autorisation Bearer invalide");
                return;
            }

            JsonObject obj = json.as<JsonObject>();
            SystemConfig cfg;
            getConfigCopy(&cfg);

            if (obj.containsKey("bottle_name")) strncpy(cfg.bottle_name, obj["bottle_name"], sizeof(cfg.bottle_name) - 1);
            if (obj.containsKey("capacity_kg")) cfg.capacity_kg = obj["capacity_kg"];
            if (obj.containsKey("tare_weight_kg")) cfg.tare_weight_kg = obj["tare_weight_kg"];
            if (obj.containsKey("leak_threshold_ppm")) cfg.leak_threshold_ppm = obj["leak_threshold_ppm"];
            if (obj.containsKey("low_level_threshold_percent")) cfg.low_level_percent = obj["low_level_threshold_percent"];
            if (obj.containsKey("critical_level_threshold_percent")) cfg.critical_level_percent = obj["critical_level_threshold_percent"];
            if (obj.containsKey("buzzer_enabled")) cfg.buzzer_enabled = obj["buzzer_enabled"];
            if (obj.containsKey("valve_enabled")) cfg.valve_enabled = obj["valve_enabled"];
            if (obj.containsKey("valve_auto_cutoff")) cfg.valve_auto_cutoff = obj["valve_auto_cutoff"];
            if (obj.containsKey("mqtt_enabled")) cfg.mqtt_enabled = obj["mqtt_enabled"];
            if (obj.containsKey("mqtt_broker")) strncpy(cfg.mqtt_broker, obj["mqtt_broker"], sizeof(cfg.mqtt_broker) - 1);
            if (obj.containsKey("mqtt_port")) cfg.mqtt_port = obj["mqtt_port"];

            StorageManager::saveConfig(&cfg);
            updateConfig(&cfg);

            StaticJsonDocument<256> doc;
            doc["success"] = true;
            String out;
            serializeJson(doc, out);
            request->send(200, "application/json", out);
        }
    );
    server.addHandler(cfgPutHandler);

    // 8. POST /api/v1/alarm/mute
    AsyncCallbackJsonWebHandler* muteHandler = new AsyncCallbackJsonWebHandler(
        "/api/v1/alarm/mute",
        [](AsyncWebServerRequest* request, JsonVariant& json) {
            int duration = 120;
            if (json.is<JsonObject>() && json.as<JsonObject>().containsKey("duration_seconds")) {
                duration = json.as<JsonObject>()["duration_seconds"];
            }

            TelemetryState tel;
            getTelemetryCopy(&tel);
            tel.buzzer_muted = true;
            tel.mute_end_time_s = (millis() / 1000) + duration;
            updateTelemetry(&tel);

            StaticJsonDocument<256> doc;
            doc["muted"] = true;
            doc["mute_remaining_seconds"] = duration;
            String out;
            serializeJson(doc, out);
            request->send(200, "application/json", out);
        }
    );
    server.addHandler(muteHandler);

    // 9. POST /api/v1/valve/control
    AsyncCallbackJsonWebHandler* valveHandler = new AsyncCallbackJsonWebHandler(
        "/api/v1/valve/control",
        [](AsyncWebServerRequest* request, JsonVariant& json) {
            if (!isAuthorized(request)) {
                sendJsonError(request, 401, "UNAUTHORIZED", "Jeton Bearer requis");
                return;
            }

            JsonObject obj = json.as<JsonObject>();
            const char* action = obj["action"];
            if (!action) {
                sendJsonError(request, 400, "MISSING_ACTION", "Action OPEN ou CLOSE requise");
                return;
            }

            TelemetryState tel;
            getTelemetryCopy(&tel);

            if (strcmp(action, "OPEN") == 0) {
                if (tel.leak) {
                    sendJsonError(request, 403, "LEAK_ACTIVE_VALVE_LOCKED", 
                                  "Refus de securite : Impossible d'ouvrir la vanne pendant qu'une fuite est detectee.");
                    return;
                }
                digitalWrite(PIN_RELAY_VALVE, HIGH);
                tel.valve_state = VALVE_STATE_OPEN;
            } else if (strcmp(action, "CLOSE") == 0) {
                digitalWrite(PIN_RELAY_VALVE, LOW);
                tel.valve_state = VALVE_STATE_CLOSED;
            } else {
                sendJsonError(request, 400, "INVALID_ACTION", "Action doit etre OPEN ou CLOSE");
                return;
            }

            updateTelemetry(&tel);

            StaticJsonDocument<256> doc;
            doc["valve_state"] = (tel.valve_state == VALVE_STATE_OPEN) ? "OPEN" : "CLOSED";
            doc["auto_cutoff_active"] = false;
            String out;
            serializeJson(doc, out);
            request->send(200, "application/json", out);
        }
    );
    server.addHandler(valveHandler);

    // 10. GET /api/v1/system/info
    server.on("/api/v1/system/info", HTTP_GET, [](AsyncWebServerRequest* request) {
        TelemetryState tel;
        getTelemetryCopy(&tel);

        StaticJsonDocument<512> doc;
        doc["device_id"] = "ESP32-SMARTGAS-8A4F";
        doc["firmware_version"] = SMARTGAS_FIRMWARE_VERSION;
        doc["chip_model"] = ESP.getChipModel();
        doc["chip_cores"] = ESP.getChipCores();
        doc["cpu_freq_mhz"] = ESP.getCpuFreqMHz();
        doc["free_heap_bytes"] = ESP.getFreeHeap();
        doc["min_free_heap_bytes"] = ESP.getMinFreeHeap();
        doc["wifi_rssi"] = tel.wifi_rssi;

        String out;
        serializeJson(doc, out);
        request->send(200, "application/json", out);
    });

    // 11. POST /api/v1/system/reboot
    server.on("/api/v1/system/reboot", HTTP_POST, [](AsyncWebServerRequest* request) {
        if (!isAuthorized(request)) {
            sendJsonError(request, 401, "UNAUTHORIZED", "Jeton Bearer requis");
            return;
        }
        request->send(200, "application/json", "{\"rebooting\":true,\"delay_ms\":1000}");
        vTaskDelay(pdMS_TO_TICKS(1000));
        ESP.restart();
    });

    // 12. Servir la PWA embarquée locale depuis LittleFS
    server.serveStatic("/", LittleFS, "/").setDefaultFile("index.html");
}
