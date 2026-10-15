#pragma once

#include "state.h"

// Gestionnaire de persistance NVS et LittleFS
class StorageManager {
public:
    static bool init();
    static bool loadConfig(SystemConfig* config);
    static bool saveConfig(const SystemConfig* config);
    static bool saveCalibration(long tare_offset, float scale);
    static bool saveAuthToken(const char* token);
    static bool generateNewPairingPin(char* pin_out);

    // Historique LittleFS
    static bool recordHistoryPoint(uint32_t timestamp, float weight_kg, float consumption_kg);
    static String getHistoryJson(const String& range, const String& resolution);
};
