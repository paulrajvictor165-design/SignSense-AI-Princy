# SignSense AI – Installation Guide

## System Requirements

| Component | Requirement |
|-----------|------------|
| OS | Windows 10+, macOS 12+, Ubuntu 22.04+ |
| Python | 3.11+ |
| Flutter | 3.0+ |
| Android | API 26+ (Android 8.0+) |
| RAM | 8 GB minimum, 16 GB recommended |
| Storage | 5 GB for models + dependencies |

---

## Step 1: Clone / Navigate to Project

```powershell
# Windows (PowerShell)
cd "d:\signsense AI universal acessibility assistant\signsense_ai"
```

---

## Step 2: Backend Setup

### 2.1 Create virtual environment

```bash
python -m venv .venv

# Windows
.venv\Scripts\activate

# macOS/Linux
source .venv/bin/activate
```

### 2.2 Install Python dependencies

```bash
cd backend
pip install -r requirements.txt
```

> **Note:** This installs PyTorch, YOLOv8, EasyOCR, and MediaPipe.
> First install may take 5–10 minutes.

### 2.3 Set up environment variables

```bash
cp .env.example .env
```

Edit `.env`:
```env
GEMINI_API_KEY=your_gemini_api_key
ORS_API_KEY=your_openrouteservice_api_key
```

**Get Free API Keys:**
- Gemini: https://aistudio.google.com/ → Get API Key
- ORS: https://openrouteservice.org/dev/#/signup

### 2.4 Download AI models

```bash
python download_models.py
```

### 2.5 Start the Flask server

```bash
python app.py
```

Server starts at: `http://0.0.0.0:5000`

---

## Step 3: Flutter App Setup

### 3.1 Install Flutter

Download from: https://flutter.dev/docs/get-started/install

```bash
flutter doctor  # Verify installation
```

### 3.2 Get Flutter dependencies

```bash
cd flutter_app
flutter pub get
```

### 3.3 Configure backend URL

Edit [`lib/services/api_service.dart`](lib/services/api_service.dart):

```dart
// For Android Emulator (points to host machine)
static const String _baseUrl = 'http://10.0.2.2:5000';

// For Physical Device (use your PC's local IP)
static const String _baseUrl = 'http://192.168.1.100:5000';
```

### 3.4 Run on Android

```bash
# Start Android emulator first, then:
flutter run

# Or build release APK
flutter build apk --release
# APK: build/app/outputs/flutter-apk/app-release.apk
```

---

## Step 4: Verify Everything Works

1. Open the app → you should hear "Welcome to SignSense AI"
2. Tap **Object Detection** → camera opens and detects objects
3. Tap **Scene Description** → Gemini AI narrates the scene
4. Tap **Emergency SOS** → location is fetched

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "No cameras found" | Grant camera permission in Android settings |
| "Gemini API error" | Check GEMINI_API_KEY in .env file |
| "No route found" | Check ORS_API_KEY or use offline mode |
| Backend not reachable | Ensure Flask is running; check firewall |
| YOLOv8 model missing | Run `python download_models.py` |
| Flutter build fails | Run `flutter clean && flutter pub get` |

---

## Deployment (Production)

```bash
# Run with gunicorn for production
gunicorn -w 4 -b 0.0.0.0:5000 "app:create_app()"
```

For Android Play Store deployment:
```bash
flutter build appbundle --release
```
