<div align="center">

# ♿ AISense

## Universal Accessibility Assistant

### AI-Powered Accessibility for Everyone

**IBM AI Builders Challenge 2026 — July Challenge**

**Challenge Theme:** Reimagine Creative Industries with AI

AISense empowers people with visual, hearing, and speech impairments through intelligent computer vision, voice assistance, navigation, and accessible technology.

<br>

[![Flutter](https://img.shields.io/badge/Frontend-Flutter-02569B?logo=flutter)](https://flutter.dev/)
[![FastAPI](https://img.shields.io/badge/Backend-FastAPI-009688?logo=fastapi)](https://fastapi.tiangolo.com/)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?logo=python)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![IBM Bob](https://img.shields.io/badge/Developed%20with-IBM%20Bob-052FAD)](https://www.ibm.com/)

</div>

---

## Table of Contents

* [Project Overview](#project-overview)
* [Challenge Theme](#challenge-theme)
* [Problem Statement](#problem-statement)
* [Proposed Solution](#proposed-solution)
* [Key Features](#key-features)
* [Core AI Modules](#core-ai-modules)
* [Innovation](#innovation)
* [System Architecture](#system-architecture)
* [AI Architecture](#ai-architecture)
* [AI Technologies](#ai-technologies)
* [Application Workflow](#application-workflow)
* [Real-Time Processing](#real-time-processing)
* [Technology Stack](#technology-stack)
* [Project Structure](#project-structure)
* [Getting Started](#getting-started)
* [Environment Variables](#environment-variables)
* [API Endpoints](#api-endpoints)
* [Screenshots](#screenshots)
* [Demo Video](#demo-video)
* [Live Application](#live-application)
* [IBM Bob Integration](#ibm-bob-integration)
* [Real-World Impact](#real-world-impact)
* [Future Improvements](#future-improvements)
* [Team Members](#team-members)
* [Challenge Submission](#challenge-submission)
* [Submission Checklist](#submission-checklist)
* [Contributing](#contributing)
* [License](#license)
* [Acknowledgements](#acknowledgements)
* [Support](#support)

---

## Project Overview

**AISense – Universal Accessibility Assistant** is an AI-powered accessibility platform designed to support people with visual, hearing, and speech impairments.

The application combines multiple assistive services into one unified platform, enabling users to:

* Recognize nearby objects
* Read printed text
* Understand complete scenes
* Identify currency notes
* Detect colors
* Recognize traffic signs
* Communicate through sign language
* Detect human faces
* Receive navigation guidance
* Hear AI-generated results through voice feedback

Instead of requiring users to install and manage several separate accessibility applications, AISense provides a consistent and accessible interface for multiple real-world assistance tasks.

The platform is developed using a cross-platform **Flutter frontend**, a scalable **FastAPI backend**, and specialized artificial intelligence technologies such as **YOLOv8, MediaPipe, EasyOCR, Google Gemini AI, OpenCV, and OpenRouteService**.

AISense was developed for the **IBM AI Builders Challenge 2026**, with **IBM Bob** serving as the primary AI-assisted development tool during planning, system design, implementation, debugging, testing, documentation, and deployment preparation.

---

## Challenge Theme

### Reimagine Creative Industries with AI

Artificial Intelligence is transforming how people interact with digital products, communication systems, visual information, and real-world environments.

AISense applies AI to accessibility by helping people with disabilities access information, understand their surroundings, communicate more effectively, and navigate unfamiliar environments with greater confidence.

The project focuses on:

* AI-powered accessibility
* Assistive computer vision
* Real-time object recognition
* Sign language recognition
* OCR-based text reading
* Generative AI scene understanding
* Currency recognition
* Traffic sign detection
* Smart navigation
* Voice-based assistance
* Inclusive interface design

AISense demonstrates how multiple AI technologies can operate together as one intelligent accessibility assistant.

---

## Problem Statement

People with visual, hearing, and speech impairments may experience difficulties while performing common everyday activities.

These challenges can include:

* Identifying nearby people and objects
* Reading books, notices, documents, labels, and signboards
* Recognizing currency denominations
* Understanding traffic signs
* Communicating through sign language
* Identifying colors
* Navigating unfamiliar locations
* Understanding complete scenes and surroundings
* Receiving immediate assistance in public places
* Accessing information independently

Many existing accessibility applications address only one problem at a time. A user may require one application for OCR, another for object detection, another for navigation, and another for sign language recognition.

This creates a fragmented experience and requires users to repeatedly switch between different applications and interfaces.

The challenge is not simply:

> “How can AI detect an object?”

The broader challenge is:

> “How can multiple AI-powered accessibility services be combined into one intelligent assistant that provides real-time, context-aware, and easy-to-use support?”

---

## Proposed Solution

AISense introduces a unified AI-powered accessibility platform where several specialized services work together through a centralized backend.

The platform includes:

* Object Detection
* Sign Language Recognition
* OCR Text Reading
* Currency Detection
* Color Detection
* AI Scene Description
* Traffic Sign Detection
* Face Detection
* Smart Navigation
* Voice Feedback

The Flutter application captures information using the device camera, uploaded images, voice commands, location services, and user-provided destination details.

The captured data is securely sent to the FastAPI backend. The backend validates the request, selects the appropriate AI module, processes the input, and returns a structured response.

AISense presents results through:

* Spoken voice feedback
* On-screen text
* Detection labels
* Visual bounding boxes
* Navigation instructions
* Accessible alerts
* Error notifications

This architecture creates a consistent user experience across multiple accessibility services.

---

## Key Features

| Feature                    | Description                                                          |
| -------------------------- | -------------------------------------------------------------------- |
| Real-Time Object Detection | Identifies nearby objects using computer vision                      |
| AI Scene Description       | Generates natural-language descriptions of complete environments     |
| Sign Language Recognition  | Converts supported hand gestures into readable text                  |
| OCR Text Reader            | Extracts text from images, documents, notices, and labels            |
| Currency Detection         | Recognizes currency notes and announces their denominations          |
| Color Detection            | Identifies dominant or selected colors                               |
| Face Detection             | Detects human faces and their positions in camera input              |
| Traffic Sign Detection     | Recognizes important road and warning signs                          |
| Smart Navigation           | Provides route guidance, distance information, and spoken directions |
| Voice Feedback             | Converts important AI results into speech                            |
| Accessible Interface       | Uses readable layouts, clear controls, and large interaction areas   |
| Cross-Platform Support     | Supports Android, iOS, and Flutter Web                               |
| Modular Architecture       | Allows AI modules to be maintained and upgraded independently        |
| FastAPI Backend            | Provides structured, scalable, and documented REST APIs              |
| Responsive Design          | Adapts to different device sizes and screen orientations             |

---

## Core AI Modules

### Object Detection

The object detection module uses **YOLOv8** to identify common objects from live camera input or uploaded images.

It can recognize objects such as:

* People
* Chairs
* Tables
* Vehicles
* Bags
* Bottles
* Mobile phones
* Animals
* Doors
* Household items

Detected objects can be highlighted using bounding boxes, displayed as text, and announced using voice feedback.

This feature helps visually impaired users understand their immediate surroundings and identify possible obstacles.

---

### Sign Language Recognition

The sign language recognition module uses **MediaPipe** and computer vision to analyze hand landmarks and supported gestures.

Recognized gestures are converted into readable text and can also be presented through voice output.

This module can support communication between:

* Hearing-impaired users
* Speech-impaired users
* Family members
* Teachers
* Healthcare professionals
* People unfamiliar with sign language

Future versions can expand the module to support complete sentences and additional regional sign languages.

---

### OCR Text Reader

The OCR module uses **EasyOCR** to extract text from camera images and uploaded files.

It can process content such as:

* Books
* Notices
* Documents
* Signboards
* Medicine labels
* Product packages
* Bills
* Menus
* Printed instructions
* Educational materials

Extracted text is displayed on screen and can be read aloud using text-to-speech technology.

---

### Currency Detection

The currency detection module analyzes currency notes and identifies their denominations.

The detected value can be displayed and announced using voice feedback.

This feature is designed to help visually impaired users:

* Verify currency notes
* Complete financial transactions
* Avoid denomination confusion
* Increase independence while shopping or travelling

Model availability depends on the trained currency dataset and model weights installed in the deployment environment.

---

### AI Scene Description

The scene description module uses **Google Gemini AI** to generate a natural-language explanation of the user’s surroundings.

Unlike traditional object detection, which identifies individual objects, scene description provides broader environmental context.

Example:

> “A person is standing near a pedestrian crossing. A red car is approaching from the left, and a traffic signal is visible ahead.”

This feature helps users understand relationships between people, objects, locations, and potential hazards.

---

### Traffic Sign Detection

The traffic sign detection module identifies important road signs and warning symbols.

Supported categories may include:

* Stop
* No Entry
* Pedestrian Crossing
* Speed Limit
* School Zone
* No Parking
* Turn Left
* Turn Right
* Road Work
* Warning Signs

Detected signs can be displayed visually and announced through voice feedback.

---

### Color Detection

The color detection module uses **OpenCV** to identify the dominant or selected color of an object or image region.

It can assist users with:

* Selecting clothes
* Identifying products
* Sorting objects
* Recognizing traffic-light colors
* Understanding visual content
* Completing educational activities

---

### Face Detection

The face detection module uses **OpenCV** to identify human faces in images and live camera input.

It can detect:

* The number of visible faces
* The approximate position of each face
* Face regions within an image

Future versions may support authorized person recognition while following appropriate privacy and security standards.

---

### Smart Navigation

The navigation module uses **OpenRouteService** and device location services to provide route information.

It supports:

* Destination search
* Route generation
* Distance estimation
* Spoken directions
* Turn-by-turn instructions
* Travel assistance

The module is designed to help users navigate unfamiliar environments with greater confidence.

---

### Voice Feedback

AISense uses **Flutter Text-to-Speech** to convert important results into spoken audio.

Voice feedback can be provided for:

* Detected objects
* OCR-extracted text
* Currency denominations
* Scene descriptions
* Traffic signs
* Navigation directions
* Warnings
* Application errors

This enables users to receive information without depending entirely on visual content.

---

## Innovation

Traditional accessibility applications commonly follow a single-purpose model:

```text
User
  │
  ▼
One AI Model
  │
  ▼
One Accessibility Feature
```

AISense follows a unified accessibility model:

```text
                         USER
                           │
                           ▼
              AISense Universal Assistant
                           │
       ┌───────────────────┼───────────────────┐
       ▼                   ▼                   ▼
 Computer Vision         OCR AI        Sign Language AI
       │                   │                   │
       ├────────────┬───────┴───────┬──────────┤
       ▼            ▼               ▼          ▼
  Object AI    Currency AI      Scene AI   Navigation AI
       │            │               │          │
       └────────────┴───────┬───────┴──────────┘
                            ▼
                Intelligent Accessibility
```

The main innovation of AISense is the integration of several assistive AI technologies into one consistent application.

This unified architecture:

* Reduces dependence on multiple applications
* Simplifies the user experience
* Enables shared backend services
* Supports context-aware assistance
* Improves accessibility and digital inclusion
* Allows new AI modules to be added easily
* Creates a foundation for personalized assistive technology

---

## System Architecture

```text
┌─────────────────────────────────────────────────────────┐
│                         USER                            │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│                   FLUTTER FRONTEND                      │
│                                                         │
│  • Landing Page                                         │
│  • Authentication                                       │
│  • Accessibility Dashboard                              │
│  • Camera Interface                                     │
│  • Voice Feedback                                       │
│  • Navigation Interface                                 │
│  • Settings                                             │
└────────────────────────────┬────────────────────────────┘
                             │
                         REST API
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│                    FASTAPI BACKEND                      │
│                                                         │
│  • Authentication                                       │
│  • Request Validation                                   │
│  • API Management                                       │
│  • AI Service Coordination                              │
│  • Database Operations                                  │
│  • Error Handling                                       │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│                       AI MODULES                        │
│                                                         │
│  • YOLOv8 Object Detection                              │
│  • MediaPipe Sign Language Recognition                  │
│  • EasyOCR Text Recognition                             │
│  • Google Gemini AI Scene Description                   │
│  • OpenCV Face and Color Detection                      │
│  • Currency Recognition                                 │
│  • Traffic Sign Detection                               │
│  • OpenRouteService Navigation                          │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│                       DATABASE                          │
│                                                         │
│  • SQLite for Development                               │
│  • PostgreSQL for Production                            │
└─────────────────────────────────────────────────────────┘
```

---

## AI Architecture

AISense follows a modular AI architecture. Each accessibility feature is implemented as an independent service and accessed through the centralized FastAPI backend.

```text
                              USER
                                │
                                ▼
                       FLUTTER APPLICATION
                                │
                         REST API REQUEST
                                │
                                ▼
                       FASTAPI BACKEND
                                │
        ┌───────────────┬───────┼────────┬───────────────┐
        ▼               ▼       ▼        ▼               ▼
      YOLOv8         EasyOCR  MediaPipe  Gemini AI     OpenCV
        │               │       │        │               │
        ▼               ▼       ▼        ▼               ▼
      Object           OCR     Sign     Scene         Face and
     Detection        Reader  Language Description   Color Detection
        │               │       │        │               │
        └───────────────┴───────┼────────┴───────────────┘
                                │
               ┌────────────────┼────────────────┐
               ▼                ▼                ▼
          Currency AI      Traffic Sign AI   Navigation AI
               │                │                │
               └────────────────┼────────────────┘
                                ▼
                     SQLite / PostgreSQL
```

This architecture improves:

* Maintainability
* Scalability
* Testing
* Code organization
* Error isolation
* AI model replacement
* Future module integration

---

## AI Technologies

| Feature                   | Technology                   |
| ------------------------- | ---------------------------- |
| Object Detection          | YOLOv8                       |
| Sign Language Recognition | MediaPipe                    |
| OCR Text Reading          | EasyOCR                      |
| AI Scene Description      | Google Gemini AI             |
| Face Detection            | OpenCV                       |
| Color Detection           | OpenCV                       |
| Currency Detection        | Custom Computer Vision Model |
| Traffic Sign Detection    | YOLO / Computer Vision       |
| Smart Navigation          | OpenRouteService API         |
| Voice Feedback            | Flutter Text-to-Speech       |

Each technology is selected for a specialized task while maintaining modularity and efficient response handling.

---

## Application Workflow

### Step 1 — Select an Accessibility Service

The user opens AISense and selects a service such as object detection, OCR reading, currency detection, scene description, sign language recognition, or navigation.

### Step 2 — Capture Input

AISense collects input through:

* Live camera feed
* Uploaded image
* Voice command
* Device microphone
* GPS location
* Destination input

### Step 3 — Send API Request

The Flutter application securely sends the captured data to the FastAPI backend using REST API requests.

### Step 4 — Route the Request

The backend validates the request and routes it to the appropriate AI module.

### Step 5 — Process the Input

The selected AI technology processes the input.

Examples:

* YOLOv8 detects objects
* EasyOCR extracts text
* MediaPipe analyzes hand landmarks
* Gemini AI describes scenes
* OpenCV detects faces and colors
* OpenRouteService generates routes

### Step 6 — Generate Structured Results

The backend generates a structured JSON response containing relevant information such as:

* Detection results
* Confidence scores
* Recognized text
* Scene descriptions
* Navigation instructions
* Processing status
* Error information

### Step 7 — Present the Result

AISense communicates the result through:

* On-screen text
* Voice feedback
* Visual labels
* Bounding boxes
* Accessible alerts
* Navigation directions

---

## Real-Time Processing

AISense is designed to provide responsive accessibility assistance through optimized AI processing.

Performance can be improved using:

* Image resizing
* Frame skipping
* Model caching
* Asynchronous API processing
* Optimized image compression
* Lightweight AI models
* Device-side preprocessing
* Cloud-based inference

Actual response time depends on the device, network connection, installed AI models, selected feature, and hosting environment.

---

## Technology Stack

### Frontend

* Flutter
* Dart
* Material Design
* Flutter Camera
* Flutter Text-to-Speech
* HTTP
* Provider
* Geolocator
* Image Picker

### Backend

* Python 3.11+
* FastAPI
* Uvicorn
* SQLAlchemy
* Pydantic
* REST APIs

### Artificial Intelligence

* YOLOv8
* Google Gemini AI
* MediaPipe
* EasyOCR
* OpenCV
* Custom Computer Vision Models

### Database

* SQLite for development
* PostgreSQL for production

### External Services

* OpenRouteService
* Google Gemini API

### Development Tools

* IBM Bob
* Visual Studio Code
* Git
* GitHub
* Docker

### Deployment

* Vercel
* Render

---

## Project Structure

```text
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
```

---

## Getting Started

### Prerequisites

Install the following software before running the project:

* Git
* Python 3.11 or later
* Flutter SDK
* Android Studio
* Visual Studio Code
* Google Chrome for Flutter Web testing

---

### Clone the Repository

```bash
git clone https://github.com/paulrajvictor165-design/SignSense-AI.git
cd SignSense-AI
```

---

### Backend Setup

Navigate to the backend directory:

```bash
cd backend
```

Create a virtual environment.

#### Windows

```bash
python -m venv venv
venv\Scripts\activate
```

#### Linux or macOS

```bash
python3 -m venv venv
source venv/bin/activate
```

Install the required packages:

```bash
pip install -r requirements.txt
```

Create the environment file.

#### Windows

```bash
copy .env.example .env
```

#### Linux or macOS

```bash
cp .env.example .env
```

Configure the required environment variables and start the server:

```bash
uvicorn app:app --host 0.0.0.0 --port 5000 --reload
```

Backend address:

```text
http://localhost:5000
```

Health-check address:

```text
http://localhost:5000/health
```

---

### Flutter Frontend Setup

Navigate to the Flutter application:

```bash
cd flutter_app
```

Install Flutter packages:

```bash
flutter pub get
```

Run on a connected device or emulator:

```bash
flutter run
```

Run in Google Chrome:

```bash
flutter run -d chrome
```

Build an Android APK:

```bash
flutter build apk
```

Build the web application:

```bash
flutter build web
```

---

## Environment Variables

Create a `.env` file inside the backend directory.

```env
GEMINI_API_KEY=your_gemini_api_key
OPENROUTESERVICE_API_KEY=your_openrouteservice_api_key
DATABASE_URL=sqlite:///aisense.db
SECRET_KEY=replace_with_a_secure_secret_key
HOST=0.0.0.0
PORT=5000
```

> Never commit your `.env` file, private API keys, database credentials, or application secrets to GitHub.

For production deployment, store sensitive values using the environment-variable settings provided by the hosting platform.

---

## API Endpoints

| Method | Endpoint                | Description                                  |
| ------ | ----------------------- | -------------------------------------------- |
| `GET`  | `/health`               | Returns backend health and model status      |
| `POST` | `/api/detect/objects`   | Detects objects in an image                  |
| `POST` | `/api/ocr/read`         | Extracts text from an image                  |
| `POST` | `/api/currency/detect`  | Detects a currency denomination              |
| `POST` | `/api/scene/describe`   | Generates a scene description                |
| `POST` | `/api/sign/detect`      | Recognizes a supported sign-language gesture |
| `POST` | `/api/faces/detect`     | Detects human faces                          |
| `POST` | `/api/colors/detect`    | Detects dominant colors                      |
| `POST` | `/api/traffic/detect`   | Detects traffic signs                        |
| `POST` | `/api/navigation/route` | Generates navigation information             |

API availability may depend on the models, datasets, API keys, and environment configuration installed on the server.

---

## Screenshots

Add screenshots inside the `screenshots` directory.

### Landing Page

```markdown
![AISense Landing Page](screenshots/landing-page.png)
```

### Accessibility Dashboard

```markdown
![AISense Dashboard](screenshots/dashboard.png)
```

### Object Detection

```markdown
![Object Detection](screenshots/object-detection.png)
```

### OCR Text Reader

```markdown
![OCR Text Reader](screenshots/ocr-reader.png)
```

### AI Scene Description

```markdown
![AI Scene Description](screenshots/scene-description.png)
```

### Recommended Screenshots

* Landing Page
* Login Page
* Accessibility Dashboard
* Live Camera
* Object Detection
* Sign Language Recognition
* OCR Text Reader
* Currency Detection
* AI Scene Description
* Traffic Sign Detection
* Color Detection
* Navigation Assistance
* Settings Page

---

## Demo Video

The project demonstration video should include:

1. Project introduction
2. Problem statement
3. Proposed solution
4. Main AI features
5. Live application demonstration
6. AI workflow
7. IBM Bob usage
8. Real-world impact
9. Future improvements

**YouTube Demo:** `[Add Public YouTube Video URL]`

---

## Live Application

| Resource             | Link                                                    |
| -------------------- | ------------------------------------------------------- |
| Frontend Application | https://sign-sense-ai-princy-23pt.vercel.app            |
| Backend API          | https://signsense-ai-princy.onrender.com                |
| Backend Health Check | https://signsense-ai-princy.onrender.com/health         |
| GitHub Repository    | https://github.com/paulrajvictor165-design/SignSense-AI |
| Demo Video           | `[Add Public YouTube Video URL]`                        |

---

## IBM Bob Integration

IBM Bob served as the primary AI-assisted development tool throughout the development of AISense.

IBM Bob supported the project in:

* Understanding project requirements
* Planning the overall architecture
* Designing modular AI services
* Developing Flutter frontend components
* Building FastAPI backend APIs
* Connecting frontend and backend services
* Debugging API and deployment issues
* Improving interface accessibility
* Optimizing AI workflows
* Testing application functionality
* Preparing technical documentation
* Supporting deployment preparation

IBM Bob acted as an AI development partner across planning, implementation, debugging, testing, documentation, and deployment while helping maintain the project’s accessibility goals and technical architecture.

---

## Real-World Impact

AISense is designed to improve accessibility and independence by bringing multiple AI-powered assistive technologies into one platform.

The application can help users perform everyday activities with greater confidence, including:

* Identifying nearby objects
* Reading printed information
* Recognizing currency notes
* Understanding complete scenes
* Communicating through supported signs
* Identifying colors
* Recognizing traffic signs
* Navigating unfamiliar environments

### Potential Users

* Visually impaired individuals
* Hearing-impaired individuals
* Speech-impaired individuals
* Senior citizens
* Caregivers and family members
* Hospitals and rehabilitation centres
* Educational institutions
* Accessibility organizations
* Non-governmental organizations

### Potential Benefits

* Supports independent living
* Improves access to information
* Enhances communication
* Increases personal safety
* Reduces dependence on multiple applications
* Promotes inclusive technology
* Encourages equal participation in digital environments

AISense demonstrates how Artificial Intelligence can help reduce accessibility barriers and contribute to a more inclusive future.

---

## Future Improvements

Future versions of AISense may include:

* Multilingual voice assistance
* Personalized AI assistance
* Offline AI model support
* Smart-glasses integration
* Smartwatch compatibility
* Emergency SOS with live location
* Medicine-label recognition
* Shopping assistance
* Indoor navigation
* Real-time language translation
* Additional regional sign languages
* Complete sign-language sentence recognition
* IoT-enabled accessibility devices
* Cloud-based model inference
* AI modules through a plugin architecture

These improvements can further enhance usability, personalization, accessibility, and real-world adoption.

---

## Team Members

AISense was developed through collaborative planning, implementation, testing, documentation, and deployment preparation.

| Team Member   | Role                                | Contribution                                                                                                                                                                           |
| ------------- | ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **V. PRINCY** | Team Lead and Full-Stack Developer  | Project planning, system architecture, Flutter frontend development, FastAPI backend integration, AI module coordination, testing, deployment, documentation, and challenge submission |
| **S. KAVYA**  | Team Member and Project Contributor | Feature development support, application testing, accessibility validation, documentation, presentation preparation, and project submission support                                    |

The team worked together to develop an inclusive AI-powered accessibility platform that combines computer vision, voice assistance, intelligent navigation, and multiple accessibility services within a single application.

---

## Challenge Submission

| Field                    | Details                                                   |
| ------------------------ | --------------------------------------------------------- |
| Project                  | AISense – Universal Accessibility Assistant               |
| Tagline                  | AI-Powered Universal Accessibility for Everyone           |
| Challenge                | IBM AI Builders Challenge 2026                            |
| Challenge Period         | July 2026                                                 |
| Theme                    | Reimagine Creative Industries with AI                     |
| Team Lead                | V. PRINCY                                                 |
| Team Member              | S. KAVYA                                                  |
| Team Size                | 2 Members                                                 |
| Primary Development Tool | IBM Bob                                                   |
| Application Type         | AI-Powered Accessibility Platform                         |
| Frontend                 | Flutter                                                   |
| Backend                  | FastAPI                                                   |
| AI Technologies          | YOLOv8, MediaPipe, EasyOCR, Gemini AI, and OpenCV         |
| Database                 | SQLite / PostgreSQL                                       |
| Deployment               | Vercel and Render                                         |
| Category                 | Accessibility AI / Computer Vision / Assistive Technology |

---

## Submission Checklist

* [x] AISense prototype developed
* [x] Flutter frontend created
* [x] FastAPI backend created
* [x] Frontend connected to backend
* [x] Object detection module added
* [x] OCR text reader added
* [x] AI scene description module added
* [x] Face detection module added
* [x] Color detection module added
* [x] Traffic sign module included
* [x] Navigation module included
* [x] IBM Bob usage documented
* [x] Team members documented
* [x] README documentation prepared
* [x] Environment configuration documented
* [x] MIT License included
* [x] Frontend deployed on Vercel
* [x] Backend deployed on Render
* [x] Public GitHub repository added
* [ ] Verify the trained currency model in production
* [ ] Verify the trained sign-language model in production
* [ ] Add final application screenshots
* [ ] Add public demo-video URL
* [ ] Add IBM SkillsBuild certificate evidence

---

## Contributing

Contributions are welcome.

To contribute:

1. Fork the repository.
2. Create a new feature branch.

```bash
git checkout -b feature/feature-name
```

3. Commit your changes.

```bash
git commit -m "Add feature description"
```

4. Push the branch.

```bash
git push origin feature/feature-name
```

5. Open a Pull Request.

Please ensure that your changes follow the project structure and coding standards.

---

## License

This project is licensed under the **MIT License**.

See the [LICENSE](LICENSE) file for complete details.

---

## Acknowledgements

Special thanks to the technologies, tools, and communities that supported the development of AISense:

* IBM AI Builders Challenge
* IBM Bob
* IBM SkillsBuild
* Flutter
* FastAPI
* YOLOv8
* Google Gemini AI
* MediaPipe
* EasyOCR
* OpenCV
* OpenRouteService
* SQLite
* PostgreSQL
* Git and GitHub
* Open-source AI community

---

## Support

If you found this project useful, please consider giving the GitHub repository a ⭐.

Your support encourages continued development and helps promote accessibility through Artificial Intelligence.

---

<div align="center">

# ♿ AISense

### Universal Accessibility Assistant

**Empowering Accessibility Through Artificial Intelligence**

### Team

**V. PRINCY — Team Lead**

**S. KAVYA — Team Member**

Built with dedication for the **IBM AI Builders Challenge 2026**

</div>
