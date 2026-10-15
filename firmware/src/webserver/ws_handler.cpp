#include "ws_handler.h"
#include "state.h"
#include <ArduinoJson.h>

static AsyncWebSocket ws("/ws");
static uint32_t s_last_broadcast_ms = 0;

static void onWsEvent(AsyncWebSocket* server, AsyncWebSocketClient* client,
                      AwsEventType type, void* arg, uint8_t* data, size_t len) {
    (void)server;
    (void)arg;
    switch (type) {
        case WS_EVT_CONNECT:
            Serial.printf("[WS] Client #%u connecté depuis %s\n", client->id(), client->remoteIP().toString().c_str());
            break;
        case WS_EVT_DISCONNECT:
            Serial.printf("[WS] Client #%u déconnecté\n", client->id());
            break;
        case WS_EVT_DATA: {
            AwsFrameInfo* info = (AwsFrameInfo*)arg;
            if (info->final && info->index == 0 && info->len == len && info->opcode == WS_TEXT) {
                data[len] = 0;
                String msg = (char*)data;
                if (msg.indexOf("ping") >= 0) {
                    client->text("{\"type\":\"pong\"}");
                }
            }
            break;
        }
        default:
            break;
    }
}

void initWebSocket(AsyncWebServer& server) {
    ws.onEvent(onWsEvent);
    server.addHandler(&ws);
}

void processWebSocketBroadcast() {
    uint32_t now = millis();

    // 1. Dépilement et diffusion des événements asynchrones prioritaires
    if (g_eventQueue) {
        SystemEvent ev;
        while (xQueueReceive(g_eventQueue, &ev, 0) == pdTRUE) {
            if (ws.count() > 0) {
                StaticJsonDocument<512> doc;
                doc["type"] = "event";
                doc["event"] = ev.event_type;
                doc["severity"] = (ev.severity == SEV_CRITICAL) ? "CRITICAL" : 
                                  (ev.severity == SEV_WARNING)  ? "WARNING" : "INFO";
                doc["timestamp"] = ev.timestamp;
                JsonObject d = doc.createNestedObject("data");
                d["message"] = ev.message;
                d["value1"] = ev.value1;
                d["value2"] = ev.value2;

                String output;
                serializeJson(doc, output);
                ws.textAll(output);
            }
        }
    }

    // 2. Télémétrie périodique 1 Hz (1000ms)
    if (now - s_last_broadcast_ms >= 1000) {
        s_last_broadcast_ms = now;

        if (ws.count() == 0) return; // Pas de client connecté

        TelemetryState tel;
        getTelemetryCopy(&tel);

        StaticJsonDocument<512> doc;
        doc["type"] = "telemetry";
        JsonObject d = doc.createNestedObject("data");
        d["weight_kg"] = tel.weight_kg;
        d["gross_weight_kg"] = tel.gross_weight_kg;
        d["level_percent"] = tel.level_percent;
        d["gas_ppm"] = tel.gas_ppm;
        d["leak"] = tel.leak;
        d["temperature_c"] = tel.temperature_c;
        d["humidity_percent"] = tel.humidity_percent;
        d["valve_state"] = (tel.valve_state == VALVE_STATE_OPEN) ? "OPEN" :
                           (tel.valve_state == VALVE_STATE_CLOSED) ? "CLOSED" : "DISABLED";
        d["buzzer_muted"] = tel.buzzer_muted;
        d["sensor_fault"] = tel.sensor_fault;
        d["uptime_s"] = tel.uptime_s;
        d["timestamp"] = tel.timestamp;

        String output;
        serializeJson(doc, output);
        ws.textAll(output);
        ws.cleanupClients();
    }
}
