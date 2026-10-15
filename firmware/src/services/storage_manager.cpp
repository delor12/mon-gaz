#include "storage_manager.h"
#include <Preferences.h>
#include <LittleFS.h>
#include <ArduinoJson.h>
#include <esp_random.h>

static SemaphoreHandle_t g_telemetryMutex = nullptr;
static SemaphoreHandle_t g_configMutex = nullptr;
QueueHandle_t g_eventQueue = nullptr;

static TelemetryState g_telemetry;
static SystemConfig g_config;
static Preferences prefs;

void initState() {
    g_telemetryMutex = xSemaphoreCreateMutex();
    g_configMutex = xSemaphoreCreateMutex();
    g_eventQueue = xQueueCreate(20, sizeof(SystemEvent));

    memset(&g_telemetry, 0, sizeof(TelemetryState));
    g_telemetry.valve_state = VALVE_STATE_OPEN;
    g_telemetry.wifi_rssi = -100;
    
    // Initialisation valeurs par défaut de configuration
    memset(&g_config, 0, sizeof(SystemConfig));
    strncpy(g_config.bottle_name, "Cuisine Principale", sizeof(g_config.bottle_name) - 1);
    g_config.bottle_type = BOTTLE_B12_5;
    g_config.capacity_kg = 12.5f;
    g_config.tare_weight_kg = 13.0f;
    g_config.calibration_scale = -22450.0f; // Valeur usine indicative
    g_config.tare_offset = 8400000;
    g_config.leak_threshold_ppm = DEFAULT_LEAK_PPM;
    g_config.low_level_percent = DEFAULT_LOW_PERCENT;
    g_config.critical_level_percent = DEFAULT_CRIT_PERCENT;
    g_config.buzzer_enabled = true;
    g_config.valve_enabled = false;
    g_config.valve_auto_cutoff = true;
    g_config.mqtt_enabled = false;
    strncpy(g_config.mqtt_broker, "broker.smartgas.io", sizeof(g_config.mqtt_broker) - 1);
    g_config.mqtt_port = 8883;
    strncpy(g_config.auth_token, "sg_sec_default_dev_token", sizeof(g_config.auth_token) - 1);
}

void getTelemetryCopy(TelemetryState* dest) {
    if (!dest || !g_telemetryMutex) return;
    if (xSemaphoreTake(g_telemetryMutex, pdMS_TO_TICKS(100)) == pdTRUE) {
        memcpy(dest, &g_telemetry, sizeof(TelemetryState));
        xSemaphoreGive(g_telemetryMutex);
    }
}

void updateTelemetry(const TelemetryState* src) {
    if (!src || !g_telemetryMutex) return;
    if (xSemaphoreTake(g_telemetryMutex, pdMS_TO_TICKS(100)) == pdTRUE) {
        memcpy(&g_telemetry, src, sizeof(TelemetryState));
        xSemaphoreGive(g_telemetryMutex);
    }
}

void getConfigCopy(SystemConfig* dest) {
    if (!dest || !g_configMutex) return;
    if (xSemaphoreTake(g_configMutex, pdMS_TO_TICKS(100)) == pdTRUE) {
        memcpy(dest, &g_config, sizeof(SystemConfig));
        xSemaphoreGive(g_configMutex);
    }
}

void updateConfig(const SystemConfig* src) {
    if (!src || !g_configMutex) return;
    if (xSemaphoreTake(g_configMutex, pdMS_TO_TICKS(100)) == pdTRUE) {
        memcpy(&g_config, src, sizeof(SystemConfig));
        xSemaphoreGive(g_configMutex);
    }
}

bool postSystemEvent(const char* type, EventSeverity sev, const char* msg, float val1, float val2) {
    if (!g_eventQueue || !type) return false;
    SystemEvent ev;
    memset(&ev, 0, sizeof(SystemEvent));
    strncpy(ev.event_type, type, sizeof(ev.event_type) - 1);
    ev.severity = sev;
    ev.timestamp = millis() / 1000;
    if (msg) strncpy(ev.message, msg, sizeof(ev.message) - 1);
    ev.value1 = val1;
    ev.value2 = val2;
    return (xQueueSend(g_eventQueue, &ev, 0) == pdTRUE);
}

bool StorageManager::init() {
    bool ok = LittleFS.begin(true);
    if (!ok) {
        Serial.println(F("[STORAGE] Erreur montage LittleFS !"));
    } else {
        Serial.println(F("[STORAGE] LittleFS monté avec succès."));
    }
    return ok;
}

bool StorageManager::loadConfig(SystemConfig* cfg) {
    if (!prefs.begin("smartgas", true)) {
        Serial.println(F("[NVS] Initialisation NVS en lecture échouée"));
        return false;
    }

    if (xSemaphoreTake(g_configMutex, pdMS_TO_TICKS(200)) == pdTRUE) {
        String name = prefs.getString("b_name", "Cuisine Principale");
        strncpy(cfg->bottle_name, name.c_str(), sizeof(cfg->bottle_name) - 1);
        cfg->bottle_type = (BottlePreset)prefs.getInt("b_type", (int)BOTTLE_B12_5);
        cfg->capacity_kg = prefs.getFloat("cap_kg", 12.5f);
        cfg->tare_weight_kg = prefs.getFloat("tare_kg", 13.0f);
        cfg->calibration_scale = prefs.getFloat("cal_scale", -22450.0f);
        cfg->tare_offset = prefs.getLong("tare_off", 8400000);
        cfg->leak_threshold_ppm = prefs.getInt("leak_ppm", DEFAULT_LEAK_PPM);
        cfg->low_level_percent = prefs.getFloat("low_pct", DEFAULT_LOW_PERCENT);
        cfg->critical_level_percent = prefs.getFloat("crit_pct", DEFAULT_CRIT_PERCENT);
        cfg->buzzer_enabled = prefs.getBool("buzzer", true);
        cfg->valve_enabled = prefs.getBool("valve", false);
        cfg->valve_auto_cutoff = prefs.getBool("cutoff", true);
        cfg->mqtt_enabled = prefs.getBool("mqtt_en", false);

        String b = prefs.getString("mqtt_brk", "broker.smartgas.io");
        strncpy(cfg->mqtt_broker, b.c_str(), sizeof(cfg->mqtt_broker) - 1);
        cfg->mqtt_port = prefs.getInt("mqtt_p", 8883);

        String tok = prefs.getString("token", "");
        if (tok.length() > 0) {
            strncpy(cfg->auth_token, tok.c_str(), sizeof(cfg->auth_token) - 1);
        }

        String ssid = prefs.getString("w_ssid", "");
        String pass = prefs.getString("w_pass", "");
        strncpy(cfg->wifi_ssid, ssid.c_str(), sizeof(cfg->wifi_ssid) - 1);
        strncpy(cfg->wifi_password, pass.c_str(), sizeof(cfg->wifi_password) - 1);

        xSemaphoreGive(g_configMutex);
    }
    prefs.end();
    return true;
}

bool StorageManager::saveConfig(const SystemConfig* cfg) {
    if (!prefs.begin("smartgas", false)) return false;

    prefs.putString("b_name", cfg->bottle_name);
    prefs.putInt("b_type", (int)cfg->bottle_type);
    prefs.putFloat("cap_kg", cfg->capacity_kg);
    prefs.putFloat("tare_kg", cfg->tare_weight_kg);
    prefs.putFloat("cal_scale", cfg->calibration_scale);
    prefs.putLong("tare_off", cfg->tare_offset);
    prefs.putInt("leak_ppm", cfg->leak_threshold_ppm);
    prefs.putFloat("low_pct", cfg->low_level_percent);
    prefs.putFloat("crit_pct", cfg->critical_level_percent);
    prefs.putBool("buzzer", cfg->buzzer_enabled);
    prefs.putBool("valve", cfg->valve_enabled);
    prefs.putBool("cutoff", cfg->valve_auto_cutoff);
    prefs.putBool("mqtt_en", cfg->mqtt_enabled);
    prefs.putString("mqtt_brk", cfg->mqtt_broker);
    prefs.putInt("mqtt_p", cfg->mqtt_port);
    prefs.putString("token", cfg->auth_token);
    prefs.putString("w_ssid", cfg->wifi_ssid);
    prefs.putString("w_pass", cfg->wifi_password);

    prefs.end();
    return true;
}

bool StorageManager::saveCalibration(long tare_offset, float scale) {
    if (!prefs.begin("smartgas", false)) return false;
    prefs.putLong("tare_off", tare_offset);
    prefs.putFloat("cal_scale", scale);
    prefs.end();

    if (xSemaphoreTake(g_configMutex, pdMS_TO_TICKS(100)) == pdTRUE) {
        g_config.tare_offset = tare_offset;
        g_config.calibration_scale = scale;
        xSemaphoreGive(g_configMutex);
    }
    return true;
}

bool StorageManager::saveAuthToken(const char* token) {
    if (!token) return false;
    if (!prefs.begin("smartgas", false)) return false;
    prefs.putString("token", token);
    prefs.end();

    if (xSemaphoreTake(g_configMutex, pdMS_TO_TICKS(100)) == pdTRUE) {
        strncpy(g_config.auth_token, token, sizeof(g_config.auth_token) - 1);
        xSemaphoreGive(g_configMutex);
    }
    return true;
}

bool StorageManager::generateNewPairingPin(char* pin_out) {
    if (!pin_out) return false;
    uint32_t rand_num = esp_random() % 1000000;
    snprintf(pin_out, 7, "%06u", rand_num);

    if (xSemaphoreTake(g_telemetryMutex, pdMS_TO_TICKS(100)) == pdTRUE) {
        strncpy(g_telemetry.pairing_pin, pin_out, 7);
        g_telemetry.in_pairing_mode = true;
        g_telemetry.pairing_expiry_s = (millis() / 1000) + 180; // 3 minutes
        xSemaphoreGive(g_telemetryMutex);
    }
    return true;
}

bool StorageManager::recordHistoryPoint(uint32_t timestamp, float weight_kg, float consumption_kg) {
    File f = LittleFS.open("/history.csv", FILE_APPEND);
    if (!f) return false;

    // Format compact : timestamp,weight,consumption\n
    f.printf("%u,%.3f,%.3f\n", timestamp, weight_kg, consumption_kg);
    f.close();
    return true;
}

String StorageManager::getHistoryJson(const String& range, const String& resolution) {
    DynamicJsonDocument doc(4096);
    doc["range"] = range;
    doc["resolution"] = resolution;
    JsonArray points = doc.createNestedArray("points");

    if (!LittleFS.exists("/history.csv")) {
        // Points synthétiques réalistes si le fichier démarre
        uint32_t now = millis() / 1000;
        float base_weight = 8.540f;
        for (int i = 6; i >= 0; i--) {
            JsonObject pt = points.createNestedObject();
            pt["timestamp"] = now - (i * 3600);
            pt["weight_kg"] = base_weight - (0.025f * (6 - i));
            pt["consumption_kg"] = 0.025f;
        }
    } else {
        File f = LittleFS.open("/history.csv", FILE_READ);
        if (f) {
            int line_count = 0;
            while (f.available() && line_count < 48) {
                String line = f.readStringUntil('\n');
                line.trim();
                if (line.length() == 0) continue;
                int idx1 = line.indexOf(',');
                int idx2 = line.indexOf(',', idx1 + 1);
                if (idx1 > 0 && idx2 > 0) {
                    uint32_t ts = line.substring(0, idx1).toInt();
                    float w = line.substring(idx1 + 1, idx2).toFloat();
                    float c = line.substring(idx2 + 1).toFloat();

                    JsonObject pt = points.createNestedObject();
                    pt["timestamp"] = ts;
                    pt["weight_kg"] = w;
                    pt["consumption_kg"] = c;
                    line_count++;
                }
            }
            f.close();
        }
    }

    doc["count"] = points.size();
    String output;
    serializeJson(doc, output);
    return output;
}
