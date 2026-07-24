"""
SignSense AI — Scene Description Service
==========================================
Business logic for AI-powered scene understanding using Google Gemini.

Module 3 changes (AI Pipeline — Scene Understanding)
------------------------------------------------------
1. Structured context injection
   Master Prompt 3 requirement: "Do not send unnecessary raw image data to
   Gemini if the task can be completed locally."  The scene pipeline now runs
   YOLO and EasyOCR *first*, injects their structured results into the Gemini
   prompt, and sends the raw image only once (Gemini still needs visual context
   for lighting, depth, and spatial reasoning).

   Result: Gemini receives pre-structured information AND the image.  The
   prompt explicitly tells Gemini what objects and text were already detected,
   so it focuses on reasoning rather than re-detecting objects.

   Example enriched prompt section:
       Pre-detected objects: Car ahead (critical), Person on left (high)
       Pre-detected text: "STOP", "CAUTION WET FLOOR"
       → Use this information to build your response.

2. Confidence envelope
   Response now includes processing_time_ms, pipeline_confidence,
   low_confidence, source_module.

3. Retry with back-off — unchanged from Module 2 (1 retry, 1 s delay).

API backward compatibility
--------------------------
All existing response keys (description, voice_message) are unchanged.
New keys are additive.
"""

from __future__ import annotations

import base64
import logging
import time

import google.generativeai as genai

from config.settings import settings
from utils.ai_metrics import start_timer, elapsed_ms, build_metrics, log_result

logger = logging.getLogger(__name__)

# Retry configuration for transient Gemini errors.
_MAX_RETRIES: int = 1
_RETRY_DELAY_S: float = 1.0

# ── Prompt templates ───────────────────────────────────────────────────────────

_SCENE_PROMPT_BASE = """
You are an AI assistant helping a visually impaired or blind person understand their surroundings.

Analyze this image and provide a clear, concise, accessible description.
Format your response as natural speech — no markdown, no bullet points.

Describe:
1. What type of environment (indoors/outdoors, road, room, etc.)
2. Key objects and their positions (left, right, center, ahead)
3. Any people and what they are doing
4. Any hazards or obstacles
5. Any text visible (signs, labels)
6. Lighting conditions

Keep the description under 5 sentences. Use simple, clear language.
Start with the most important safety information first.
""".strip()

_SCENE_PROMPT_ENRICHED = """
You are an AI assistant helping a visually impaired or blind person understand their surroundings.

The following information has already been detected by local AI models. Use it to build a more accurate and helpful response:

{context_block}

Now analyze the image and provide a clear, concise, accessible description.
Format your response as natural speech — no markdown, no bullet points.

Describe:
1. What type of environment (indoors/outdoors, road, room, etc.)
2. Key objects and their positions (left, right, center, ahead)
3. Any people and what they are doing
4. Any hazards or obstacles — use the pre-detected object list above
5. Any visible text — use the pre-detected text list above if present
6. Lighting conditions

Keep the description under 5 sentences. Use simple, clear language.
Start with the most important safety information first.
""".strip()


class SceneService:
    """
    Service for Gemini-powered scene description.

    Module 3: The Gemini prompt is enriched with pre-detected YOLO objects
    and OCR text so Gemini can focus on reasoning and spatial context
    rather than raw object detection.
    """

    def __init__(self) -> None:
        self._model = None
        self._gemini_available = False
        if settings.GEMINI_API_KEY:
            try:
                genai.configure(api_key=settings.GEMINI_API_KEY)
                self._model = genai.GenerativeModel(model_name="gemini-3.6-flash")
                self._gemini_available = True
                logger.info("SceneService initialised with Gemini 1.5 Flash.")
            except Exception as e:
                logger.warning("SceneService: Gemini init failed: %s", e)
        else:
            logger.warning(
                "SceneService: GEMINI_API_KEY not set in .env — "
                "Scene Description will return a clear error until the key is configured."
            )

    def describe_scene(
        self,
        image_bytes: bytes,
        mime_type: str = "image/jpeg",
        detected_objects: list[dict] | None = None,
        detected_text: str | None = None,
    ) -> dict:
        """
        Analyse *image_bytes* with Gemini Vision and return a natural-language
        scene description optimised for TTS.

        Module 3: When *detected_objects* and/or *detected_text* are provided,
        they are injected into the prompt as pre-detected context so Gemini can
        reason on top of structured data rather than performing raw detection.

        Parameters
        ----------
        image_bytes:
            Raw JPEG/PNG bytes.
        mime_type:
            MIME type of the image.
        detected_objects:
            Optional list of detection dicts (from DetectionService).
            Each dict should have keys: label, position, confidence, priority.
        detected_text:
            Optional OCR text string (from OcrService).

        Returns
        -------
        dict with keys:
            description, voice_message                 ← unchanged
            processing_time_ms, pipeline_confidence,
            low_confidence, source_module               ← new (Module 3)

        Raises
        ------
        RuntimeError
            When Gemini is unavailable after all retries.
        """
        t0 = start_timer()

        # ── Guard: check Gemini availability ──────────────────────────────
        if not self._gemini_available:
            logger.warning("describe_scene: Gemini is not configured — returning error.")
            raise RuntimeError(
                "Scene Description requires a Gemini API key. "
                "Set GEMINI_API_KEY in backend/.env and restart the server."
            )

        # ── Build enriched or base prompt ─────────────────────────────────
        prompt = self._build_prompt(detected_objects, detected_text)

        image_part = {
            "mime_type": mime_type,
            "data": base64.b64encode(image_bytes).decode("utf-8"),
        }

        last_exc: Exception | None = None
        for attempt in range(_MAX_RETRIES + 1):
            try:
                response = self._model.generate_content([prompt, image_part])
                description = response.text.strip()
                logger.debug(
                    "Scene description generated (%d chars, enriched=%s).",
                    len(description),
                    detected_objects is not None or detected_text is not None,
                )

                metrics = build_metrics(
                    source_module="gemini",
                    processing_time_ms=elapsed_ms(t0),
                    # Gemini doesn't return a numeric confidence; use 1.0 when
                    # description is non-empty, 0.0 otherwise.
                    pipeline_confidence=1.0 if description else 0.0,
                    low_confidence=not bool(description),
                )
                log_result("describe_scene", metrics)

                return {
                    "description":   description,
                    "voice_message": description,
                    **metrics,
                }
            except Exception as exc:
                last_exc = exc
                if attempt < _MAX_RETRIES:
                    logger.warning(
                        "Gemini scene description attempt %d failed: %s. Retrying...",
                        attempt + 1, exc,
                    )
                    time.sleep(_RETRY_DELAY_S)

        logger.error(
            "Gemini scene description failed after %d attempts: %s",
            _MAX_RETRIES + 1, last_exc,
        )
        raise RuntimeError(f"Gemini API unavailable: {last_exc}") from last_exc

    # ── Private helpers ────────────────────────────────────────────────────

    @staticmethod
    def _build_prompt(
        detected_objects: list[dict] | None,
        detected_text: str | None,
    ) -> str:
        """
        Build the Gemini prompt.

        When no structured context is available, returns the base prompt.
        When objects/text are provided, returns the enriched template with a
        structured context block injected.
        """
        has_objects = detected_objects and len(detected_objects) > 0
        has_text = detected_text and detected_text.strip()

        if not has_objects and not has_text:
            return _SCENE_PROMPT_BASE

        context_lines: list[str] = []

        if has_objects:
            object_lines: list[str] = []
            for det in detected_objects[:6]:   # Limit to 6 most relevant
                priority = det.get("priority", 3)
                label = det.get("label", "unknown")
                position = det.get("position", "ahead")
                conf = det.get("confidence", 0.0)
                tier = (
                    "critical safety risk"
                    if priority == 1
                    else "navigation hazard"
                    if priority == 2
                    else "environmental object"
                )
                object_lines.append(
                    f"  - {label} {position} ({tier}, confidence {conf:.0%})"
                )
            context_lines.append("Pre-detected objects:\n" + "\n".join(object_lines))

        if has_text:
            # Truncate very long OCR results to keep the prompt manageable.
            text_snippet = detected_text.strip()[:300]
            context_lines.append(f'Pre-detected text: "{text_snippet}"')

        context_block = "\n\n".join(context_lines)
        return _SCENE_PROMPT_ENRICHED.format(context_block=context_block)


# ── Module-level singleton ─────────────────────────────────────────────────────
scene_service = SceneService()
