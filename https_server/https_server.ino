// TODO: Configure your WiFi here
#define WIFI_SSID "FRITZ!Box 7330"
#define WIFI_PSK  "04885702616868858006"

#include <Arduino.h>
#include <WiFi.h>

// Includes for the server
#include <SSLCert.hpp>
#include <HTTPSServer.hpp>
#include <HTTPRequest.hpp>
#include <HTTPResponse.hpp>
using namespace httpsserver;

#include "Hash.h"

std::unique_ptr<HTTPSServer> secureServer;
std::string xCord, oldXCord; // -180 - 180
std::string yCord, oldYCord; // -90  -  90
std::string data;
unsigned long lastSignal = 0;

void Restart()
{
    Serial.println("Restarting...");
    ESP.restart();
}


void setup()
{
    Serial.begin(115200);
    delay(3000); // wait for the monitor to reconnect after uploading.

    Serial.println("Creating a new self-signed certificate.");

    // First, we create an empty certificate:
    std::unique_ptr<SSLCert> cert(new SSLCert());

    // Now, we use the function createSelfSignedCert to create private key and certificate.
    // The function takes the following paramters:
    // - Key size: 1024 or 2048 bit should be fine here, 4096 on the ESP might be "paranoid mode"
    //   (in generel: shorter key = faster but less secure)
    // - Distinguished name: The name of the host as used in certificates.
    //   If you want to run your own DNS, the part after CN (Common Name) should match the DNS
    //   entry pointing to your ESP32. You can try to insert an IP there, but that's not really good style.
    // - Dates for certificate validity (optional, default is 2019-2029, both included)
    //   Format is YYYYMMDDhhmmss
    int createCertResult = createSelfSignedCert(
        *cert,
        KEYSIZE_1024,
        "CN=myesp32.local,O=pyvyx,C=DE",
        "20190101000000",
        "20300101000000"
    );

    // Now check if creating that worked
    if (createCertResult != 0)
    {
        Serial.printf("Cerating certificate failed. Error Code = 0x%02X, check SSLCert.hpp for details", createCertResult);
        Restart();
    }
    Serial.println("Creating the certificate was successful");

    // If you're working on a serious project, this would be a good place to initialize some form of non-volatile storage
    // and to put the certificate and the key there. This has the advantage that the certificate stays the same after a reboot
    // so your client still trusts your server, additionally you increase the speed-up of your application.
    // Some browsers like Firefox might even reject the second run for the same issuer name (the distinguished name defined above).
    //
    // Storing:
    //   For the key:
    //     cert->getPKLength() will return the length of the private key in byte
    //     cert->getPKData() will return the actual private key (in DER-format, if that matters to you)
    //   For the certificate:
    //     cert->getCertLength() and ->getCertData() do the same for the actual certificate data.
    // Restoring:
    //   When your applications boots, check your non-volatile storage for an existing certificate, and if you find one
    //   use the parameterized SSLCert constructor to re-create the certificate and pass it to the HTTPSServer.
    //
    // A short reminder on key security: If you're working on something professional, be aware that the storage of the ESP32 is
    // not encrypted in any way. This means that if you just write it to the flash storage, it is easy to extract it if someone
    // gets a hand on your hardware. You should decide if that's a relevant risk for you and apply countermeasures like flashd:\Dev\esp32server\esp32_https_server\examples\Static-Page\Static-Page.ino
    // encryption if neccessary

    // We can now use the new certificate to setup our server as usual.
    secureServer = std::unique_ptr<HTTPSServer>(new HTTPSServer(cert.get()));

    // Connect to WiFi
    Serial.println("Setting up WiFi");
    WiFi.begin(WIFI_SSID, WIFI_PSK);
    while (WiFi.status() != WL_CONNECTED)
    {
        Serial.print(".");
        delay(500);
    }

    Serial.print("Connected. IP=");
    Serial.println(WiFi.localIP());

    // For every resource available on the server, we need to create a ResourceNode
    // The ResourceNode links URL and HTTP method to a handler function
    ResourceNode* nodeGet = new ResourceNode("/", "GET", &HandleGet);
    ResourceNode* node404 = new ResourceNode("", "GET", &Handle404);
    ResourceNode* nodePost = new ResourceNode("/", "POST", &HandlePost);

    secureServer->registerNode(nodeGet);
    secureServer->registerNode(nodePost);
    secureServer->setDefaultNode(node404);
    secureServer->addMiddleware(Authenticate);

    Serial.println("Starting server...");
    secureServer->start();
    if (!secureServer->isRunning())
    {
        Serial.println("Failed to start server");
        Restart();
    }
    Serial.println("Server ready.");
}


void loop()
{
    secureServer->loop();
    delay(1500);
}


void Authenticate(HTTPRequest* req, HTTPResponse* res, std::function<void()> next)
{
    static const char* user = "login";
    static const char* apiKey = "d404559f602eab6fd602ac7680dacbfaadd13630335e951f097af3900e9de176b6db28512f2e000b9d04fba5133e8b1c6e8df59db3a8ab9d60be4b97cc9e81db";
    if (strcmp(apiKey, hash_sha512_binary(req->getBasicAuthPassword().c_str(), req->getBasicAuthPassword().size(), NULL)) == 0 && strcmp(user, req->getBasicAuthUser().c_str()) == 0)
        next();
    else
    {
        res->setStatusCode(201);
        req->discardRequestBody();
        delay(random(1000, 30000));
    }
}


void HandlePost(HTTPRequest* req, HTTPResponse* res)
{
    /*
        Structure: "lat,lng,alt,kmh"
        every thing 8 decimal places and at max 3 before decimal i.e. 12 chars per entry

        51 chars
        example: "49.02536179,11.95466600,436.79907407,0.14565581"

        Authentication:
        User: login
        Pw: 1234
    */
    
    size_t s = 0;
    constexpr size_t bufferSize = 51;
    char buffer[bufferSize+1] = {0};

    while(s < bufferSize && !req->requestComplete())
    {
        s += req->readBytes((byte*)&buffer[s], bufferSize-s);
    }

    if (!req->requestComplete())
    {
        req->discardRequestBody();
        Serial.println("Request is to long");
        return;
    }


    char* endx = nullptr, *endy = nullptr;
    strtod(buffer, &endx);
    strtod(endx+1, &endy);
    if (endx == buffer || endy == endx+1)
    {
        Serial.println("Failed to convert");
        delay(5000);
        return;
    }
    oldXCord = xCord;
    oldYCord = yCord;
    xCord.assign(buffer, endx - buffer);
    yCord.assign(endx+1, endy - (endx+1));
    lastSignal = millis();

    data = endy+1;
    Serial.printf("B: %s\n", data.c_str());
    Serial.printf("old x: %s\n", oldXCord.c_str());
    Serial.printf("old y: %s\n", oldYCord.c_str());
    Serial.printf("x: %s\n", xCord.c_str());
    Serial.printf("y: %s\n", yCord.c_str());
}


void HandleGet(HTTPRequest* req, HTTPResponse* res)
{
    req->discardRequestBody();
    res->setHeader("Content-Type", "text/plain");
    res->printf("%lu,%s,%s,%s", (unsigned long)(millis() - lastSignal), xCord.c_str(), yCord.c_str(), data.c_str());
}


void Handle404(HTTPRequest* req, HTTPResponse* res)
{
    res->setStatusCode(201);
    req->discardRequestBody();
    delay(random(1000, 30000));
}
