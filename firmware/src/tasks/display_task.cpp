#include "display_task.h"
#include "config.h"
#include "state.h"
#include <TFT_eSPI.h>

static TaskHandle_t s_displayTaskHandle = nullptr;
static TFT_eSPI tft = TFT_eSPI();

// Conversion de la palette de couleurs SmartGas en RGB565 pour TFT
#define COLOR_BG_DEEP       tft.color565(6, 26, 69)     // #061A45
#define COLOR_BG_SURFACE    tft.color565(10, 42, 107)   // #0A2A6B
#define COLOR_GOLD          tft.color565(212, 175, 55)  // #D4AF37
#define COLOR_GOLD_LIGHT    tft.color565(245, 215, 110) // #F5D76E
#define COLOR_YELLOW        tft.color565(255, 214, 10)  // #FFD60A
#define COLOR_TEXT_WHITE    tft.color565(245, 247, 250) // #F5F7FA
#define COLOR_ALERT_RED     tft.color565(229, 56, 59)   // #E5383B
#define COLOR_GREEN_OK      tft.color565(16, 185, 129)  // #10B981
#define COLOR_GRAY_MUTED    tft.color565(108, 130, 166) // #6C82A6

static void drawHeader(bool wifi_connected, int rssi) {
    tft.fillRect(0, 0, 240, 36, COLOR_BG_SURFACE);
    tft.drawFastHLine(0, 36, 240, COLOR_GOLD);

    // Titre SMART GAZ
    tft.setTextColor(COLOR_GOLD, COLOR_BG_SURFACE);
    tft.setTextSize(2);
    tft.setCursor(8, 10);
    tft.print("SMART GAZ");

    // Indicateur Wi-Fi
    tft.setTextSize(1);
    if (wifi_connected) {
        tft.setTextColor(COLOR_GREEN_OK, COLOR_BG_SURFACE);
        tft.setCursor(180, 8);
        tft.print("Wi-Fi OK");
        tft.setCursor(180, 20);
        tft.printf("%d dBm", rssi);
    } else {
        tft.setTextColor(COLOR_ALERT_RED, COLOR_BG_SURFACE);
        tft.setCursor(170, 14);
        tft.print("HORS LIGNE");
    }
}

static void drawNormalScreen(const TelemetryState& tel) {
    // 1. En-tête
    bool wifi_ok = (tel.wifi_rssi > -95 && tel.wifi_rssi != 0);
    drawHeader(wifi_ok, tel.wifi_rssi);

    // 2. Zone Poids Actuel
    tft.fillRect(10, 46, 220, 110, COLOR_BG_SURFACE);
    tft.drawRoundRect(10, 46, 220, 110, 8, COLOR_GOLD);

    tft.setTextColor(COLOR_GOLD_LIGHT, COLOR_BG_SURFACE);
    tft.setTextSize(1);
    tft.setCursor(20, 56);
    tft.print("POIDS ACTUEL DE GAZ (NET)");

    // Grande valeur numérique
    tft.setTextColor(COLOR_TEXT_WHITE, COLOR_BG_SURFACE);
    tft.setTextSize(4);
    tft.setCursor(25, 80);
    tft.printf("%0.2f", tel.weight_kg);

    tft.setTextSize(2);
    tft.setTextColor(COLOR_YELLOW, COLOR_BG_SURFACE);
    tft.setCursor(170, 95);
    tft.print("kg");

    tft.setTextSize(1);
    tft.setTextColor(COLOR_GRAY_MUTED, COLOR_BG_SURFACE);
    tft.setCursor(20, 134);
    tft.printf("Brut: %0.2f kg | T: %0.1f C", tel.gross_weight_kg, tel.temperature_c);

    // 3. Barre de Niveau Restant
    tft.setTextColor(COLOR_TEXT_WHITE, COLOR_BG_DEEP);
    tft.setTextSize(1);
    tft.setCursor(12, 168);
    tft.printf("NIVEAU DE LA BOUTEILLE : %0.1f %%", tel.level_percent);

    // Cadre de la barre
    int bar_x = 10, bar_y = 184, bar_w = 220, bar_h = 24;
    tft.drawRoundRect(bar_x, bar_y, bar_w, bar_h, 4, COLOR_GOLD);
    tft.fillRect(bar_x + 2, bar_y + 2, bar_w - 4, bar_h - 4, COLOR_BG_DEEP);

    // Remplissage proportionnel
    int fill_w = (int)(((bar_w - 4) * tel.level_percent) / 100.0f);
    if (fill_w > bar_w - 4) fill_w = bar_w - 4;
    if (fill_w < 0) fill_w = 0;

    uint16_t fill_color = COLOR_GOLD;
    if (tel.level_percent <= 15.0f) fill_color = COLOR_YELLOW;
    if (tel.level_percent <= 5.0f) fill_color = COLOR_ALERT_RED;

    if (fill_w > 0) {
        tft.fillRect(bar_x + 2, bar_y + 2, fill_w, bar_h - 4, fill_color);
    }

    // 4. État du Capteur de Gaz MQ
    tft.fillRect(10, 220, 220, 85, COLOR_BG_SURFACE);
    tft.drawRoundRect(10, 220, 220, 85, 8, COLOR_GOLD);

    tft.setTextColor(COLOR_GOLD_LIGHT, COLOR_BG_SURFACE);
    tft.setTextSize(1);
    tft.setCursor(20, 230);
    tft.print("SURVEILLANCE GAZ GPL (MQ-6)");

    tft.setCursor(20, 252);
    tft.setTextColor(COLOR_TEXT_WHITE, COLOR_BG_SURFACE);
    tft.setTextSize(2);
    tft.printf("%d ppm", tel.gas_ppm);

    tft.setTextSize(1);
    if (tel.sensor_fault) {
        tft.setTextColor(COLOR_YELLOW, COLOR_BG_SURFACE);
        tft.setCursor(130, 256);
        tft.print("[CHAUFFAGE]");
    } else {
        tft.setTextColor(COLOR_GREEN_OK, COLOR_BG_SURFACE);
        tft.setCursor(130, 256);
        tft.print("[NORMAL]");
    }

    tft.setTextColor(COLOR_GRAY_MUTED, COLOR_BG_SURFACE);
    tft.setCursor(20, 280);
    const char* v_str = (tel.valve_state == VALVE_STATE_OPEN) ? "OUVERTE" : 
                        (tel.valve_state == VALVE_STATE_CLOSED) ? "FERMEE" : "DESACTIVEE";
    tft.printf("Vanne: %s | Uptime: %u s", v_str, tel.uptime_s);
}

static void drawPairingScreen(const char* pin, uint32_t remaining_s) {
    tft.fillScreen(COLOR_BG_DEEP);
    tft.drawRoundRect(8, 8, 224, 304, 12, COLOR_GOLD);

    tft.setTextColor(COLOR_GOLD, COLOR_BG_DEEP);
    tft.setTextSize(2);
    tft.setCursor(35, 30);
    tft.print("APPAIRAGE");

    tft.setTextColor(COLOR_TEXT_WHITE, COLOR_BG_DEEP);
    tft.setTextSize(1);
    tft.setCursor(20, 70);
    tft.print("Saisissez ce code PIN dans");
    tft.setCursor(20, 86);
    tft.print("l'application mobile/web :");

    // Boîte encadrant le PIN
    tft.fillRect(25, 120, 190, 60, COLOR_BG_SURFACE);
    tft.drawRoundRect(25, 120, 190, 60, 8, COLOR_YELLOW);

    tft.setTextColor(COLOR_YELLOW, COLOR_BG_SURFACE);
    tft.setTextSize(4);
    tft.setCursor(45, 135);
    tft.print(pin);

    tft.setTextColor(COLOR_GRAY_MUTED, COLOR_BG_DEEP);
    tft.setTextSize(1);
    tft.setCursor(30, 210);
    tft.printf("Expire dans : %u secondes", remaining_s);

    tft.setTextColor(COLOR_GOLD_LIGHT, COLOR_BG_DEEP);
    tft.setCursor(20, 250);
    tft.print("Connectez-vous au reseau Wi-Fi");
    tft.setCursor(20, 265);
    tft.print("ou au point 'SmartGas-Setup'");
}

static void drawCriticalLeakScreen(int ppm, bool phase) {
    uint16_t bg = phase ? COLOR_ALERT_RED : COLOR_BG_DEEP;
    uint16_t fg = phase ? COLOR_TEXT_WHITE : COLOR_ALERT_RED;

    tft.fillScreen(bg);
    tft.drawRect(4, 4, 232, 312, fg);
    tft.drawRect(6, 6, 228, 308, fg);

    tft.setTextColor(fg, bg);
    tft.setTextSize(3);
    tft.setCursor(20, 30);
    tft.print("! DANGER !");

    tft.setTextSize(2);
    tft.setCursor(15, 80);
    tft.print("FUITE DE GAZ");

    tft.setTextSize(2);
    tft.setCursor(25, 115);
    tft.printf("%d PPM", ppm);

    tft.setTextSize(1);
    tft.setCursor(15, 165);
    tft.print("1. NE TOUCHEZ A AUCUN");
    tft.setCursor(15, 180);
    tft.print("   INTERRUPTEUR NI FEU");

    tft.setCursor(15, 210);
    tft.print("2. FERMEZ LE ROBINET");
    tft.setCursor(15, 225);
    tft.print("   DE LA BOUTEILLE");

    tft.setCursor(15, 255);
    tft.print("3. OUVREZ GRANDEMENT");
    tft.setCursor(15, 270);
    tft.print("   PORTES ET FENETRES");
}

static void displayTaskLoop(void* pvParameters) {
    (void)pvParameters;

    // Initialisation du contrôleur d'affichage ST7789/ILI9341
    tft.init();
    tft.setRotation(0); // Orientation portrait 240x320
    tft.fillScreen(COLOR_BG_DEEP);

    // Écran d'accueil de démarrage
    tft.setTextColor(COLOR_GOLD, COLOR_BG_DEEP);
    tft.setTextSize(2);
    tft.setCursor(45, 120);
    tft.print("SMART GAS");
    tft.setTextColor(COLOR_TEXT_WHITE, COLOR_BG_DEEP);
    tft.setTextSize(1);
    tft.setCursor(55, 150);
    tft.print("Initialisation v1.0...");
    vTaskDelay(pdMS_TO_TICKS(1500));
    tft.fillScreen(COLOR_BG_DEEP);

    bool emergency_flash_phase = false;

    for (;;) {
        uint32_t now_s = millis() / 1000;
        TelemetryState tel;
        getTelemetryCopy(&tel);

        if (tel.leak) {
            // Mode alerte critique plein écran
            emergency_flash_phase = !emergency_flash_phase;
            drawCriticalLeakScreen(tel.gas_ppm, emergency_flash_phase);
            vTaskDelay(pdMS_TO_TICKS(300));
        } else if (tel.in_pairing_mode) {
            // Mode appairage PIN
            uint32_t remaining = (tel.pairing_expiry_s > now_s) ? (tel.pairing_expiry_s - now_s) : 0;
            if (remaining == 0) {
                tel.in_pairing_mode = false;
                updateTelemetry(&tel);
                tft.fillScreen(COLOR_BG_DEEP);
            } else {
                drawPairingScreen(tel.pairing_pin, remaining);
                vTaskDelay(pdMS_TO_TICKS(500));
            }
        } else {
            // Écran standard de surveillance
            drawNormalScreen(tel);
            vTaskDelay(pdMS_TO_TICKS(500)); // Rafraîchissement 2 Hz fluide
        }
    }
}

void startDisplayTask() {
    xTaskCreatePinnedToCore(
        displayTaskLoop,
        "DisplayTask",
        4096,
        nullptr,
        2, // Priorité normale
        &s_displayTaskHandle,
        0  // Épinglé sur Core 0
    );
}
