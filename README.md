# ViziLink Security Lab — Flutter + Android

> **Educational Screen Mirroring & Security Analysis Prototype**  
> Demonstrating how legitimate full-device screen mirroring operates on modern Android, and how the operating system's security architecture prevents covert surveillance.

---

## 🛡️ Core Educational & Security Philosophy

The primary objective of this project is to provide a reference implementation of **zero-stealth, user-authorized screen mirroring** between two devices (Phone A: Broadcaster, Phone B: Viewer) over local Wi-Fi or Android Hotspot.

### Strict Security Invariants
1. **Zero Silent Capture**: Screen mirroring cannot initiate without the user granting explicit consent through Android's system `MediaProjection` dialog (`MediaProjectionManager.createScreenCaptureIntent()`).
2. **Foreground Service & Visibility**: Android 10+ and 14+ mandate that screen capture execute inside an ongoing Foreground Service with `foregroundServiceType="mediaProjection"`. The system notification cannot be hidden or suppressed.
3. **Android Hardware Privacy Indicator**: Android 12+ renders a persistent green camera/screen chip in the status bar while capture is active. This is drawn by the OS compositor and cannot be spoofed or occluded.
4. **Sender Approval Gate**: In addition to the dynamic 6-digit session PIN, Phone A must explicitly approve incoming viewer requests before streaming begins.
5. **Zero Cloud Server / P2P Local Transport**: Signaling runs directly on an embedded WebSocket server hosted on Phone A. Video and DataChannel payloads travel peer-to-peer over LAN via WebRTC with DTLS-SRTP encryption. No frames are sent to external cloud servers.

---

## 📐 Architecture Overview

```
Phone A (Broadcaster / Sender)                     Phone B (Receiver / Viewer)
==============================                     ===========================
[ Flutter UI: SenderScreen ]                       [ Flutter UI: ViewerScreen ]
            │                                                  │
            ▼                                                  ▼
[ Native Kotlin Foreground Service ]                [ MobileScanner / PIN Prompt ]
            │                                                  │
            ▼                                                  ▼
[ Android MediaProjection API ]                    [ WebSocket Signaling Client ]
            │                                                  │
            ▼                                                  ▼
[ WebRTC VideoTrack (720p/30fps) ]                 [ WebRTC RTCPeerConnection ]
            │                                                  │
            ▼                                                  ▼
[ Local LAN / Hotspot Signaling Server ] ────────> [ RTCVideoRenderer + HUD ]
            │
            ▼
[ RTCDataChannel File Transfer ] ────────────────> [ SHA-256 Verified Storage ]
```

---

## 🚀 Key Features

* **Android MediaProjection & Foreground Service**: Kotlin `ScreenCaptureService` companion with ongoing notification and stop broadcast receiver.
* **Low-Latency WebRTC Video**: 720p (default), configurable 15/30/60 FPS, adaptive bitrate (1.5 - 5.0 Mbps), and real-time telemetry polling.
* **Interactive Viewer HUD**:
  * Real-time FPS
  * Latency (RTT in ms)
  * Bitrate (kbps / Mbps)
  * Fullscreen toggle
  * One-tap disconnect
* **Ephemeral Dynamic QR Pairing**:
  * QR Code encodes `{ "ip": "...", "port": ..., "pin": "...", "sessionId": "..." }`
  * 6-digit random PIN
  * Host approval modal on Phone A
* **Encrypted WebRTC DataChannel File Transfer**:
  * Pick files via Android-approved picker
  * 64 KB binary chunking with flow control (`bufferedAmount`)
  * Recipient confirmation modal before download starts
  * SHA-256 hash checksum calculation and verification
  * Pause, Resume, and Cancel transfer controls
* **Interactive Security Lab**:
  * MediaProjection token lifecycle
  * Android 14+ FGS security rules
  * Threat matrix: Malicious Spyware vs Legitimate Mirroring
  * ADB commands for forensic auditing (`dumpsys media_projection`, `appops`, `dumpsys activity services`)

---

## 🛠️ Build & Installation Instructions

### Prerequisites
* Flutter SDK 3.47+ (Dart 3.13+)
* Android SDK 34+
* Java 17+
* Two Android devices or emulators on the same Wi-Fi network / Hotspot

### Building Debug APK
```bash
flutter pub get
flutter build apk --debug
```
The resulting APK will be located at:
```
build/app/outputs/flutter-apk/app-debug.apk
```

### Running on Device A (Sender)
```bash
flutter run -d <device_a_id>
```

### Running on Device B (Viewer)
```bash
flutter run -d <device_b_id>
```

---

## 📋 Comprehensive Testing Checklist

| # | Test Scenario | Expected Outcome | Status |
|---|---------------|------------------|--------|
| 1 | **Permission Granted** | Android shows system MediaProjection prompt. When user taps "Start now", foreground service starts and streaming initiates. | ✅ Verified |
| 2 | **Permission Denied** | User taps "Cancel" on Android prompt. Screen capture cleanly aborts; foreground service does not remain running; UI displays error banner. | ✅ Verified |
| 3 | **Sender Stops Sharing** | Phone A taps "Stop Screen Sharing". Capture tracks are closed, foreground notification is removed, and Phone B is disconnected. | ✅ Verified |
| 4 | **Viewer Disconnects** | Phone B taps "Disconnect". Signaling client closes, WebRTC tracks release, Phone A updates UI to "Host Ready". | ✅ Verified |
| 5 | **Host Notification Action** | User taps "Stop Sharing" directly on the Android status bar notification. `ScreenCaptureService` broadcasts stop event, terminating Flutter stream. | ✅ Verified |
| 6 | **Invalid PIN Attempt** | Phone B connects with incorrect PIN. Phone A server immediately rejects handshake with `auth_failed` and drops WebSocket. | ✅ Verified |
| 7 | **Host Rejects Request** | Phone B enters valid PIN, but Phone A user taps "Decline" on the approval modal. Connection is closed without streaming. | ✅ Verified |
| 8 | **Local Hotspot Mode** | Phone A creates an Android Wi-Fi Hotspot, Phone B connects to it. Signaling resolves to `192.168.43.1` and streams directly over hotspot. | ✅ Verified |
| 9 | **Network Disconnect** | Wi-Fi is toggled off during active stream. WebRTC triggers `RTCIceConnectionStateDisconnected`; stats HUD marks network drop. | ✅ Verified |
| 10 | **Screen Rotation** | Phone A rotates between portrait and landscape. VirtualDisplay automatically adapts resolution and aspect ratio in `RTCVideoView`. | ✅ Verified |
| 11 | **App Backgrounding** | Phone A presses Home button. MediaProjection continues safely in background under the Foreground Service with system green privacy chip active. | ✅ Verified |
| 12 | **DataChannel Transfer** | A file is sent from Phone A to Phone B. Chunks transfer smoothly; SHA-256 checksum is calculated and matches original file. | ✅ Verified |
| 13 | **Checksum Mismatch Defense** | Tampered or corrupt file chunks result in SHA-256 verification failure, file rejection, and warning alert. | ✅ Verified |
| 14 | **Audit Inspection** | Running `adb shell dumpsys media_projection` explicitly lists the app's package and active token. | ✅ Verified |

---

## 🔍 Educational Security Audit Commands

Forensic investigators, students, and defenders can inspect running sessions using ADB:

```bash
# 1. Query active MediaProjection tokens:
adb shell dumpsys media_projection

# 2. Check running foreground services of type mediaProjection:
adb shell dumpsys activity services | grep -i "mediaProjection"

# 3. Check AppOps PROJECT_MEDIA permission:
adb shell cmd appops get com.vizilink.securitylab.vizilink_security_lab PROJECT_MEDIA

# 4. View active WebRTC signaling and capture logs:
adb logcat -s ScreenCaptureService:V WebRtcAudioRecord:V WebRtcVideoTrack:V
```

---

## ⚖️ Ethical & Educational Notice

This software is developed strictly for educational, testing, and authorized screen mirroring purposes. It does not contain covert capabilities, accessibility service evasion, hidden background installation, or remote access Trojans (RATs).
