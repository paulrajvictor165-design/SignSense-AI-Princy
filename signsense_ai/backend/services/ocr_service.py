"""
SignSense AI — OCR Service
===========================
Business logic for optical character recognition.

Module 3 changes (AI Pipeline)
--------------------------------
1. Image pre-processing stage
   Before EasyOCR inference, the image is enhanced:
   - CLAHE (Contrast Limited Adaptive Histogram Equalisation) for uneven lighting
   - Sharpening kernel to improve text edge definition
   - Adaptive resize: upscale small images to minimum side 800 px for better OCR
   Both steps operate on a working copy — the original image is not mutated.

2. Low-confidence handling
   When the aggregate text confidence is below _LOW_CONF_THRESHOLD, the
   response includes low_confidence=True and a voice message that asks the
   user to move closer or improve lighting rather than silently returning poor
   results.

3. AI metrics envelope
   Every response now includes processing_time_ms, pipeline_confidence,
   low_confidence, source_module.

4. Auto-retry with enhanced pre-processing
   If the initial pass returns 0 blocks (no text found), the service
   re-runs OCR on an aggressively sharpened version of the image before
   giving up. This handles cases where a single enhancement pass is
   insufficient for very low contrast text.

API backward compatibility
--------------------------
All existing response keys (text, blocks, count, voice_message) are unchanged.
New keys are additive.
"""

from __future__ import annotations

import logging
import cv2
import numpy as np

from ai_modules import get_easyocr_reader
from utils.image_utils import decode_image_safe
from utils.ai_metrics import start_timer, elapsed_ms, build_metrics, log_result
from database.db import save_ocr_result

logger = logging.getLogger(__name__)

# Minimum EasyOCR confidence to include a text block in the result.
_MIN_CONFIDENCE: float = 0.30

# Pipeline-level aggregate confidence below which the response is flagged
# as low-confidence and the user is prompted to retry.
_LOW_CONF_THRESHOLD: float = 0.50

# Minimum pixel count for the shorter image side.
# Images smaller than this are upscaled before OCR to improve accuracy.
_MIN_OCR_SIDE: int = 800


class OcrService:
    """
    Stateless service for OCR text extraction operations.

    Module 3: Adds image pre-processing (CLAHE + sharpening + resize),
    low-confidence retry, and AI metrics envelope.
    """

    def extract_text(self, image_bytes: bytes) -> dict:
        """
        Extract text from *image_bytes* using EasyOCR.

        Pipeline (Module 3):
          1. Decode image.
          2. Pre-process: CLAHE + sharpening + minimum-size upscale.
          3. Run EasyOCR inference.
          4. If zero blocks found: retry with aggressive sharpening.
          5. Filter by confidence, join text, evaluate pipeline confidence.
          6. Return result with AI metrics envelope.

        Parameters
        ----------
        image_bytes:
            Raw JPEG/PNG bytes from a multipart form upload.

        Returns
        -------
        dict with keys:
            text, blocks, count, voice_message         ← unchanged
            processing_time_ms, pipeline_confidence,
            low_confidence, source_module               ← new (Module 3)
        """
        t0 = start_timer()
        img = decode_image_safe(image_bytes)
        if img is None:
            logger.warning("extract_text: could not decode image bytes.")
            metrics = build_metrics(
                source_module="easyocr",
                processing_time_ms=elapsed_ms(t0),
                pipeline_confidence=0.0,
                low_confidence=True,
            )
            return {
                "text":          "",
                "blocks":        [],
                "count":         0,
                "voice_message": "Could not read the image. Please try again.",
                **metrics,
            }

        try:
            reader = get_easyocr_reader()

            # ── Stage 2: Pre-processing ───────────────────────────────────
            enhanced = self._preprocess(img)

            # ── Stage 3: OCR inference ────────────────────────────────────
            raw_results = reader.readtext(enhanced)
            text_blocks = self._filter_blocks(raw_results)

            # ── Stage 4: Auto-retry on zero blocks ────────────────────────
            if not text_blocks:
                logger.debug("OCR: zero blocks on first pass — retrying with aggressive sharpening.")
                retry_img = self._preprocess(img, aggressive=True)
                raw_results = reader.readtext(retry_img)
                text_blocks = self._filter_blocks(raw_results)

            # ── Stage 5: Aggregate & voice ────────────────────────────────
            full_text = " ".join(b["text"] for b in text_blocks)
            avg_conf = (
                sum(b["confidence"] for b in text_blocks) / len(text_blocks)
                if text_blocks else 0.0
            )

            if full_text.strip():
                try:
                    save_ocr_result(full_text)
                except Exception as db_exc:
                    logger.warning(
                        "OCR text detected, but database save failed: %s",
                        db_exc,
                    )                
                if avg_conf >= _LOW_CONF_THRESHOLD:
                    voice_message = full_text
                else:
                    voice_message = (
                        f"{full_text} "
                        "— some text may be unclear. "
                        "Move closer or improve lighting for better results."
                    )
            else:
                voice_message = (
                    "No text found in the image. "
                    "Please move closer or ensure better lighting."
                )

            metrics = build_metrics(
                source_module="easyocr",
                processing_time_ms=elapsed_ms(t0),
                pipeline_confidence=round(avg_conf, 3),
                low_conf_threshold=_LOW_CONF_THRESHOLD,
            )
            log_result("extract_text", metrics)

            return {
                "text":          full_text,
                "blocks":        text_blocks,
                "count":         len(text_blocks),
                "voice_message": voice_message,
                **metrics,
            }

        except Exception as exc:
            logger.error("OCR processing error: %s", exc)
            raise RuntimeError(f"OCR processing failed: {exc}") from exc

    # ── Private helpers ────────────────────────────────────────────────────

    @staticmethod
    def _preprocess(img: np.ndarray, aggressive: bool = False) -> np.ndarray:
        """
        Enhance *img* for OCR accuracy.

        Steps:
        1. Convert to grayscale for processing, then merge back to BGR
           so EasyOCR (which expects BGR or grayscale) works correctly.
        2. CLAHE — equalises local contrast without over-brightening.
        3. Sharpening kernel — sharpens text edges.
        4. Minimum-side upscale — small images are enlarged to _MIN_OCR_SIDE.

        When *aggressive* is True the sharpening kernel strength is doubled,
        used on the auto-retry path.

        Returns a BGR image suitable for ``reader.readtext()``.
        """
        # Step 1: Convert to LAB colour space, apply CLAHE to the L channel only.
        lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
        l_ch, a_ch, b_ch = cv2.split(lab)
        clahe = cv2.createCLAHE(
            clipLimit=3.0 if not aggressive else 5.0,
            tileGridSize=(8, 8),
        )
        l_enhanced = clahe.apply(l_ch)
        enhanced = cv2.merge([l_enhanced, a_ch, b_ch])
        enhanced = cv2.cvtColor(enhanced, cv2.COLOR_LAB2BGR)

        # Step 2: Apply controlled unsharp masking.
        blur_sigma = 1.0 if not aggressive else 1.5
        sharpen_amount = 1.2 if not aggressive else 1.8

        blurred = cv2.GaussianBlur(
            enhanced,
            (0, 0),
            sigmaX=blur_sigma,
            sigmaY=blur_sigma,
        )

        enhanced = cv2.addWeighted(
            enhanced,
            1.0 + sharpen_amount,
            blurred,
            -sharpen_amount,
            0,
        )       
        # Step 3: Upscale if too small.
        h, w = enhanced.shape[:2]
        min_side = min(h, w)

        if min_side <= 0:
            raise ValueError("Invalid image dimensions for OCR preprocessing.")

        if min_side < _MIN_OCR_SIDE:
            scale = _MIN_OCR_SIDE / min_side
            new_w = int(w * scale)
            new_h = int(h * scale)

            enhanced = cv2.resize(
                enhanced,
                (new_w, new_h),
                interpolation=cv2.INTER_CUBIC,
            )        
        return enhanced

    @staticmethod
    def _filter_blocks(raw_results: list) -> list[dict]:
        """Filter and normalise raw EasyOCR results."""
        return [
            {
                "text":       text,
                "confidence": round(confidence, 2),
                "bbox":       bbox,
            }
            for bbox, text, confidence in raw_results
            if confidence >= _MIN_CONFIDENCE and text.strip()
        ]


# ── Module-level singleton ─────────────────────────────────────────────────────
ocr_service = OcrService()
