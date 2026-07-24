"""
Model downloader script — downloads required AI models.
Run: python download_models.py
"""

import os
import sys
import urllib.request


def download_yolov8():
    """Download YOLOv8n (nano) — smallest and fastest model."""
    os.makedirs("../ml_models/yolov8", exist_ok=True)
    target = "../ml_models/yolov8/yolov8n.pt"

    if os.path.exists(target):
        print(f"✅ YOLOv8n already exists: {target}")
        return

    print("⬇️  Downloading YOLOv8n model...")
    try:
        from ultralytics import YOLO
        model = YOLO("yolov8n.pt")  # Auto-downloads from Ultralytics
        model.export()  # Ensures model is saved
        print("✅ YOLOv8n downloaded successfully.")
    except Exception as e:
        print(f"❌ YOLOv8n download failed: {e}")


def verify_easyocr():
    """Pre-download EasyOCR models for English and Hindi."""
    print("⬇️  Pre-loading EasyOCR models (en, hi)...")
    try:
        import easyocr
        reader = easyocr.Reader(["en", "hi"], gpu=False, verbose=False)
        print("✅ EasyOCR models ready.")
    except Exception as e:
        print(f"❌ EasyOCR setup failed: {e}")


def verify_mediapipe():
    """Verify MediaPipe face detection is available."""
    print("🔍 Verifying MediaPipe face detection...")
    try:
        import mediapipe as mp
        detector = mp.solutions.face_detection.FaceDetection(
            model_selection=0, min_detection_confidence=0.5
        )
        detector.close()
        print("✅ MediaPipe face detection ready.")
    except Exception as e:
        print(f"❌ MediaPipe check failed: {e}")


if __name__ == "__main__":
    print("\n🚀 SignSense AI — Model Setup\n")
    download_yolov8()
    verify_easyocr()
    verify_mediapipe()
    print("\n✅ All models ready! Run: python app.py\n")
