"""
AI Modules package — lazy loaders for all ML models.
Models are loaded once at startup and reused across requests.

Path resolution
---------------
YOLO model is resolved relative to this file's location so it works
regardless of the working directory from which Flask is launched.

Expected layout:
    signsense_ai/
    ├── backend/           ← Flask runs here
    │   └── ai_modules/    ← this file
    └── ml_models/
        └── yolov8/
            └── yolov8n.pt ← model lives here
"""

import os
import threading
import logging

from config.settings import settings

logger = logging.getLogger(__name__)

# ── Absolute path resolution ──────────────────────────────────────────────────
# __file__ is  .../signsense_ai/backend/ai_modules/__init__.py
# We go up three levels to reach the signsense_ai/ root, then into ml_models/.
_BACKEND_DIR   = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_PROJECT_DIR   = os.path.dirname(_BACKEND_DIR)          # signsense_ai/
_ML_MODELS_DIR = os.path.join(_PROJECT_DIR, "ml_models") # signsense_ai/ml_models/

# Default YOLO path — overridden by YOLO_MODEL_PATH in .env if set.
_DEFAULT_YOLO_PATH = os.path.join(_ML_MODELS_DIR, "yolov8", "yolov8n.pt")

# Thread-safe model registry
_models: dict = {}
_lock = threading.Lock()

# ── Model status tracking ─────────────────────────────────────────────────────
_model_status: dict = {
    "object_detection": {"loaded": False, "path": None, "reason": None},
    "sign_language":    {"loaded": False, "path": None, "reason": "No trained model installed"},
    "currency":         {"loaded": False, "path": None, "reason": "No trained model installed"},
    "mediapipe":        {"available": False, "reason": None},
}


def get_model_status() -> dict:
    """Return current model status for the /health endpoint."""
    # Check mediapipe availability
    try:
        import mediapipe  # noqa: F401
        _model_status["mediapipe"]["available"] = True
        _model_status["mediapipe"]["reason"] = None
    except ImportError as e:
        _model_status["mediapipe"]["available"] = False
        _model_status["mediapipe"]["reason"] = str(e)
    return dict(_model_status)


def get_yolo_model():
    """
    Lazy-load YOLOv8 model for object / vehicle / traffic detection.

    Path resolution order:
    1. YOLO_MODEL_PATH from .env (if set and non-empty).
    2. Default: signsense_ai/ml_models/yolov8/yolov8n.pt (absolute).

    Returns the loaded YOLO model.
    Raises FileNotFoundError with a clear message if the model file is missing.
    """
    with _lock:
        if "yolo" not in _models:
            from ultralytics import YOLO

            # Resolve path: prefer .env override, fall back to absolute default.
            env_path = settings.YOLO_MODEL_PATH.strip()
            if env_path and env_path != "yolov8n.pt":
                # User set an explicit path — use it as-is.
                model_path = env_path
            else:
                # Use absolute path derived from project layout.
                model_path = _DEFAULT_YOLO_PATH

            logger.info("Resolving YOLO model path: %s", model_path)

            if not os.path.isfile(model_path):
                msg = (
                    f"YOLO model not found at: {model_path}\n"
                    f"Expected: signsense_ai/ml_models/yolov8/yolov8n.pt\n"
                    f"Download it with: python backend/download_models.py"
                )
                logger.error(msg)
                _model_status["object_detection"]["loaded"] = False
                _model_status["object_detection"]["reason"] = f"File not found: {model_path}"
                raise FileNotFoundError(msg)

            logger.info("Loading YOLO model from: %s", model_path)
            try:
                _models["yolo"] = YOLO(model_path)
                _model_status["object_detection"]["loaded"] = True
                _model_status["object_detection"]["path"] = model_path
                _model_status["object_detection"]["reason"] = None
                logger.info("YOLO model loaded successfully.")
            except Exception as e:
                _model_status["object_detection"]["loaded"] = False
                _model_status["object_detection"]["reason"] = str(e)
                logger.error("YOLO model loading failed: %s", e)
                raise

        return _models["yolo"]


def get_easyocr_reader():
    """Lazy-load EasyOCR reader for text extraction."""
    with _lock:
        if "easyocr" not in _models:
            import easyocr
            logger.info("Loading EasyOCR reader (en, hi)...")
            _models["easyocr"] = easyocr.Reader(["en", "hi"], gpu=False)
        return _models["easyocr"]


def get_face_detector():
    """Lazy-load MediaPipe face detection."""
    with _lock:
        if "face" not in _models:
            import mediapipe as mp
            logger.info("Loading MediaPipe face detector...")
            _models["face"] = mp.solutions.face_detection.FaceDetection(
                model_selection=0,
                min_detection_confidence=0.5,
            )
        return _models["face"]


def get_face_mesh():
    """MediaPipe face mesh for expression/direction."""
    with _lock:
        if "face_mesh" not in _models:
            import mediapipe as mp
            _models["face_mesh"] = mp.solutions.face_mesh.FaceMesh(
                static_image_mode=True,
                max_num_faces=5,
                refine_landmarks=True,
            )
        return _models["face_mesh"]


def get_hand_detector():
    """Lazy-load MediaPipe Hands for sign language recognition."""
    with _lock:
        if "hands" not in _models:
            import mediapipe as mp
            logger.info("Loading MediaPipe Hands model...")
            _models["hands"] = mp.solutions.hands.Hands(
                static_image_mode=True,
                max_num_hands=1,
                min_detection_confidence=0.5,
            )
        return _models["hands"]
