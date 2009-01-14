#include <SoftwareSerial.h>
#include <Ethernet.h>
#include "configuration.h"

#define disconnected 0
#define connected 1
#define requesting 2
#define reading 3
#define requestComplete 4
#define pausing 5

#define rxPin 6
#define txPin 7
#define ledPin 13

Client client(server, 80);

SoftwareSerial printer =  SoftwareSerial(rxPin, txPin);

int status = 0;
long lastCompletionTime = 0;

const byte command = 0x1B;
const byte fullcut = 0x69;
const byte partialcut = 0x6D;

void setup() {
  // ethernet
  Ethernet.begin(mac, ip, gateway);
  
  // serial
  pinMode(rxPin, INPUT);
  pinMode(txPin, OUTPUT);
  pinMode(ledPin, OUTPUT);
  printer.begin(9600);
  //Serial.begin(9600);
  
  // dunno why
  delay(1000);
}

void loop() {
  stateCheck();
}

void stateCheck() {
  switch (status) {
  case disconnected:
    connect();
    break;
  case connected:
    httpRequest();
    break;
  case requesting:
    lookForData();
    break;
  case reading:
    readData();
    break;
  case requestComplete:
    disconnect();
    break;
  case pausing:
    waitForNextRequest();
  }
}

void connect() {
  if (client.connect()) {
    //Serial.println("connecting...");
    status = connected;
  } else {
    //Serial.println("connection failed");
    lastCompletionTime = millis();
    status = requestComplete;
  }
}

void httpRequest() {
  //Serial.println("making request");
  char getRequest[100];
  strcpy(getRequest, "GET /messages/next?secret=");
  strcat(getRequest, secret);
  strcat(getRequest, " HTTP/1.0");
  client.println(getRequest);
  
  char hostRequest[100];
  strcpy(hostRequest, "Host: ");
  strcat(hostRequest, hostname);
  client.println(hostRequest);
  client.println();
  status = requesting;
}

void lookForData() {
  char seen = 0;
  if (client.available()) {
    seen = 1;
    char c = client.read();
    // Serial.print(c);
    if (c == '>') {
      status = reading;
    }
  }
 
 if (client.available() == 0 && seen == 1) {
    //Serial.println("found nothing");
    lastCompletionTime = millis();
    status = requestComplete;
  }
}

void readData() {
  if (client.available()) {
    char c = client.read();
    printer.print(c);
    //Serial.print(c);
  }
  else {
    //Serial.println("finished reading");
    printer.println("");
    printer.println("");
    printer.println("");
    printer.print(command, BYTE);
    printer.print(partialcut, BYTE);
    lastCompletionTime = millis();
    status = requestComplete;
  }
}

void disconnect() {
  //Serial.println("");
  //Serial.println("disconnecting.");
  client.stop();
  status = pausing;
  /*if (!client.connected()) {
    printer.println();
    printer.println("disconnecting.");
    client.stop();
    for(;;)
      ;
  }*/
}

void waitForNextRequest() {
  if (millis() - lastCompletionTime >= 10000) {
    status = disconnected;
  } 
}

void blink(int howManyTimes) {
  int i;
  for (i=0; i < howManyTimes; i++) {
   digitalWrite(ledPin, HIGH);
   delay(500);
   digitalWrite(ledPin, LOW);
   delay(500);
  } 
}
