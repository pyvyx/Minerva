#include <TinyGPS++.h>
#include <HardwareSerial.h>

HardwareSerial SerialGPS(2);

void setup()
{
    Serial.begin(115200);
    SerialGPS.begin(9600, SERIAL_8N1, 16, 17);
}

void loop()
{
    TinyGPSPlus gps;
    while (SerialGPS.available() > 0)
    {
        if (gps.encode(SerialGPS.read()))
        {
            if (gps.altitude.isValid())
                Serial.println(gps.altitude.value());
            if (gps.speed.isValid())
                Serial.println(gps.speed.kmph());
            if (gps.location.isValid())
            {
                Serial.print("Latitude = ");
                Serial.println(gps.location.rawLat().deg);
                Serial.println(gps.location.rawLat().billionths);
                Serial.print("Longitude = ");
                Serial.println(gps.location.rawLng().deg);
                Serial.println(gps.location.rawLng().billionths);

                delay(1000);
                Serial.println();
            }
        }
    }
}