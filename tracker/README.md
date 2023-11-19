# Tracker

Our tracking system utilizes an ESP32 to gather and transmit data to our server.

# Hardware
- ESP32
- NEO-6M
- SIM800L (Optional, for using mobile data instead of WiFi; note that this feature is not yet implemented, but it should be easy to add)

# Building
## Prerequistis
Install the [TinyGPSPlus](https://github.com/mikalhart/TinyGPSPlus/tree/master) library.

Next, navigate to the code and make the following modifications:
``` c++
#define WIFI_SSID "WIFI_NAME"
#define WIFI_PSK "WIFI_PASSWORD"
#define SERVER_IP "https://192.168.178.90"
```
Adjust these values according to your specific parameters.