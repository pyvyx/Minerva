# HTTPS Server

This repository contains two variants of an HTTPS server: one in C++ for the ESP32 and another in Go for the Raspberry Pi.

## ESP32 HTTPS Server

The ESP32 server is designed to run on the ESP32 microcontroller and automatically creates a self-signed SSL certificate. Before using the ESP32 server, you need to set your WiFi credentials for it to connect. Modify the following lines at the top of the file:

```c++
#define WIFI_SSID "WIFI_NAME"
#define WIFI_PSK "WIFI_PASSWORD"
```

If you want to change the authorization credentials, go into the code and modify:
```c++
static const char* User = "login";
static const char* ApiKey = "d404559f602eab6fd602ac7680dacbfaadd13630335e951f097af3900e9de176b6db28512f2e000b9d04fba5133e8b1c6e8df59db3a8ab9d60be4b97cc9e81db";
```

The ApiKey is the password as a SHA512 hash, and the default password is "1234". The ESP32 server also supports using an OLED display; if you don't need that functionality, simply remove the corresponding code.


## Go HTTPS Server
The Go server is designed to run on the Raspberry Pi and requires a pre-generated SSL certificate and key. To create a certificate and key, you can use the following OpenSSL command:

```
openssl req -x509 -sha256 -newkey rsa:4048 -keyout key.pem -out cert.pem -days 1095 -nodes
```

The certificate and key should be placed in the same directory as the Go server code.

If you want to change the authorization credentials, go into the code and modify:
```go
const (
	User   = "login"
	ApiKey = "d404559f602eab6fd602ac7680dacbfaadd13630335e951f097af3900e9de176b6db28512f2e000b9d04fba5133e8b1c6e8df59db3a8ab9d60be4b97cc9e81db"
)
```

The ApiKey is the password as a SHA512 hash, and the default password is "1234". The ESP32 server also supports using an OLED display; if you don't need that functionality, simply remove the corresponding code.