🌍 AISense – Universal Accessibility Assistant

AI-Powered Universal Accessibility for Everyone

IBM AI Builders Challenge 2026 — July Challenge

Challenge Theme: Reimagine Creative Industries with AI

---

📌 Project Overview

AISense – Universal Accessibility Assistant is an AI-powered accessibility platform designed to assist people with visual, hearing, and speech impairments through intelligent computer vision and artificial intelligence.

The application combines multiple AI-powered accessibility services into a single platform, enabling users to recognize objects, understand their surroundings, communicate through sign language, read printed text, identify currency notes, detect colors, recognize traffic signs, and receive smart navigation assistance.

Instead of requiring users to install and manage multiple accessibility applications, AISense integrates these capabilities into one intelligent assistant, providing a seamless, real-time experience that promotes independence and inclusion.

AISense was developed for the IBM AI Builders Challenge 2026 using IBM Bob as the primary AI-assisted development tool throughout the planning, development, debugging, testing, and deployment process.

---

🎯 Selected Challenge Theme

Reimagine Creative Industries with AI

Artificial Intelligence is transforming how people interact with technology and digital experiences.

AISense applies AI to accessibility by enabling people with disabilities to access information, communicate more effectively, and navigate their surroundings with confidence.

The platform focuses on:

- AI-powered accessibility
- Computer vision
- Real-time object recognition
- Sign language recognition
- OCR text reading
- Scene understanding
- Smart navigation
- Inclusive technology

AISense demonstrates how multiple AI technologies can work together to create an intelligent accessibility assistant that improves everyday life.

---

❗ Problem Statement

Millions of people with visual, hearing, and speech impairments face challenges while performing everyday activities.

Common challenges include:

- Identifying surrounding objects
- Reading printed documents
- Understanding traffic signs
- Recognizing currency notes
- Communicating through sign language
- Navigating unfamiliar environments
- Understanding scenes and surroundings

Existing accessibility applications usually solve only one problem at a time, requiring users to switch between different applications and repeatedly perform the same tasks.

The challenge is not simply:

«"How can AI detect an object?"»

The larger challenge is:

«"How can AI combine multiple accessibility services into one intelligent assistant that provides real-time, context-aware support?"»

---

💡 Solution Description

AISense introduces an integrated AI-powered accessibility platform where multiple intelligent services work together to assist users in real time.

The platform includes:

- 👁️ Object Detection
- 🤟 Sign Language Recognition
- 📝 OCR Text Reader
- 💵 Currency Detection
- 🎨 Color Detection
- 🌄 AI Scene Description
- 🚦 Traffic Sign Detection
- 😊 Face Detection
- 🧭 Smart Navigation

                  USER
                    │
                    ▼
        AISense Universal Assistant
                    │
 ┌──────────┬──────────┬───────────┐
 ▼          ▼          ▼
Object     OCR      Sign Language
Detection  Reader   Recognition
 │          │          │
 ▼          ▼          ▼
Currency  Scene     Navigation
Detection Description Assistant
 │          │          │
 └──────────┼──────────┘
            ▼
   Intelligent Accessibility

Each AI module performs a specialized task while sharing information through a centralized backend, enabling a consistent and efficient user experience.

---

✨ Key Features

- Real-time Object Detection
- AI Scene Description
- Sign Language Recognition
- OCR Text Reading
- Currency Detection
- Color Detection
- Face Detection
- Traffic Sign Detection
- Smart Navigation Assistance
- Voice Feedback
- Accessible Flutter Interface
- FastAPI Backend
- AI-powered Computer Vision
- Responsive Cross-Platform Design

---

🤖 Core AI Features

👁️ Object Detection

Detects everyday objects in real time using AI-powered computer vision and announces detected objects through voice output.

🤟 Sign Language Recognition

Recognizes hand gestures and converts sign language into readable text, improving communication for hearing- and speech-impaired users.

📝 OCR Text Reader

Extracts text from books, notices, documents, medicine labels, and signboards, then converts it into speech.

💵 Currency Detection

Recognizes currency notes and announces their denomination using voice feedback.

🌄 AI Scene Description

Uses Generative AI to describe complete surroundings, helping visually impaired users understand nearby people, objects, and environments.

🚦 Traffic Sign Detection

Detects important road signs such as Stop, No Entry, Pedestrian Crossing, and Speed Limit signs.

🎨 Color Detection

Identifies dominant colors of objects to assist users in daily activities.

🧭 Smart Navigation

Provides AI-assisted navigation with spoken guidance to help users travel safely.

---
🤖 AI Architecture

AISense follows a modular AI architecture where each accessibility feature is implemented as an independent AI service. This architecture enables scalability, maintainability, and easy integration of future AI models.

Each AI service performs a specialized task while communicating through a centralized FastAPI backend.

                        USER
                          │
                          ▼
                FLUTTER APPLICATION
                          │
                 REST API REQUESTS
                          │
                          ▼
                 FASTAPI BACKEND SERVER
                          │
 ┌──────────┬──────────┬──────────┬──────────┐
 ▼          ▼          ▼          ▼
YOLOv8    EasyOCR   MediaPipe   Gemini AI
 │          │          │          │
 ▼          ▼          ▼          ▼
Objects    OCR      Sign      Scene
Detection  Reader   Language  Description
 │
 ├───────────────┬───────────────────┐
 ▼               ▼                   ▼
Currency     Face Detection     Navigation
Detection
                          │
                          ▼
                     SQLite Database

The backend coordinates all AI services and sends structured responses back to the Flutter application.

---

🧠 AI Models Used

AISense integrates multiple AI technologies to provide intelligent accessibility assistance.

Feature| AI Technology
Object Detection| YOLOv8
Sign Language Recognition| MediaPipe
OCR Text Reading| EasyOCR
Scene Description| Google Gemini AI
Face Detection| OpenCV
Color Detection| OpenCV
Currency Detection| Computer Vision
Navigation| OpenRouteService API

Each model is optimized for its specific accessibility task while maintaining fast response times.

---

🔄 AI Workflow

Step 1 – User Opens AISense

The user launches the application and selects an accessibility feature.

↓

Step 2 – Capture Input

The application captures:

- Live Camera Feed
- Image
- Voice Command

↓

Step 3 – Backend Processing

The captured input is securely sent to the FastAPI backend.

↓

Step 4 – AI Processing

The backend routes the request to the appropriate AI model.

↓

Step 5 – Result Generation

The AI model analyzes the input and generates structured results.

↓

Step 6 – Voice & Text Output

AISense presents the result through:

- Voice Feedback
- On-screen Text
- Visual Highlights

This real-time workflow enables users to interact naturally with their surroundings.

---

🏗️ System Architecture

┌─────────────────────────────────────────────┐
│                   USER                      │
└─────────────────────┬───────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────┐
│            FLUTTER FRONTEND                 │
│                                             │
│  Home Screen                                │
│  Accessibility Dashboard                    │
│  Camera Interface                            │
│  Voice Output                               │
│  Settings                                   │
└─────────────────────┬───────────────────────┘
                      │
                 REST API
                      │
                      ▼
┌─────────────────────────────────────────────┐
│             FASTAPI BACKEND                 │
│                                             │
│ Authentication                              │
│ AI Services                                 │
│ API Management                              │
│ Database Operations                         │
└─────────────────────┬───────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────┐
│             AI MODULES                      │
│                                             │
│ YOLOv8                                      │
│ MediaPipe                                   │
│ EasyOCR                                     │
│ Google Gemini AI                            │
│ OpenCV                                      │
└─────────────────────┬───────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────┐
│              DATABASE                       │
│         SQLite / PostgreSQL                 │
└─────────────────────────────────────────────┘

---

⚡ Real-Time AI Processing

AISense is designed to provide instant assistance through continuous AI processing.

The platform supports:

- Live Object Detection
- Real-Time Sign Language Recognition
- Instant OCR Text Reading
- AI Scene Description
- Face Detection
- Currency Recognition
- Traffic Sign Detection
- Color Identification

Optimized AI models ensure low latency and fast response times, enabling users to receive immediate feedback while interacting with the environment.

---

🛠️ Technology Stack

Frontend

- Flutter
- Dart
- Material Design
- Camera Plugin
- Flutter TTS
- HTTP Package

Backend

- Python
- FastAPI
- Uvicorn
- SQLAlchemy
- Pydantic

Artificial Intelligence

- YOLOv8
- Google Gemini AI
- MediaPipe
- EasyOCR
- OpenCV

Database

- SQLite (Development)
- PostgreSQL (Production)

Development Tools

- IBM Bob
- Visual Studio Code
- Git
- GitHub
- Docker

---

🔷 How IBM Bob Was Used

IBM Bob served as the primary AI-assisted development tool throughout the development of AISense.

IBM Bob assisted in:

- Understanding the project architecture
- Planning AI module integration
- Developing Flutter frontend components
- Building FastAPI backend services
- Designing REST APIs
- Debugging backend and frontend communication
- Improving UI and user experience
- Optimizing AI workflows
- Testing and validating application functionality

IBM Bob acted as an AI development partner across planning, coding, debugging, testing, and deployment, helping accelerate development while maintaining the project's architecture and accessibility goals.

---📁 Project Structure

AISense-Universal-Accessibility/
│
├── backend/
│   ├── ai_modules/
│   │   ├── object_detection/
│   │   ├── sign_language/
│   │   ├── currency_detection/
│   │   ├── scene_description/
│   │   ├── ocr/
│   │   ├── navigation/
│   │   ├── traffic_sign/
│   │   ├── face_detection/
│   │   └── color_detection/
│   │
│   ├── routes/
│   ├── services/
│   ├── models/
│   ├── database/
│   ├── middleware/
│   ├── utils/
│   ├── app.py
│   ├── requirements.txt
│   ├── .env.example
│   └── README.md
│
├── flutter_app/
│   ├── lib/
│   │   ├── screens/
│   │   ├── widgets/
│   │   ├── services/
│   │   ├── models/
│   │   ├── utils/
│   │   └── main.dart
│   │
│   ├── assets/
│   ├── android/
│   ├── ios/
│   ├── web/
│   ├── pubspec.yaml
│   └── README.md
│
├── screenshots/
├── docs/
├── LICENSE
├── README.md
└── .gitignore

---

🚀 Getting Started

Prerequisites

Before running AISense, install the following software:

- Git
- Python 3.11+
- Flutter SDK
- Android Studio
- Visual Studio Code
- Node.js (for Flutter Web)
- Google Chrome (for Web Testing)

---

⚙️ Backend Setup

Step 1 – Clone the Repository

git clone https://github.com/your-username/AISense-Universal-Accessibility.git

cd AISense-Universal-Accessibility/backend

---

Step 2 – Create Virtual Environment

Windows

python -m venv venv

venv\Scripts\activate

Linux / macOS

python3 -m venv venv

source venv/bin/activate

---

Step 3 – Install Dependencies

pip install -r requirements.txt

---

Step 4 – Configure Environment Variables

Copy

.env.example

to

.env

Then configure:

- Gemini API Key
- Database URL
- Secret Key
- Navigation API Key

---

Step 5 – Run Backend

python app.py

or

uvicorn app:app --reload

Backend URL

http://localhost:5000

Health Check

http://localhost:5000/health

---

💻 Flutter Frontend Setup

Navigate to Flutter project

cd flutter_app

Install packages

flutter pub get

Run application

flutter run

Run on Chrome

flutter run -d chrome

Build APK

flutter build apk

Build Web

flutter build web

---

🔌 Core API Endpoints

Health Check

GET /health

Object Detection

POST /api/detect/objects

OCR Text Reading

POST /api/ocr/read

Currency Detection

POST /api/currency/detect

Scene Description

POST /api/scene/describe

Sign Language Recognition

POST /api/sign/detect

Face Detection

POST /api/faces/detect

Color Detection

POST /api/colors/detect

Traffic Sign Detection

POST /api/traffic/detect

Navigation

POST /api/navigation/route

---

🔐 Environment Variables

Example

GEMINI_API_KEY=your_api_key

OPENROUTESERVICE_API_KEY=your_api_key

DATABASE_URL=sqlite:///aisense.db

SECRET_KEY=your_secret_key

HOST=0.0.0.0

PORT=5000

«⚠️ Never commit your ".env" file, API keys, or secrets to GitHub.»

---

📸 Screenshots

Include screenshots of the following pages:

- 🏠 Landing Page
- 🔐 Login Page
- 📱 Home Dashboard
- 📷 Live Camera
- 👁️ Object Detection
- 🤟 Sign Language Recognition
- 📝 OCR Reader
- 💵 Currency Detection
- 🌄 Scene Description
- 🚦 Traffic Sign Detection
- 🎨 Color Detection
- 🧭 Navigation Assistance
- ⚙️ Settings

---

🎥 Demo Video

Create a public demonstration video showcasing:

- Project Introduction
- Problem Statement
- AI Features
- Live Demonstration
- AI Workflow
- IBM Bob Usage
- Real-World Impact
- Future Scope

Upload the video to YouTube and include the link here.

---

🌐 Live Application

Frontend

https://your-vercel-app.vercel.app

Backend

https://your-backend.onrender.com

GitHub Repository

https://github.com/your-username/AISense-Universal-Accessibility

---

📄 License

This project is licensed under the MIT License.

See the LICENSE file for complete details.

---
🌍 Real-World Impact

AISense – Universal Accessibility Assistant is designed to improve accessibility and independence for people with disabilities by bringing multiple AI-powered assistive technologies into one platform.

The application enables users to perform everyday activities with greater confidence, including identifying objects, reading printed text, recognizing currency, understanding scenes, communicating through sign language, and navigating unfamiliar environments.

Potential Users

- 👨‍🦯 Visually Impaired Individuals
- 🧏 Hearing-Impaired Users
- 🗣️ Speech-Impaired Users
- 👵 Senior Citizens
- 👨‍👩‍👧 Caregivers and Family Members
- 🏥 Hospitals and Rehabilitation Centers
- 🏫 Educational Institutions
- 🏢 Accessibility Organizations
- 🌍 NGOs Supporting Persons with Disabilities

Benefits

- Improves independent living
- Enhances communication
- Increases personal safety
- Provides equal access to information
- Reduces dependence on multiple applications
- Promotes digital inclusion through AI

AISense demonstrates how Artificial Intelligence can bridge accessibility gaps and create a more inclusive digital future.

---

💎 Innovation

Traditional accessibility applications usually solve only one problem.

AISense combines multiple AI technologies into a single intelligent assistant capable of understanding the user's surroundings and providing real-time assistance.

Instead of:

User
 │
 ▼
One AI Model
 │
 ▼
One Accessibility Feature

AISense provides:

                  USER
                    │
                    ▼
      AISense Universal Assistant
                    │
 ┌──────────┬──────────┬──────────┐
 ▼          ▼          ▼
 Vision      OCR      Sign Language
    AI        AI          AI
 │           │           │
 └───────────┼───────────┘
             ▼
     Universal Accessibility

This unified architecture enables seamless interaction between multiple AI services while delivering a consistent and accessible user experience.

---

🔮 Future Improvements

Future versions of AISense may include:

- 🌐 Multilingual voice assistance
- ☁️ Cloud-based AI inference
- 🤖 Personalized AI assistant
- 🧠 Offline AI model support
- 👓 Smart glasses integration
- ⌚ Smartwatch compatibility
- 🚨 Emergency SOS with live location
- 🏥 Medicine label recognition
- 🛒 Shopping assistance
- 🧭 Indoor navigation
- 🌍 Real-time language translation
- 📡 IoT-enabled accessibility devices
- 🧩 Additional AI modules through a plugin system

These enhancements will further improve usability, accessibility, and real-world adoption.

---

🏆 IBM AI Builders Challenge Submission

Field| Details
Project| AISense – Universal Accessibility Assistant
Tagline| AI-Powered Universal Accessibility for Everyone
Challenge| IBM AI Builders Challenge 2026
Theme| Reimagine Creative Industries with AI
Primary Development Tool| IBM Bob
Application Type| AI-Powered Accessibility Platform
Frontend| Flutter
Backend| FastAPI
AI Technologies| YOLOv8, MediaPipe, EasyOCR, Google Gemini AI, OpenCV
Database| SQLite / PostgreSQL
Deployment| Vercel + Render
Category| Accessibility AI / Computer Vision / Assistive Technology

---

✅ Submission Checklist

- ✅ Working AISense prototype
- ✅ Object Detection
- ✅ Sign Language Recognition
- ✅ OCR Text Reader
- ✅ Currency Detection
- ✅ Scene Description
- ✅ Face Detection
- ✅ Color Detection
- ✅ Traffic Sign Detection
- ✅ Smart Navigation
- ✅ Flutter Frontend
- ✅ FastAPI Backend
- ✅ Frontend Connected to Backend
- ✅ Public GitHub Repository
- ✅ Complete README Documentation
- ✅ Backend Documentation
- ✅ Environment Configuration
- ✅ Demo Video
- ✅ Application Screenshots
- ✅ IBM Bob Usage Documented
- ✅ IBM SkillsBuild Learning Completed
- ✅ MIT License Included

---

🤝 Contributing

Contributions are welcome.

To contribute:

1. Fork the repository.
2. Create a new feature branch.
3. Commit your changes.
4. Push the branch.
5. Open a Pull Request.

Please ensure your code follows the project's coding standards.

---

📄 License

This project is licensed under the MIT License.

See the LICENSE file for more information.

---

🙏 Acknowledgements

Special thanks to the technologies and communities that supported the development of AISense:

- IBM AI Builders Challenge
- IBM Bob
- IBM SkillsBuild
- Flutter
- FastAPI
- YOLOv8
- Google Gemini AI
- MediaPipe
- EasyOCR
- OpenCV
- SQLite
- PostgreSQL
- Git & GitHub
- Open-source AI community

---

⭐ Support

If you found this project helpful, please consider giving it a ⭐ on GitHub.

Your support encourages future development and helps improve accessibility through AI.

---

🌍 AISense – Universal Accessibility Assistant

Empowering Accessibility Through Artificial Intelligence

Built with ❤️ for IBM AI Builders Challenge 2026

