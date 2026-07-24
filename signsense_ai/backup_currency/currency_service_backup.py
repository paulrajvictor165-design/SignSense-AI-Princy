"""
SignSense AI — Currency Detection Service
==========================================
Business logic for Indian Rupee denomination detection.

Module 3 changes (AI Pipeline)
--------------------------------
1. AI metrics envelope
   Every response now includes processing_time_ms, pipeline_confidence,
   low_confidence, source_module.

2. Low-confidence voice path
   When confidence < LOW_CONF_THRESHOLD (0.55 for currency — higher than other
   services because denomination errors are high-stakes), the voice message
   explicitly tells the user the result is uncertain and asks them to retry.
   Previously the service silently returned a low-confidence denomination.

3. Source module tracking
   source_module is "yolo_currency" when the custom model fires, "gemini"
   when Gemini is used as fallback.

Pipeline (unchanged)
---------------------
1. Try custom YOLO currency model (if configured and weights exist).
2. Fall back to Gemini Vision API.
3. Return structured denomination result.

API contract preserved
-----------------------
All existing response keys (denomination, currency, confidence, voice_message)
are unchanged.  New keys are additive.
"""

from __future__ import annotations

import base64
import logging
import os

import google.generativeai as genai

from config.settings import settings
from utils.image_utils import decode_image_safe
from utils.ai_metrics import start_timer, elapsed_ms, build_metrics, log_result

logger = logging.getLogger(__name__)

# ── Denomination data ──────────────────────────────────────────────────────────
# Moved from currency_routes.py — single source of truth.

DENOMINATIONS: list[int] = [10, 20, 50, 100, 200, 500, 2000]

DENOMINATION_VOICE: dict[int, str] = {
    10:   "This is a Ten Rupee note.",
    20:   "This is a Twenty Rupee note.",
    50:   "This is a Fifty Rupee note.",
    100:  "This is a One Hundred Rupee note.",
    200:  "This is a Two Hundred Rupee note.",
    500:  "This is a Five Hundred Rupee note.",
    2000: "This is a Two Thousand Rupee note.",
}


# Currency-specific confidence threshold — higher than the default because
# denomination errors have direct financial consequence.
_CURRENCY_LOW_CONF_THRESHOLD: float = 0.55


class CurrencyService:
    """
    Service for Indian Rupee denomination detection.

    Primary strategy:  Custom YOLOv8 currency model (when weights are present).
    Fallback strategy: Gemini Vision API (when GEMINI_API_KEY is configured).

    Module 3: Adds AI metrics envelope and explicit low-confidence voice path.
    """

    def __init__(self) -> None:
        self._gemini_model = None
        self._gemini_available = False
        if settings.GEMINI_API_KEY:
            try:
                genai.configure(api_key=settings.GEMINI_API_KEY)
                self._gemini_model = genai.GenerativeModel("gemini-3.6-flash")
                self._gemini_available = True
                logger.info("CurrencyService: Gemini Vision API configured.")
            except Exception as e:
                logger.warning("CurrencyService: Gemini init failed: %s", e)
        else:
            logger.warning(
                "CurrencyService: GEMINI_API_KEY not set — Gemini fallback disabled."
            )

        # Resolve currency model path from ml_models directory.
        from ai_modules import _ML_MODELS_DIR
        self._currency_model_path: str = settings.CURRENCY_MODEL_PATH
        if not self._currency_model_path:
            # Check the canonical location.
            candidate = os.path.join(_ML_MODELS_DIR, "currency", "currency_model.pt")
            if os.path.isfile(candidate):
                self._currency_model_path = candidate

        logger.info(
            "CurrencyService initialised. "
            "Custom YOLO model: %s | Gemini available: %s",
            self._currency_model_path or "not configured",
            self._gemini_available,
        )

    def detect(self, image_bytes: bytes) -> dict:
        """
        Detect the Indian Rupee denomination in *image_bytes*.

        Returns
        -------
        dict with keys:
            denomination, currency, confidence, voice_message  ← unchanged
            processing_time_ms, pipeline_confidence,
            low_confidence, source_module                       ← new (Module 3)
        """
        t0 = start_timer()
        source_module = "gemini"

        # Primary: custom YOLO model
        result: dict | None = None
        if self._currency_model_path and os.path.exists(self._currency_model_path):
            result = self._detect_with_yolo(image_bytes)
            if result:
                source_module = "yolo_currency"

        # Fallback: Gemini Vision
        if result is None:
            if not self._gemini_available:
                return {
                    "denomination": "",
                    "currency": "Unavailable",
                    "confidence": 0.0,
                    "voice_message": (
                        "Currency detection is not available. "
                        "No trained model is installed and the Gemini API key is not configured."
                    ),
                    "processing_time_ms": elapsed_ms(t0),
                    "pipeline_confidence": 0.0,
                    "low_confidence": True,
                    "source_module": "none",
                }
            result = self._detect_with_gemini(image_bytes)

        # ── Attach metrics ────────────────────────────────────────────────
        conf = result.get("confidence", 0.0)
        metrics = build_metrics(
            source_module=source_module,
            processing_time_ms=elapsed_ms(t0),
            pipeline_confidence=conf,
            low_conf_threshold=_CURRENCY_LOW_CONF_THRESHOLD,
        )
        log_result("detect_currency", metrics)

        # ── Low-confidence voice override ─────────────────────────────────
        # When confidence is too low, override voice_message to prompt retry.
        # This only applies when a denomination was actually detected (not
        # already an "Unknown" or "Error" result).
        if (
            metrics["low_confidence"]
            and result.get("denomination")
            and conf > 0.0
        ):
            result["voice_message"] = (
                f"Possible {result['currency']} detected but confidence is low. "
                "Please hold the note flat and directly under the camera, "
                "then try again."
            )

        return {**result, **metrics}

    # ── Private pipeline methods ───────────────────────────────────────────

    def _detect_with_yolo(self, image_bytes: bytes) -> dict | None:
        """
        Run the custom YOLO currency model.

        Returns a result dict on success, or None when the model produces
        no confident detection (so the caller can fall through to Gemini).
        """
        try:
            from ultralytics import YOLO
            model = YOLO(self._currency_model_path)
            img = decode_image_safe(image_bytes)
            if img is None:
                return None

            results = model.predict(img, imgsz=640, conf=0.5, verbose=False)
            for result in results:
                for box in result.boxes:
                    label = model.names[int(box.cls)]
                    denomination = self._parse_denomination(label)
                    if denomination:
                        return self._build_result(denomination, float(box.conf))

        except Exception as exc:
            logger.warning("YOLO currency detection failed: %s", exc)

        return None

    def _detect_with_gemini(self, image_bytes: bytes) -> dict:
        """
        Use Gemini Vision to identify the denomination.

        Always returns a result dict (never raises) so the route always gets
        a response even when Gemini fails — degraded gracefully.
        """
        prompt = (
            "This is an image of an Indian Rupee note. "
            "Identify the denomination (10, 20, 50, 100, 200, 500, or 2000). "
            "Respond with ONLY the number. No other text. "
            "If you cannot identify it, respond with 'unknown'."
        )

        image_part = {
            "mime_type": "image/jpeg",
            "data": base64.b64encode(image_bytes).decode("utf-8"),
        }

        try:
            response = self._gemini_model.generate_content([prompt, image_part])
            raw = response.text.strip().lower()
            denomination = self._parse_denomination(raw)
            if denomination:
                return self._build_result(denomination, confidence=0.85)

            return {
                "denomination": "",
                "currency": "Unknown",
                "confidence": 0.0,
                "voice_message": (
                    "Could not identify the currency denomination. "
                    "Please hold the note flat and try again."
                ),
            }

        except Exception as exc:
            logger.error("Gemini currency detection error: %s", exc)
            return {
                "denomination": "",
                "currency": "Error",
                "confidence": 0.0,
                "voice_message": (
                    "Currency detection failed. "
                    "Please check your internet connection and try again."
                ),
            }

    # ── Helpers ───────────────────────────────────────────────────────────

    @staticmethod
    def _parse_denomination(text: str) -> int | None:
        """Extract an Indian Rupee denomination integer from arbitrary text."""
        for d in DENOMINATIONS:
            if str(d) in text:
                return d
        return None

    @staticmethod
    def _build_result(denomination: int, confidence: float) -> dict:
        return {
            "denomination": denomination,
            "currency":     f"₹{denomination}",
            "confidence":   round(confidence, 2),
            "voice_message": DENOMINATION_VOICE.get(
                denomination,
                f"This is a {denomination} Rupee note.",
            ),
        }


# ── Module-level singleton ─────────────────────────────────────────────────────
currency_service = CurrencyService()
