"""
SignSense AI – Flask Backend
============================
Application factory.  All blueprints, middleware, and configuration are
assembled here.

Architecture changes (Module 1)
--------------------------------
* Central Settings class (config/settings.py) replaces scattered os.getenv()
  calls.  A RuntimeError at startup surfaces missing required keys
  immediately rather than silently at the first API request.
* Global error handlers (middleware/error_handler.py) standardise every
  error response to a consistent JSON envelope that the Flutter client
  can parse reliably.
* Request validator decorator (middleware/request_validator.py) is now
  available to all routes — individual routes opt in with @require_image_file.
"""

import logging
import os

from flask import Flask
from flask_cors import CORS
from dotenv import load_dotenv

# Load .env before importing settings so environment variables are available.
load_dotenv()

from config.settings import settings                          # noqa: E402
from middleware.error_handler import register_error_handlers  # noqa: E402

from api.detection_routes import detection_bp    # noqa: E402
from api.ocr_routes import ocr_bp                # noqa: E402
from api.scene_routes import scene_bp            # noqa: E402
from api.currency_routes import currency_bp      # noqa: E402
from api.navigation_routes import navigation_bp  # noqa: E402
from api.sign_routes import sign_bp              # noqa: E402
from database.db import init_db                  # noqa: E402
from ai_modules import get_model_status, get_yolo_model          # noqa: E402

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.DEBUG if settings.DEBUG else logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)


def create_app() -> Flask:
    """Application factory — create and configure the Flask app."""
    app = Flask(__name__)

    # Maximum upload size from settings (default 32 MB).
    app.config["MAX_CONTENT_LENGTH"] = settings.MAX_UPLOAD_BYTES
    app.config["SECRET_KEY"] = settings.SECRET_KEY

    # ── CORS ──────────────────────────────────────────────────────────────
    # Allow "*" in development; lock down to specific origins in production
    # by setting CORS_ORIGINS in .env.
    CORS(app, resources={r"/*": {"origins": "*"}})
    logger.info("CORS configured for all origins")

    # ── Database ──────────────────────────────────────────────────────────
    init_db(app)

    # ── Global error handlers ─────────────────────────────────────────────
    # Must be registered BEFORE blueprints so blueprint-raised exceptions
    # are also caught.
    register_error_handlers(app)

    # ── Blueprints ────────────────────────────────────────────────────────
    app.register_blueprint(detection_bp, url_prefix="/api/detect")
    app.register_blueprint(ocr_bp,       url_prefix="/api/ocr")
    app.register_blueprint(scene_bp,     url_prefix="/api/scene")
    app.register_blueprint(currency_bp,  url_prefix="/api/currency")
    app.register_blueprint(navigation_bp, url_prefix="/api/navigation")
    app.register_blueprint(sign_bp,       url_prefix="/api/sign")

    @app.get("/")
    def root():
        return {
            "status": "ok",
            "message": "SignSense AI Backend is running",
        }, 200

    # ── Health check ──────────────────────────────────────────────────────
    @app.route("/health")
    def health():
        model_status = get_model_status()
        gemini_configured = bool(settings.GEMINI_API_KEY)

        return {
            "status": "healthy",
            "service": "SignSense AI Backend",
            "debug": settings.DEBUG,
            "version": "1.0.0",
            "models": {
                "object_detection": {
                    "loaded": model_status["object_detection"]["loaded"],
                    "path": model_status["object_detection"]["path"],
                    "reason": model_status["object_detection"]["reason"],
                },
                "sign_language": {
                    "loaded": model_status["sign_language"]["loaded"],
                    "reason": model_status["sign_language"]["reason"],
                },
                "currency": {
                    "loaded": model_status["currency"]["loaded"],
                    "reason": model_status["currency"]["reason"],
                },
                "mediapipe": {
                    "available": model_status["mediapipe"]["available"],
                    "reason": model_status["mediapipe"]["reason"],
                },
                "scene_description": {
                    "configured": gemini_configured,
                    "reason": (
                        None
                        if gemini_configured
                        else "GEMINI_API_KEY not set in .env"
                    ),
                },
            },
        }, 200

    # Preload YOLO object-detection model
    try:
        get_yolo_model()
        logger.info(
            "YOLO object-detection model initialized successfully."
        )
    except Exception:
        logger.exception(
            "YOLO object-detection model initialization failed."
        )

    logger.info(
        "SignSense AI backend ready — port=%s  debug=%s",
        settings.PORT,
        settings.DEBUG,
    )

    return app  


if __name__ == "__main__":
    app = create_app()
    app.run(
        host="0.0.0.0",
        port=settings.PORT,
        debug=settings.DEBUG,
    )
