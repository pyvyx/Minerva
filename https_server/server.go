package main

import (
	"crypto/sha512"
	"crypto/tls"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"math/rand"
	"net/http"
	"time"
)

const (
	User   = "login"
	ApiKey = "d404559f602eab6fd602ac7680dacbfaadd13630335e951f097af3900e9de176b6db28512f2e000b9d04fba5133e8b1c6e8df59db3a8ab9d60be4b97cc9e81db"
)

const (
    StatusSettingsChanged = 201
    StatusSettingsPending = 202
    StatusSettingsApplied = 203
)

var (
	data            []byte
	settingsData    []byte
	settingsChanged bool
	lastSignal      time.Time
)

func main() {
	serverTLSCert, err := tls.LoadX509KeyPair("cert.pem", "key.pem")
	if err != nil {
		log.Fatalf("Error loading certificate and key file: %v", err)
	}
	
	http.HandleFunc("/info", HandleInfo)
	http.HandleFunc("/settings/tracker/status", HandleSettingsTrackerStatus)
	http.HandleFunc("/settings/tracker/applied", HandleSettingsTrackerApplied)
	http.HandleFunc("/settings/tracker", HandleSettingsTracker)
	http.HandleFunc("/", Handle404)

	server := &http.Server{
		Addr: ":443",
		TLSConfig: &tls.Config{
			Certificates: []tls.Certificate{serverTLSCert},
		},
	}
	defer server.Close()

	fmt.Println("Starting server...")
	log.Fatal(server.ListenAndServeTLS("", ""))
}


func Authenticate(r *http.Request) bool {
	username, password, ok := r.BasicAuth()
	if !ok {
		return false
	}

	hasher := sha512.New()
	hasher.Write([]byte(password))
	hashBytes := hasher.Sum(nil)

	if username != User || hex.EncodeToString(hashBytes) != ApiKey {
		fmt.Printf("Failed to authenticate, ip = %s\n", r.RemoteAddr)
		time.Sleep(time.Duration(rand.Intn(30-1+1) + 1) * time.Second)
		return false
	}
	return true
}


func HandleInfo(w http.ResponseWriter, r *http.Request) {
	if !Authenticate(r) {
		return
	}

	if r.Method == http.MethodGet {
		w.Header().Add("Content-Type", "text/plain")
		fmt.Fprintf(w, "%d,%s", time.Now().Sub(lastSignal).Milliseconds(), data)
	} else if r.Method == http.MethodPost {
		body, err := io.ReadAll(r.Body)
		defer r.Body.Close()
		if err != nil {
			fmt.Println("Failed to read body")
			return
		}
		data = body
		lastSignal = time.Now()
		if settingsChanged {
			w.WriteHeader(StatusSettingsChanged)
		}
	}
}

func HandleSettingsTracker(w http.ResponseWriter, r *http.Request) {
	if !Authenticate(r) {
		return
	}

	if r.Method == http.MethodGet {
		w.Header().Add("Content-Type", "text/plain")
		fmt.Fprintf(w, "%s", settingsData)
	} else if r.Method == http.MethodPost {
		body, err := io.ReadAll(r.Body)
		defer r.Body.Close()
		if err != nil {
			fmt.Println("Failed to read settings body")
			return
		}
		settingsData = body
		settingsChanged = true
	}
}

func HandleSettingsTrackerApplied(w http.ResponseWriter, r *http.Request) {
	if !Authenticate(r) {
		return
	}

	settingsChanged = false
}

func HandleSettingsTrackerStatus(w http.ResponseWriter, r *http.Request) {
	if !Authenticate(r) {
		return
	}

	if settingsChanged {
		w.WriteHeader(StatusSettingsPending)
	} else {
		w.WriteHeader(StatusSettingsApplied)
	}
}

func Handle404(w http.ResponseWriter, r *http.Request) {
	if !Authenticate(r) {
		return
	}
}