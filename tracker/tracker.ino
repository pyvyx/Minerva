#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>

#include <TinyGPS++.h>
#include <HardwareSerial.h>

#define WIFI_SSID "FRITZ!Box 7330"
#define WIFI_PSK  "04885702616868858006"
#define SERVER_IP "https://192.168.178.90"

enum Status
{
    Ok = 200,
    SettingsChanged = 201,
    SettingsPending = 202,
    SettingsApplied = 203,
    Error = 204
};

static HTTPClient http;
static HardwareSerial SerialGPS(2);
static unsigned long sleepForAfterSend = 450000;
static unsigned long sleepForBetweenSamples = 1000;
static unsigned long samplesToCollect = 3;
static unsigned long sleepForWhileNoSignal = 3000;

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

    http.setAuthorization("login", "1234");
    http.begin(SERVER_IP);
}


bool SplitString(const String& str, char c, String* buffer, size_t size)
{
    size_t s = 0;
    size_t idx = 0;
    for (size_t i = 0; i < str.length(); ++i)
    {
        if (str[i] == c && s < size)
        {
            buffer[s] = str.substring(idx, i);
            idx = i+1;
            ++s;
        }
    }
    buffer[s] = str.substring(idx);
    return s == size;
}


void ChangeSettings()
{
    http.setURL("/settings/tracker");
    Serial.print("Applying settings\n");
    if(http.GET() != Status::Ok) return;
    String buffer[4];
    SplitString(http.getString(), ',', buffer, 4);

    sleepForAfterSend = buffer[0].toInt();
    sleepForBetweenSamples = buffer[1].toInt();
    samplesToCollect = buffer[2].toInt();
    sleepForWhileNoSignal = buffer[3].toInt();
    Serial.println(sleepForAfterSend);
    Serial.println(sleepForBetweenSamples);
    Serial.println(samplesToCollect);
    Serial.println(sleepForWhileNoSignal);
    http.setURL("/settings/tracker/applied");
    http.GET();
    http.setURL("/");
}


void SendData(double lat, double lng, int alt, int kmh)
{
    /*
        Structure: "lat,lng,alt,kmh"
    */
    String buffer;
    buffer.reserve(40);
    buffer += String(lat, 8) + ',';
    buffer += String(lng, 8) + ',';
    buffer += String(alt) + ',';
    buffer += String(kmh);
    Serial.printf("Buffer: %s\n", buffer.c_str());

    int httpResponseCode = http.POST(buffer);
    if (httpResponseCode == Status::SettingsChanged)
    {
        ChangeSettings();
    }
    else if (httpResponseCode != Status::Ok)
    {
        Serial.print("HTTP Post failed: ");
        Serial.println(httpResponseCode);
    }
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
    SendData(lat, lng, alt, kmh);

    while (SerialGPS.available() > 0)
    {
        if (gps.encode(SerialGPS.read()))
        {
            size_t toWait = sleepForBetweenSamples / 4;
            if (gps.altitude.isUpdated())
            {
                toWait += sleepForBetweenSamples / 4;
                ++altCount;
                alt += gps.altitude.meters();
            }
            if (gps.speed.isUpdated())
            {
                toWait += sleepForBetweenSamples / 4;
                ++kmhCount;
                kmh += gps.speed.kmph();
            }
            if (gps.location.isUpdated())
            {
                toWait += sleepForBetweenSamples / 4;
                ++locCount;
                lat += gps.location.lat();
                lng += gps.location.lng();
            }
            if (locCount == samplesToCollect)
            {
                lat = lat / locCount;
                lng = lng / locCount;
                alt = alt / altCount;
                kmh = kmh / kmhCount;
                SendData(lat, lng, alt, kmh);
                locCount = 0;
                altCount = 0;
                kmhCount = 0;
                lat = 0;
                lng = 0;
                alt = 0;
                kmh = 0;
                toWait += sleepForAfterSend;
            }
            delay(toWait);
        }
    }
    delay(sleepForWhileNoSignal);
}