"""
[DEPRECATED — Module 2 refactor]
=================================
This file is the PRE-REFACTOR version of the scene route.
It is NOT registered in app.py and NOT used at runtime.
It is kept for reference purposes only.

The production implementation is:
  signsense_ai/backend/api/scene_routes.py   ← thin controller
  signsense_ai/backend/services/scene_service.py ← business logic

DO NOT import or register this file.
"""

import os
import base64
import logging
from flask import Blueprint, request, jsonify
import google.generativeai as genai

logger = logging.getLogger(__name__)
scene_bp = Blueprint("scene", __name__)

# Configure Gemini on module load
_GEMINI_CONFIGURED = False


def _configure_gemini():
    global _GEMINI_CONFIGURED
    if not _GEMINI_CONFIGURED:
        api_key = os.getenv("GEMINI_API_KEY", "")
        if api_key:
            genai.configure(api_key=api_key)
            _GEMINI_CONFIGURED = True
        else:
            logger.warning("GEMINI_API_KEY not set — scene description will fail.")


SCENE_PROMPT = """
You are an AI assistant helping a visually impaired or blind person understand their surroundings.

Analyze this image and provide a clear, concise, accessible description.
Format your response as natural speech — no markdown, no bullets.

Describe:
1. What type of environment (indoors/outdoors, road, room, etc.)
2. Key objects and their positions (left, right, center, ahead)
3. Any people and what they are doing
4. Any hazards or obstacles
5. Any text visible (signs, labels)
6. Lighting conditions

Keep the description under 5 sentences. Use simple, clear language.
Start with the most important safety information first.
"""


@scene_bp.route("/describe", methods=["POST"])
def describe_scene():
    """
    Accept an image, send to Gemini Vision API, return natural language description.
    """
    _configure_gemini()

    if "image" not in request.files:
        return jsonify({"error": "No image provided"}), 400

    image_bytes = request.files["image"].read()
    mime_type = request.files["image"].mimetype or "image/jpeg"

    try:
        model = genai.GenerativeModel(model_name="gemini-1.5-flash")

        image_part = {
            "mime_type": mime_type,
            "data": base64.b64encode(image_bytes).decode("utf-8"),
        }

        response = model.generate_content([SCENE_PROMPT, image_part])
        description = response.text.strip()

        return jsonify({
            "description": description,
            "voice_message": description,
        })

    except Exception as e:
        logger.error(f"Gemini scene description error: {e}")

        # Graceful fallback using YOLO labels
        return jsonify({
            "description": "Scene analysis unavailable. Check your Gemini API key.",
            "voice_message": "I could not analyze the scene right now. Please check your internet connection.",
            "error": str(e),
        }), 500
