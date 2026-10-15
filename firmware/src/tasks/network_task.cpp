#include "network_task.h"
#include "config.h"
#include "state.h"
#include "webserver/api_routes.h"
#include "webserver/ws_handler.h"
#include <WiFi.h>
#include <ESPmDNS.h>
#include <ArduinoOTA.h>
#include <DNSServer.h>
#include <AsyncTCP.h>
#include <ESPAsyncWebServer.h>

static TaskHandle_t s_networkTaskHandle = nullptr;
static AsyncWebServer s_server(80);
static DNSServer s_dnsServer;
static bool s_ap_mode = false;

static void setupWiFi(const SystemConfig& cfg) {
    if (strlen(cfg.wifi_ssid) > 0) {
        Serial.printf("[WIFI] Connexion a %s...\n", cfg.wifi_ssid);
        WiFi.mode(WIFI_STA);
        WiFi.begin(cfg.wifi_ssid, cfg.wifi_password);

        int attempts = 0;
        while (WiFi.status() != WL_CONNECTED && attempts < 20) {
            vTaskDelay(pdMS_TO_TICKS(500));
            Serial.print(".");
            attempts++;
        }
        Serial.println();
    }

    if (WiFi.status() == WL_CONNECTED) {
        s_ap_mode = false;
        Serial.printf("[WIFI] Connecte ! IP: %s | RSSI: %d dBm\n", 
                      WiFi.localIP().toString().c_str(), WiFi.RSSI());
        
        // Démarrage mDNS (smartgas.local)
        if (MDNS.begin(SMARTGAS_MDNS_HOST)) {
            MDNS.addService("smartgas", "tcp", 80);
            MDNS.addServiceTxt("smartgas", "tcp", "version", SMARTGAS_FIRMWARE_VERSION);
            MDNS.addServiceTxt("smartgas", "tcp", "device", "ESP32-SMARTGAS-8A4F");
            Serial.println(F("[mDNS] Service actif sur http://smartgas.local"));
        }
    } else {
        // Fallback en Point d'Accès avec portail captif
        s_ap_mode = true;
        Serial.println(F("[WIFI] Échec Wi-Fi STA -> Démarrage AP 'SmartGas-Setup'"));
        WiFi.mode(WIFI_AP);
        WiFi.softAP(SMARTGAS_AP_SSID_PREFIX, "smartgas123");
        IPAddress apIP(192, 168, 4, 1);
        WiFi.softAPConfig(apIP, apIP, IPAddress(255, 255, 255, 0));

        s_dnsServer.start(53, "*", apIP); // Redirige toutes les requêtes DNS
        Serial.printf("[WIFI] AP actif sur IP: %s (SSID: %s)\n", 
                      WiFi.softAPIP().toString().c_str(), SMARTGAS_AP_SSID_PREFIX);
    }
}

static void setupOTA() {
    ArduinoOTA.setHostname("smartgas-esp32");
    ArduinoOTA.setPassword("smartgas-ota-pass");
    ArduinoOTA.onStart([]() {
        Serial.println(F("[OTA] Début mise à jour firmware..."));
    });
    ArduinoOTA.onEnd([]() {
        Serial.println(F("\n[OTA] Mise à jour terminée ! Redémarrage..."));
    });
    ArduinoOTA.begin();
}

static void networkTaskLoop(void* pvParameters) {
    (void)pvParameters;

    SystemConfig cfg;
    getConfigCopy(&cfg);

    setupWiFi(cfg);

    // Initialisation Serveur Web, WebSocket et Routes
    DefaultHeaders::Instance().addHeader("Access-Control-Allow-Origin", "*");
    DefaultHeaders::Instance().addHeader("Access-Control-Allow-Methods", "GET, POST, PUT, OPTIONS");
    DefaultHeaders::Instance().addHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");

    initWebSocket(s_server);
    registerApiRoutes(s_server);
    s_server.begin();
    Serial.println(F("[HTTP] Serveur Web démarré sur port 80"));

    setupOTA();

    for (;;) {
        // Traitement portail captif si mode AP
        if (s_ap_mode) {
            s_dnsServer.processNextRequest();
        }

        // Tâches OTA
        ArduinoOTA.handle();

        // Émission télémétrique périodique et événements WebSocket
        processWebSocketBroadcast();

        // Mise à jour périodique du RSSI
        TelemetryState tel;
        getTelemetryCopy(&tel);
        tel.wifi_rssi = (WiFi.status() == WL_CONNECTED) ? WiFi.RSSI() : 0;
        updateTelemetry(&tel);

        vTaskDelay(pdMS_TO_TICKS(50));
    }
}

void startNetworkTask() {
    xTaskCreatePinnedToCore(
        networkTaskLoop,
        "NetworkTask",
        8192,
        nullptr,
        2, // Priorité normale
        &s_networkTaskHandle,
        0  // Épinglé sur Core 0
    );
}
