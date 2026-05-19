Most DIY IoT dashboards suffer from a critical flaw: latency. You press a button on your screen, and you wait three seconds for the network to catch up.
Welcome to the Sovereign Gateway.
Built natively in Godot 4, this premium UI kit utilizes an Optimistic Asynchronous Network Stack. The millisecond you touch the glass, the UI reacts. It is a complete, deployable frontend designed specifically for ESP8266/ESP32 microcontrollers.
Titanium-Grade Features:
Zero-Latency Optimistic UI: Instant visual feedback backed by background HTTP verification. No ghosting. No tap-spamming.
Dynamic Multi-Node UDP Mapping: Drop the provided C++ firmware onto your microcontrollers, and the Godot app will automatically discover them on your subnet, populating a seamless dropdown menu for instant room switching.
Cyberpunk Emissive Post-Processing: Hardware-accelerated glow effects on a clean, industrial pixel-art aesthetic.
Captive Portal Firmware Included: Stop hardcoding your WiFi passwords. The included C++ framework turns your ESP into an access point if the grid goes down, allowing seamless remote network configuration.
Flash the ESP8266_Firmware.ino to your board. (Hardcode your hardware_identity string first so Godot knows what room it is).
Connect to the CORTEX_SETUP WiFi network to pass your router credentials.

<img width="1080" height="2400" alt="1000040245" src="https://github.com/user-attachments/assets/89143b11-9961-48a7-a1b6-7b35f5798d47" />
