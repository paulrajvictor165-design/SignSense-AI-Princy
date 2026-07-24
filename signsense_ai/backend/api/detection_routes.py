"""
SignSense AI — Detection Routes (Controller Layer)
===================================================
HTTP controller for all object-detection endpoints.

Architecture (Module 2)
------------------------
Before: Routes contained YOLO inference, HSV analysis, confidence filtering,
        voice message building, DB persistence, and categorisation (297 lines).

After:  Routes are thin HTTP controllers — they:
        1. Validate the incoming image file (@require_image_file).
        2. Read image bytes.
        3. Delegate entirely to DetectionService.
        4. Return the JSON response.

        All business logic lives in services/detection_service.py.

API contract
------------
All endpoints, URLs, HTTP methods, and response shapes are 100% backward
compatible with the original implementation.  The Flutter client requires
zero changes.

Endpoints
---------
POST /api/detect/objects   → detect everyday objects
POST /api/detect/traffic   → detect traffic signals + colour
POST /api/detect/vehicles  → detect approaching vehicles
POST /api/detect/faces     → detect faces with MediaPipe
POST /api/detect/colors    → detect dominant scene colours
"""

import logging
from flask import Blueprint, request, jsonify

from middleware.request_validator import require_image_file
from services.detection_service import detection_service

logger = logging.getLogger(__name__)
detection_bp = Blueprint("detection", __name__)


@detection_bp.route("/objects", methods=["POST"])
@require_image_file
def detect_objects():
    """Detect everyday objects in the scene."""
    image_bytes = request.files["image"].read()
    result = detection_service.detect_objects(image_bytes)
    return jsonify(result)


@detection_bp.route("/traffic", methods=["POST"])
@require_image_file
def detect_traffic():
    """Detect traffic signals and determine their colour state."""
    image_bytes = request.files["image"].read()
    result = detection_service.detect_traffic(image_bytes)
    return jsonify(result)


@detection_bp.route("/vehicles", methods=["POST"])
@require_image_file
def detect_vehicles():
    """Detect vehicles and produce directional voice warnings."""
    image_bytes = request.files["image"].read()
    result = detection_service.detect_vehicles(image_bytes)
    return jsonify(result)


@detection_bp.route("/faces", methods=["POST"])
@require_image_file
def detect_faces():
    """Detect and report faces using MediaPipe."""
    image_bytes = request.files["image"].read()
    result = detection_service.detect_faces(image_bytes)
    return jsonify(result)


@detection_bp.route("/colors", methods=["POST"])
@require_image_file
def detect_colors():
    """Detect dominant colours in the scene."""
    image_bytes = request.files["image"].read()
    result = detection_service.detect_colors(image_bytes)
    return jsonify(result)
