#include <WiFi.h>
#include <Wire.h>
#include <MPU6050.h>

const char* ssid = "Eshal";
const char* password = "Eshal123"; // WiFi credentials

WiFiServer server(80);
MPU6050 mpu;

float baselinePitch = 0, baselineRoll = 0;
float pitch, roll;
float threshold = 5.0; // Threshold for anomaly detection (posture difference > 5 degrees)
bool calibrated = false;
unsigned long lastIncorrectTime = 0;
String incorrectPostureHistory = ""; // Stores incorrect posture history
String matlabTimestamp = ""; // To store the timestamp received from MATLAB

void setup() {
  Serial.begin(115200);
  Wire.begin();

  // Connect to Wi-Fi
  Serial.print("Connecting to Wi-Fi");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println(" Connected!");
  Serial.println("IP Address: " + WiFi.localIP().toString());

  server.begin();

  // Initialize MPU6050
  mpu.initialize();
  if (!mpu.testConnection()) {
    Serial.println("MPU6050 not found. Check connections.");
    while (1);
  }
}

void loop() {
  WiFiClient client = server.available();
  if (client) {
    String request = client.readStringUntil('\r');
    Serial.println(request);

    if (request.indexOf("/calibrate") >= 0) {
      calibrateBaseline();
      sendWebResponse(client, "Baseline posture calibrated!");
      calibrated = true;
    } else if (request.indexOf("/monitor") >= 0) {
      sendPostureData(client);  // Send incorrect posture data when abnormal
    } else {
      sendWebPage(client);  // Show the web page
    }
    client.stop();
  }

  if (calibrated) {
    monitorPosture();  // Continuously monitor posture after calibration
    sendToMATLAB();    // Continuously send data to MATLAB
  }

  receiveFromMATLAB(); // Continuously listen for MATLAB data
}

void calibrateBaseline() {
  float totalPitch = 0, totalRoll = 0;
  const int samples = 100;

  for (int i = 0; i < samples; i++) {
    readTiltAngles();
    totalPitch += pitch;
    totalRoll += roll;
    delay(50);
  }

  baselinePitch = totalPitch / samples;
  baselineRoll = totalRoll / samples;

  Serial.printf("Baseline - Pitch: %.2f, Roll: %.2f\n", baselinePitch, baselineRoll);
  sendBaselineToMATLAB(); // Send baseline data to MATLAB after calibration
}

void readTiltAngles() {
  int16_t ax, ay, az, gx, gy, gz;
  mpu.getAcceleration(&ax, &ay, &az);
  mpu.getRotation(&gx, &gy, &gz);

  pitch = atan2(ay, sqrt(pow(ax, 2) + pow(az, 2))) * 180 / PI;
  roll = atan2(-ax, az) * 180 / PI;
}

void monitorPosture() {
  readTiltAngles();

  // Only flag as incorrect if the difference exceeds the threshold
  if (abs(pitch - baselinePitch) > threshold || abs(roll - baselineRoll) > threshold) {
    if (millis() - lastIncorrectTime > 2000) {  // Detect anomaly after 2 seconds
      lastIncorrectTime = millis();
      String timestamp = String(millis());
      String data = "Timestamp: " + timestamp + " - Pitch: " + String(pitch) + ", Roll: " + String(roll);
      incorrectPostureHistory += data + "\n";  // Store in history
    }
  }

  Serial.printf("Pitch: %.2f, Roll: %.2f\n", pitch, roll);  // Send to Serial Monitor
}

void sendToMATLAB() {
  // Send data to MATLAB with timestamp (continuously)
  String timestamp = String(millis());
  Serial.printf("MATLAB_DATA Timestamp=%s Pitch=%.2f Roll=%.2f\n", timestamp.c_str(), pitch, roll);  // Send data for real-time plotting
}

void receiveFromMATLAB() {
  // Listen for data from MATLAB
  if (Serial.available() > 0) {
    String data = Serial.readStringUntil('\n');
    if (data.startsWith("MATLAB_TIMESTAMP")) {
      matlabTimestamp = data.substring(data.indexOf('=') + 1);
      Serial.println("Received from MATLAB: " + matlabTimestamp);
    }
  }
}

void sendBaselineToMATLAB() {
  // Send the baseline posture data to MATLAB
  String timestamp = String(millis());
  Serial.printf("MATLAB_BASELINE Timestamp=%s Pitch=%.2f Roll=%.2f\n", timestamp.c_str(), baselinePitch, baselineRoll);
  
}

void sendWebResponse(WiFiClient client, String message) {
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: text/html");
  client.println();
  client.println("<html><body><h1>" + message + "</h1></body></html>");
}

void sendPostureData(WiFiClient client) {
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: text/html");
  client.println();
  client.println("<html><body>");
  client.println("<h1>Posture Monitoring System</h1>");
  
  // Only display incorrect posture history if it is abnormal
  if (abs(pitch - baselinePitch) > threshold && abs(roll - baselineRoll) > threshold) {
    client.println("<h2>Incorrect Posture History:</h2>");
    client.println("<pre>" + incorrectPostureHistory + "</pre>");
  } else {
    client.println("<p>No abnormal posture detected.</p>");
  }
  
  client.println("<h2>Last MATLAB Timestamp:</h2>");
  client.println("<pre>" + matlabTimestamp + "</pre>"); // Display MATLAB timestamp
  
  // Display baseline posture after calibration
  if (calibrated) {
    client.println("<h2>Baseline Posture (calibrated):</h2>");
    client.println("<p>Pitch: " + String(baselinePitch) + "°</p>");
    client.println("<p>Roll: " + String(baselineRoll) + "°</p>");
  }
  
  client.println("</body></html>");
}

void sendWebPage(WiFiClient client) {
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: text/html");
  client.println();
  client.println("<html><body>");
  client.println("<h1>Posture Monitoring System</h1>");
  client.println("<p>Press the button below to calibrate baseline posture:</p>");
  client.println("<form action=\"/calibrate\" method=\"GET\"><button>Calibrate</button></form>");
  client.println("<p>View incorrect posture history:</p>");
  client.println("<form action=\"/monitor\" method=\"GET\"><button>Monitor</button></form>");
  client.println("</body></html>");
}
