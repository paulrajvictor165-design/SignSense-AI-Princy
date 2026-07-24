"""
SignSense AI — OCR Routes (Controller Layer)
=============================================
HTTP controller for text extraction endpoint.

Architecture (Module 2)
------------------------
Before: Route contained EasyOCR call, confidence filtering, text joining,
        DB persistence — all in a single 65-line route function.

After:  Thin controller — validates, delegates to OcrService, returns JSON.
        All business logic lives in services/ocr_service.py.

API contract
------------
POST /api/ocr/read  →  {text, blocks, count, voice_message}
Response shape is 100% backward compatible.
"""

import logging
from flask import Blueprint, request, jsonify

from middleware.request_validator import require_image_file
from services.ocr_service import ocr_service

logger = logging.getLogger(__name__)
ocr_bp = Blueprint("ocr", __name__)


@ocr_bp.route("/read", methods=["POST"])
@require_image_file
def read_text():
    """Extract text from an image using EasyOCR (English + Hindi)."""
    image_bytes = request.files["image"].read()
    try:
        result = ocr_service.extract_text(image_bytes)
        return jsonify(result)
    except RuntimeError as exc:
        logger.error("OCR route error: %s", exc)
        return jsonify({
            "text": "",
            "blocks": [],
            "count": 0,
            "voice_message": "Could not read text. Please try again.",
        }), 500

    except Exception as exc:
        logger.exception("Unexpected OCR route error: %s", exc)
        return jsonify({
            "text": "",
            "blocks": [],
            "count": 0,
            "voice_message": "Text reading failed unexpectedly. Please try again.",
        }), 500    