"""
SignSense AI — AI Metrics Utility
===================================
Lightweight processing-time and confidence measurement helpers.

Module 3 addition — AI Pipeline improvement.

Design
------
Every AI service method is expected to:
  1. Call ``start_timer()`` before inference begins.
  2. Call ``elapsed_ms(start)`` after inference completes.
  3. Include ``processing_time_ms`` and ``pipeline_confidence`` in its
     response dict.

This module provides only the measurement helpers — it does NOT perform
any I/O, logging side-effects, or database writes.  Services call
``log_result()`` to emit a single INFO-level log line with all metrics;
the log line is machine-parseable so it can be ingested by log aggregators.

Response envelope additions (Module 3)
---------------------------------------
Every service response now includes:

    processing_time_ms  int     — wall-clock ms from validation to response
    pipeline_confidence float   — aggregate confidence: max over detections,
                                  or the model's own confidence for single-
                                  result services (OCR, currency, scene)
    low_confidence      bool    — True when pipeline_confidence is below the
                                  configured threshold for the service
    source_module       str     — which AI module produced the result
                                  ("yolo", "easyocr", "gemini", "mediapipe")

All new keys are *additive* — existing keys are unchanged.
Flutter receives extra fields it ignores until it is updated to use them.

Usage
-----
    import time
    from utils.ai_metrics import start_timer, elapsed_ms, build_metrics, log_result

    t0 = start_timer()
    # ... inference ...
    ms = elapsed_ms(t0)
    metrics = build_metrics(
        source_module="yolo",
        processing_time_ms=ms,
        pipeline_confidence=0.87,
        low_confidence=False,
    )
    log_result("detection", metrics)
    return {**result, **metrics}
"""

from __future__ import annotations

import logging
import time

logger = logging.getLogger(__name__)

# Module-level confidence threshold used by build_metrics() when callers
# do not supply their own.  Services that care about custom thresholds
# should import from utils.object_priority instead.
_DEFAULT_LOW_CONF_THRESHOLD: float = 0.45


def start_timer() -> float:
    """Return a high-resolution timestamp (seconds since epoch)."""
    return time.perf_counter()


def elapsed_ms(start: float) -> int:
    """Return integer milliseconds elapsed since *start* (from start_timer)."""
    return int((time.perf_counter() - start) * 1000)


def build_metrics(
    *,
    source_module: str,
    processing_time_ms: int,
    pipeline_confidence: float,
    low_confidence: bool | None = None,
    low_conf_threshold: float = _DEFAULT_LOW_CONF_THRESHOLD,
) -> dict:
    """Return the standard AI metrics dict to be merged into a service response.

    Parameters
    ----------
    source_module:
        Human-readable name of the AI module that produced the result.
        E.g. ``"yolo"``, ``"easyocr"``, ``"gemini"``, ``"mediapipe"``.
    processing_time_ms:
        Wall-clock time in milliseconds from input receipt to result dict.
    pipeline_confidence:
        Aggregate confidence for the result (0.0 – 1.0).
        For multi-detection responses: highest priority detection's confidence.
        For single-result responses (OCR, currency): the model's own score.
    low_confidence:
        Explicit override.  When ``None`` (default), computed automatically
        from *pipeline_confidence* vs *low_conf_threshold*.
    low_conf_threshold:
        Confidence floor below which the result is flagged as uncertain.
    """
    if low_confidence is None:
        low_confidence = pipeline_confidence < low_conf_threshold

    return {
        "processing_time_ms":   processing_time_ms,
        "pipeline_confidence":  round(pipeline_confidence, 3),
        "low_confidence":       low_confidence,
        "source_module":        source_module,
    }


def log_result(service_name: str, metrics: dict) -> None:
    """Emit a single INFO log line with all metrics for this request.

    Log format is intentionally machine-parseable:
        [AI] service=<name> module=<src> conf=<val> time_ms=<val> low_conf=<bool>
    """
    logger.info(
        "[AI] service=%s module=%s conf=%.3f time_ms=%d low_conf=%s",
        service_name,
        metrics.get("source_module", "unknown"),
        metrics.get("pipeline_confidence", 0.0),
        metrics.get("processing_time_ms", 0),
        metrics.get("low_confidence", False),
    )
