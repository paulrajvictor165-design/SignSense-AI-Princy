"""
SignSense AI — Currency Routes (Controller Layer)
==================================================
HTTP controller for Indian Rupee denomination detection.

Architecture (Module 2)
------------------------
Before: Route contained two full AI pipelines (YOLO + Gemini), denomination
        data, denomination parser, and os.getenv() calls — all in the routes
        file across 154 lines.

After:  Thin controller — validates, delegates to CurrencyService, returns JSON.
        All business logic lives in services/currency_service.py.

API contract
------------
POST /api/currency/detect  →  {denomination, currency, confidence, voice_message}
Response shape is 100% backward compatible.
"""

import logging
from flask import Blueprint, request, jsonify

from middleware.request_validator import require_image_file
from services.currency_service import currency_service

logger = logging.getLogger(__name__)
currency_bp = Blueprint("currency", __name__)


@currency_bp.route("/detect", methods=["POST"])
@require_image_file
def detect_currency():
    """
    Detect Indian Rupee denomination.
    Primary: Custom YOLOv8 currency model.
    Fallback: Gemini Vision API.
    """
    image_bytes = request.files["image"].read()
    result = currency_service.detect(image_bytes)
    return jsonify(result)
