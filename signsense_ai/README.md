# SignSense AI – Universal Accessibility Assistant

<div align="center">
  <img src="docs/diagrams/logo.png" width="140" alt="SignSense AI Logo" />
  <h2>Empowering the Visually Impaired with AI</h2>
  <p><b>IBM SkillsBuild Hackathon Project</b></p>

  ![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
  ![Python](https://img.shields.io/badge/Python-3.11-3776AB?logo=python)
  ![YOLOv8](https://img.shields.io/badge/YOLOv8-Ultralytics-00BFFF)
  ![Gemini AI](https://img.shields.io/badge/Gemini-AI-4285F4?logo=google)
  ![License](https://img.shields.io/badge/License-MIT-green)
</div>

---

## 📖 Overview

**SignSense AI** is a production-ready, AI-powered Universal Accessibility Assistant that helps blind, visually impaired, and elderly users understand their surroundings through real-time camera intelligence and voice guidance.

---

## ✨ Core Features

| Feature | Description | Technology |
|---------|-------------|------------|
| 🎯 Object Detection | Real-time detection of 80+ everyday objects | YOLOv8 + OpenCV |
| 🚦 Traffic Detection | Traffic signals, pedestrian crossings | YOLOv8 + HSV Analysis |
| 🚗 Vehicle Detection | Cars, bikes, buses, trucks detection | YOLOv8 |
| 💸 Currency Detection | Indian Rupee denomination recognition | Gemini Vision |
| 📄 OCR Text Reader | Books, signs, labels, menus | EasyOCR |
| 🌍 Scene Description | Full AI scene narration | Gemini 1.5 Flash |
| 🎨 Color Detection | 12 dominant color detection | OpenCV HSV |
| 👤 Face Detection | Face count and position | MediaPipe |
| 🗺️ Navigation | Turn-by-turn walking directions | OSM + OpenRouteService |
| 🆘 Emergency SOS | One-tap SOS with live location | Geolocator + SMS |
| 🎙️ Voice Commands | Full hands-free operation | SpeechToText |

---

## 🏗️ Architecture

```
SignSense AI
├── flutter_app/           # Flutter mobile application
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/       # All UI screens
│   │   ├── widgets/       # Reusable components
│   │   ├── services/      # API, Navigation, DB, Voice
│   │   ├── providers/     # State management
│   │   ├── models/        # Data models
│   │   └── utils/         # Theme, routing
│   └── pubspec.yaml
│
├── backend/               # Python Flask API server
│   ├── app.py             # Entry point
│   ├── api/               # REST endpoints
│   ├── ai_modules/        # ML model loaders
│   ├── utils/             # Image processing, color detection
│   └── database/          # SQLite
│
├── ml_models/             # AI model weights
│   ├── yolov8/            # YOLOv8n weights
│   └── currency/          # Custom currency model
│
└── docs/                  # Documentation & diagrams
```

---

## 🚀 Quick Start

### Prerequisites

```bash
# Backend
Python 3.11+
pip install -r backend/requirements.txt

# Frontend
Flutter 3.x
Android SDK / Xcode
```

### Backend Setup

```bash
cd signsense_ai/backend

# 1. Copy and fill environment variables
cp .env.example .env
# Edit .env — add GEMINI_API_KEY, ORS_API_KEY

# 2. Install dependencies
pip install -r requirements.txt

# 3. Download AI models
python download_models.py

# 4. Start Flask server
python app.py
```

The API will be available at `http://localhost:5000`.

### Flutter App Setup

```bash
cd signsense_ai/flutter_app

# 1. Install Flutter packages
flutter pub get

# 2. Update backend URL in lib/services/api_service.dart
# Change: static const String _baseUrl = 'http://YOUR_BACKEND_IP:5000';

# 3. Run on Android emulator (connects via 10.0.2.2)
flutter run

# 4. Build APK
flutter build apk --release
```

---

## 🔑 Free API Keys

| Service | Purpose | Get Free Key |
|---------|---------|-------------|
| Google Gemini | Scene description, currency | [ai.google.dev](https://ai.google.dev) |
| OpenRouteService | Navigation routing | [openrouteservice.org](https://openrouteservice.org) |
| Nominatim/OSM | Geocoding & maps | No key required |

---

## 📡 REST API Reference

### Object Detection
```
POST /api/detect/objects
Content-Type: multipart/form-data
Body: image (JPEG file)

Response:
{
  "detections": [
    {"label": "Person", "confidence": 0.92, "position": "ahead", "bbox": {...}},
    {"label": "Chair", "confidence": 0.87, "position": "left", "bbox": {...}}
  ],
  "voice_message": "Person ahead. Chair on your left.",
  "count": 2
}
```

### Traffic Detection
```
POST /api/detect/traffic
Response: {"traffic_light_color": "red", "voice_message": "Red signal. Please wait."}
```

### OCR Text Reading
```
POST /api/ocr/read
Response: {"text": "Full extracted text...", "blocks": [...]}
```

### Scene Description (Gemini)
```
POST /api/scene/describe
Response: {"description": "You are standing near a busy road..."}
```

### Currency Detection
```
POST /api/currency/detect
Response: {"denomination": 500, "currency": "₹500", "voice_message": "This is a Five Hundred Rupee note."}
```

### Navigation
```
POST /api/navigation/route
Body: {"start_lat": 12.9, "start_lng": 77.5, "destination": "Indiranagar"}
Response: {"route_points": [...], "instructions": [...], "voice_message": "Route found..."}
```

---

## 🧪 Testing

```bash
# Backend tests
cd signsense_ai
pip install pytest
python -m pytest tests/ -v

# Flutter tests
cd flutter_app
flutter test
```

---

## 📱 Voice Commands

| Say | Action |
|-----|--------|
| "Detect objects" | Opens object detection camera |
| "Navigate" | Opens navigation mode |
| "Read text" | Opens OCR scanner |
| "Currency" | Opens currency detector |
| "Describe scene" | Opens AI scene description |
| "SOS" / "Emergency" | Opens emergency SOS screen |
| "Settings" | Opens settings |

---

## ♿ Accessibility Features

- **Screen Reader Support** — All buttons and cards have Semantics labels
- **Voice-First Design** — Every screen announces itself when opened
- **High Contrast Mode** — Available in settings
- **Adjustable Text Size** — 80%–200% scaling
- **Adjustable Speech Rate** — 0.1x – 1.0x
- **Multi-Language Voice** — English, Hindi, Tamil, Telugu, Kannada
- **Haptic Feedback** — Optional vibration cues
- **Offline Mode** — Core features work without internet

---

## 🛠️ Tech Stack

### Frontend
- **Flutter 3.x** — Cross-platform mobile
- **Provider** — State management
- **flutter_tts** — Text-to-speech
- **speech_to_text** — Voice commands
- **flutter_map + OSM** — Navigation maps

### Backend
- **Python Flask** — REST API server
- **YOLOv8 (Ultralytics)** — Object detection
- **EasyOCR** — Text recognition
- **MediaPipe** — Face detection
- **OpenCV** — Image processing
- **Google Gemini 1.5 Flash** — Scene description & currency (free tier)

### Infrastructure
- **SQLite** — Local database (backend)
- **sqflite** — Local database (mobile)
- **OpenRouteService** — Walking navigation
- **Nominatim/OpenStreetMap** — Geocoding

---

## 📊 IBM SkillsBuild Alignment

| Skill | How Used |
|-------|---------|
| AI / Machine Learning | YOLOv8 object detection, Gemini AI |
| Computer Vision | Real-time camera analysis |
| Cloud & API Integration | Gemini API, ORS API |
| Accessibility Design | WCAG 2.1 AA compliance |
| Full Stack Development | Flutter + Flask end-to-end |
| Data Management | SQLite + structured detection history |

---

## 👥 Team

Built for the **IBM SkillsBuild Hackathon** — *Building AI for Social Good*.

---

## 📄 License

MIT License — Free to use, modify, and distribute.

---

<div align="center">
  <p><i>Made with ❤️ for Accessibility</i></p>
  <p><b>SignSense AI — See the World. Hear the World.</b></p>
</div>
