# HTTPS Server

This repository encompasses two variants of an HTTPS server: one implemented in C++ for the ESP32 and another in Go for the Raspberry Pi. To enable access to the server from anywhere, beyond your local network, please refer to this [guide](https://microcontrollerslab.com/accessing-esp32-web-server-anywhere-world-esp8266/). The guide is applicable to both ESP32 and Raspberry Pi. Alternatively, you can deploy the Go server on a rented server from a hosting provider for broader accessibility.

## ESP32 HTTPS Server

### Prerequisite
You have to install [esp32 https server](https://github.com/fhessel/esp32_https_server), the easiest way is to use the arudino ide.


The ESP32 server is designed to run on the ESP32 microcontroller and automatically creates a self-signed SSL certificate. Before using the ESP32 server, you need to set your WiFi credentials for it to connect. Modify the following lines at the top of the file:

```c++
#define WIFI_SSID "WIFI_NAME"
#define WIFI_PSK "WIFI_PASSWORD"
```

If you want to change the authorization credentials modify:
```c++
#define LOGIN_USER "login"
#define LOGIN_KEY  "d404559f602eab6fd602ac7680dacbfaadd13630335e951f097af3900e9de176b6db28512f2e000b9d04fba5133e8b1c6e8df59db3a8ab9d60be4b97cc9e81db"
```

The LOGIN_KEY is the password as a [SHA512](https://emn178.github.io/online-tools/sha512.html) hash, and the default password is "1234".

The ESP32 server also supports using an OLED display to get status updates, if you need that functionality use `https_server_oled.ino`.

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

The ApiKey is the password as a [SHA512](https://emn178.github.io/online-tools/sha512.html) hash, and the default password is "1234".