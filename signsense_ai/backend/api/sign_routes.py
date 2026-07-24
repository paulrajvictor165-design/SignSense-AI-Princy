"""
SignSense AI — Sign Language Recognition Routes

Phase D: New blueprint registered at /api/sign/*.

Endpoints
---------
POST /api/sign/recognize
    Full sign recognition: MediaPipe hand landmarks → rule-based ISL classifier.
    Returns sign_label, confidence, description, voice_message, low_confidence.

POST /api/sign/landmarks
    Raw MediaPipe hand-landmark extraction only.
    Returns landmark coordinates, handedness, detection confidence.
    Use this for debugging or building a custom classifier client-side.

All AI logic lives in SignLanguageService — this file is thin.
"""

import logging

from flask import Blueprint, request, jsonify

from middleware.request_validator import require_image_file
from middleware.error_handler import handle_service_error
from services.sign_language_service import sign_language_service

logger = logging.getLogger(__name__)

sign_bp = Blueprint("sign", __name__, url_prefix="/api/sign")


@sign_bp.route("/recognize", methods=["POST"])
@require_image_file
def recognize_sign():
    """
    Recognize a hand sign from a JPEG image.

    Multipart form field: image (JPEG)
    Returns a JSON object with sign_label, confidence, voice_message, etc.
    """
    image_bytes = request.files["image"].read()

    try:
        result = sign_language_service.recognize(image_bytes)
        return jsonify(result), 200
    except Exception as exc:
        logger.error("Sign recognition error: %s", exc, exc_info=True)
        return handle_service_error(exc)


@sign_bp.route("/landmarks", methods=["POST"])
@require_image_file
def get_landmarks():
    """
    Extract raw MediaPipe hand landmarks from a JPEG image.

    Returns normalized 21-landmark coordinates per hand, handedness,
    and detection confidence. Does NOT run sign classification.

    Multipart form field: image (JPEG)
    """
    image_bytes = request.files["image"].read()

    try:
        result = sign_language_service.get_landmarks(image_bytes)
        return jsonify(result), 200
    except Exception as exc:
        logger.error("Landmark extraction error: %s", exc, exc_info=True)
        return handle_service_error(exc)
