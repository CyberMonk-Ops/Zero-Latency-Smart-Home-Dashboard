#include <ESP8266WiFi.h>
#include <ESP8266WebServer.h>
#include <EEPROM.h>
#include <WiFiUdp.h>
#include <WiFiManager.h>

WiFiUDP udp;
const unsigned int localUdpPort = 4210;
char incomingPacket[255];

// =================================================================
// 1. TRANSHUMANIST HOTSPOT CONFIGURATION
// =================================================================


ESP8266WebServer server(80);

// --- REFACTORED SOVEREIGN GPIO MAPPING ---
const int RELAY_1 = 5;  // D1 (GPIO5)
const int RELAY_2 = 4;  // D2 (GPIO4)
const int RELAY_3 = 14; // D5 (GPIO14)
const int RELAY_4 = 12; // D6 (GPIO12)

const int OVERRIDE_BTN = 13; // D7 (GPIO13) - Tactile Safety Valve

// Permanent EEPROM Memory Addresses
const int ADDR_R1 = 0;
const int ADDR_R2 = 1;
const int ADDR_R3 = 2;
const int ADDR_R4 = 3;

// Active RAM State tracking
bool r1_active = false;
bool r2_active = false;
bool r3_active = false;
bool r4_active = false;

bool last_btn_state = HIGH;
unsigned long last_debounce_time = 0;
const unsigned long debounce_delay = 50;


unsigned long last_wifi_reconnect = 0;
// =================================================================
// 2. EEPROM SUBCONSCIOUS ETCHING & RECOVERY
// =================================================================
void commit_state_to_flash(int address, bool state) {
    byte current_byte = EEPROM.read(address);
    byte target_byte = state ? 1 : 0;
    
    if (current_byte != target_byte) {
        EEPROM.write(address, target_byte);
        EEPROM.commit();
        Serial.print("[EEPROM] Non-volatile byte etched to Address ");
        Serial.println(address);
    }
}

void update_physical_gate(int pin, bool make_active) {
    digitalWrite(pin, make_active ? LOW : HIGH);
}

// =================================================================
// 3. HTTP REST COMPOSITORS
// =================================================================
void emit_system_state() {
    String payload = "{\"status\":\"online\"";
    payload += ",\"r1\":" + String(r1_active ? "true" : "false");
    payload += ",\"r2\":" + String(r2_active ? "true" : "false");
    payload += ",\"r3\":" + String(r3_active ? "true" : "false");
    payload += ",\"r4\":" + String(r4_active ? "true" : "false");
    payload += "}";
    
    server.sendHeader("Connection", "close");
    server.send(200, "application/json", payload);
}

void handle_gate_actuation() {
    if (!server.hasArg("pin") || !server.hasArg("state")) {
        server.send(400, "application/json", "{\"error\":\"Void parameters\"}");
        return;
    }

    int target_gpio = server.arg("pin").toInt();
    bool target_state = (server.arg("state").toInt() == 1);

    switch(target_gpio) {
        case RELAY_1: 
            if (r1_active == target_state) break;
            r1_active = target_state;
            update_physical_gate(RELAY_1, r1_active);
            commit_state_to_flash(ADDR_R1, r1_active);
            break;
        case RELAY_2:  
            if (r2_active == target_state) break;
            r2_active = target_state; 
            update_physical_gate(RELAY_2, r2_active);
            commit_state_to_flash(ADDR_R2, r2_active);
            break;
        case RELAY_3: 
            if (r3_active == target_state) break;
            r3_active = target_state; 
            update_physical_gate(RELAY_3, r3_active);
            commit_state_to_flash(ADDR_R3, r3_active);
            break;
        case RELAY_4: 
            if (r4_active == target_state) break;
            r4_active = target_state; 
            update_physical_gate(RELAY_4, r4_active);
            commit_state_to_flash(ADDR_R4, r4_active);
            break;
        default:
            server.send(404, "application/json", "{\"error\":\"Unmapped GPIO\"}");
            return;
    }
    emit_system_state();
}

// =================================================================
// 4. HARDWARE IGNITION & BLACKOUT RECOVERY
// =================================================================
void setup() {
    Serial.begin(115200);
    delay(100);
    
    EEPROM.begin(512);
    Serial.println("\n[MATRIARCH CORTEX] Igniting Blackout-Proof Switchboard...");

    pinMode(RELAY_1, OUTPUT);
    pinMode(RELAY_2, OUTPUT);
    pinMode(RELAY_3, OUTPUT);
    pinMode(RELAY_4, OUTPUT);
    pinMode(OVERRIDE_BTN, INPUT_PULLUP);

    r1_active = (EEPROM.read(ADDR_R1) == 1);
    r2_active = (EEPROM.read(ADDR_R2) == 1);
    r3_active = (EEPROM.read(ADDR_R3) == 1);
    r4_active = (EEPROM.read(ADDR_R4) == 1);

    update_physical_gate(RELAY_1, r1_active);
    update_physical_gate(RELAY_2, r2_active);
    update_physical_gate(RELAY_3, r3_active);
    update_physical_gate(RELAY_4, r4_active);

    Serial.println("[EEPROM RECOVERY] Pre-blackout realities extracted:");
    Serial.printf("R1: %d | R2: %d | R3: %d | R4: %d\n", r1_active, r2_active, r3_active, r4_active);



    // =================================================================
    // THE CAPTIVE PORTAL ROUTING ENGINE
    // =================================================================
    WiFiManager wifiManager;
    
    // Uncomment the line below ONLY if you want to wipe the ESP's memory to test the portal
    // wifiManager.resetSettings(); 

    // Set a strict 60-second limit on the setup portal
    wifiManager.setConfigPortalTimeout(60); 
    
    Serial.println("\n[ROUTING] Initiating Sovereign Air-Bridge...");
    
    // Try to connect. If it fails, it opens the portal for 60 seconds, then gives up and moves on.
    wifiManager.autoConnect("CORTEX_SETUP");

    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("[AIR-BRIDGE SECURED] Assigned IP: " + WiFi.localIP().toString());
        // SINGLE VERIFIED LISTENER PORT ALLOCATION
        udp.begin(localUdpPort);
        Serial.printf("[DISCOVERY] UDP socket bound cleanly to Port %d\n", localUdpPort);
    } else {
        Serial.println("[WARN] Grid Offline. Matriarch Cortex running in Sovereign Physical Mode.");
    }



    server.on("/status", HTTP_GET, emit_system_state);
    server.on("/gate", HTTP_GET, handle_gate_actuation);
    server.begin();
}

// =================================================================
// 5. CONTINUOUS DAEMON & DISCOVERY WATCHDOG
// =================================================================
void loop() {
    server.handleClient();

    // --- BACKGROUND GRID RECOVERY DAEMON ---
    if (WiFi.status() != WL_CONNECTED) {
        if (millis() - last_wifi_reconnect > 15000) { // Every 15 seconds
            Serial.println("[NETWORK] Attempting silent background reconnect...");
            WiFi.begin(); // Tries to connect using credentials stored in flash
            last_wifi_reconnect = millis();
        }
    }



    // --- PRODUCTION UDP INTERCEPT DECK ---
    int packetSize = udp.parsePacket();
    if (packetSize) {
        int len = udp.read(incomingPacket, 255);
        if (len > 0) incomingPacket[len] = 0;
        
        if (strcmp(incomingPacket, "CORTEX_WHOAMI") == 0) {
            Serial.printf("[DISCOVERY] Intercepted broadcast from %s. Returning identity...\n", udp.remoteIP().toString().c_str());

            String hardware_identity = "MAIN_LIVINGROOM"; 
            String reply = "CORTEX_NODE:" + hardware_identity + "|" + WiFi.localIP().toString();

            
            // String reply = "CORTEX_NODE_IP:" + WiFi.localIP().toString();
            
            // PRODUCTION PATCH: Force raw payload array directly back to dedicated source UDP listener port
            udp.beginPacket(udp.remoteIP(), udp.remotePort());
            udp.write((const uint8_t*)reply.c_str(), reply.length());
            udp.endPacket();
        }
    }
    
    delay(2); // Yield TCP Core

    // --- TACTILE OVERRIDE EVALUATION ---
    bool reading = digitalRead(OVERRIDE_BTN);
    if (reading != last_btn_state) {
        last_debounce_time = millis();
    }

    if ((millis() - last_debounce_time) > debounce_delay) {
        if (reading == LOW) { 
            r1_active = !r1_active;
            update_physical_gate(RELAY_1, r1_active);
            commit_state_to_flash(ADDR_R1, r1_active);
            
            Serial.print("[OVERRIDE] Relay 1 toggled locally. Permanent State: ");
            Serial.println(r1_active);
            while(digitalRead(OVERRIDE_BTN) == LOW) { 
                server.handleClient();
                delay(2);
            }
        }
    }
    last_btn_state = reading;
}

