#pragma once

#include <ESPAsyncWebServer.h>

void initWebSocket(AsyncWebServer& server);
void processWebSocketBroadcast();
