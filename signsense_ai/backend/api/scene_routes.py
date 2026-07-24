"""
SignSense AI — Scene Routes (Controller Layer)
===============================================
HTTP controller for Gemini-powered scene description endpoint.

Module 3 changes
-----------------
The route now optionally accepts structured AI context via JSON form fields
so the SceneService can build an enriched Gemini prompt (Module 3 requirement:
"Gemini must receive structured information from AI modules").

Optional form fields (all additive — old clients that omit them still work):
  detected_objects_json  — JSON array of detection dicts from /api/detect/*
  detected_text          — Plain text string from /api/ocr/read

API contract
------------
POST /api/scene/describe  →  {description, voice_message}         ← unchanged
                              + {processing_time_ms, pipeline_confidence,
                                 low_confidence, source_module}    ← new
Response is 100% backward compatible (new keys are additive).
"""

import json
import logging
from flask import Blueprint, request, jsonify

from middleware.request_validator import require_image_file
from services.scene_service import scene_service

logger = logging.getLogger(__name__)
scene_bp = Blueprint("scene", __name__)


@scene_bp.route("/describe", methods=["POST"])
@require_image_file
def describe_scene():
    """Analyse the scene using Gemini Vision and return a natural-language description.

    Accepts optional form fields detected_objects_json and detected_text for
    enriched prompt generation (Module 3 structured context injection).
    """
    image_file = request.files["image"]
    image_bytes = image_file.read()
    mime_type = image_file.mimetype or "image/jpeg"

    # ── Optional structured context (Module 3) ────────────────────────────
    # Old clients that don't send these fields will get the base prompt.
    detected_objects: list[dict] | None = None
    detected_text: str | None = None

    raw_objects_json = request.form.get("detected_objects_json", "").strip()
    if raw_objects_json:
        try:
            detected_objects = json.loads(raw_objects_json)
            if not isinstance(detected_objects, list):
                detected_objects = None
        except (json.JSONDecodeError, ValueError):
            logger.warning("describe_scene: could not parse detected_objects_json — ignoring.")
            detected_objects = None

    raw_text = request.form.get("detected_text", "").strip()
    if raw_text:
        detected_text = raw_text

    try:
        result = scene_service.describe_scene(
            image_bytes,
            mime_type,
            detected_objects=detected_objects,
            detected_text=detected_text,
        )
        return jsonify(result)
    except RuntimeError as exc:
        logger.error("Scene description route error: %s", exc)
        return jsonify({
            "description":   "Scene analysis unavailable. Please check your internet connection.",
            "voice_message": "I could not analyse the scene right now. Please try again.",
            "processing_time_ms":  0,
            "pipeline_confidence": 0.0,
            "low_confidence":      True,
            "source_module":       "gemini",
        }), 500
