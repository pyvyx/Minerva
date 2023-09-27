#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>

#include <TinyGPS++.h>
#include <HardwareSerial.h>

#define WIFI_SSID "FRITZ!Box 7330"
#define WIFI_PSK  "04885702616868858006"

HardwareSerial SerialGPS(2);

void setup()
{
    Serial.begin(115200);
    delay(3000); // wait for the monitor to reconnect after uploading.
    SerialGPS.begin(9600, SERIAL_8N1, 16, 17);

    Serial.println("Setting up WiFi");
    WiFi.begin(WIFI_SSID, WIFI_PSK);
    while (WiFi.status() != WL_CONNECTED)
    {
        Serial.print(".");
        delay(500);
    }

    Serial.print("Connected. IP=");
    Serial.println(WiFi.localIP());
    //HTTPClient http;
    //http.begin("https://www.google.de");
    //int httpResponseCode = http.GET();
    //if (httpResponseCode>0) {
    //    Serial.print("HTTP Response code: ");
    //    Serial.println(httpResponseCode);
    //    String payload = http.getString();
    //    Serial.println(payload);
    //  }
    //  else {
    //    Serial.print("Error code: ");
    //    Serial.println(httpResponseCode);
    //  }
    //http.end();
}

void SendData(double lat, double lng, double alt, double kmh)
{
    /*
        Structure: "lat,lng,alt,kmh"
    */
    String buffer;
    buffer.reserve(46);
    buffer += String(lat, 8) + ',';
    buffer += String(lng, 8) + ',';
    buffer += String(alt, 8) + ',';
    buffer += String(kmh, 8);
    Serial.printf("Buffer: %s\n", buffer.c_str());
}


void loop()
{
    static TinyGPSPlus gps;
    static size_t locCount = 0;
    static size_t altCount = 0;
    static size_t kmhCount = 0;

    static double lat = 0;
    static double lng = 0;
    static double alt = 0;
    static double kmh = 0;

    while (SerialGPS.available() > 0)
    {
        if (gps.encode(SerialGPS.read()))
        {
            size_t toWait = 0;
            if (gps.altitude.isUpdated())
            {
                toWait += 100;
                ++altCount;
                alt += gps.altitude.meters();
            }
            if (gps.speed.isUpdated())
            {
                toWait += 100;
                ++kmhCount;
                kmh += gps.speed.kmph();
            }
            if (gps.location.isUpdated())
            {
                toWait += 100;
                ++locCount;
                lat += gps.location.lat();
                lng += gps.location.lng();
            }
            if (locCount == 4)
            {
                lat = lat / locCount;
                lng = lng / locCount;
                alt = alt / altCount;
                kmh = kmh / kmhCount;
                SendData(lat, lng, alt, kmh);
                locCount = 1;
                altCount = 1;
                kmhCount = 1;
            }
            delay(toWait);
        }
    }
}