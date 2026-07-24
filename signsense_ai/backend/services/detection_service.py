"""
SignSense AI — Detection Service
==================================
Business logic for all computer-vision detection tasks.

Module 3 changes (AI Pipeline)
--------------------------------
1. Object priority ordering
   Previously detections were sorted by confidence only.
   Now sorted by *priority tier first*, confidence second.
   A vehicle at 70 % confidence is always announced before a chair at 92 %.

2. Per-detection priority field
   Each detection dict now includes a ``priority`` integer (1–4) so the
   Flutter client can apply its own visual differentiation (e.g. red border
   for critical objects).

3. AI metrics envelope
   Every response now includes four additive keys:
     processing_time_ms   — wall-clock inference time
     pipeline_confidence  — highest-priority detection's confidence
     low_confidence       — flag when pipeline_confidence < tier threshold
     source_module        — always "yolo" or "mediapipe" for these endpoints

4. Priority-aware voice message
   ``build_priority_voice_message()`` prepends "Warning!" / "Caution!" for
   critical/high-priority objects and skips sub-threshold detections.

5. Safety-first face & vehicle messages
   detect_vehicles() now prefixes "Warning!" for all vehicles (always
   PRIORITY_CRITICAL).  detect_faces() remains unchanged in priority (it is
   PRIORITY_HIGH by categorisation).

API backward compatibility
--------------------------
All previously existing response keys (detections, count, voice_message,
traffic_light_color, colors) are unchanged.  New keys are additive.
"""

from __future__ import annotations

import logging
import cv2
import numpy as np

from ai_modules import get_yolo_model, get_face_detector
from utils.image_utils import decode_image_safe, compute_position, resize_for_inference
from utils.color_detector import detect_dominant_colors
from utils.object_priority import (
    get_priority,
    sort_by_priority,
    build_priority_voice_message,
    should_announce,
    LOW_CONFIDENCE_THRESHOLD,
    PRIORITY_CRITICAL,
    PRIORITY_HIGH,
)
from utils.ai_metrics import start_timer, elapsed_ms, build_metrics, log_result
from database.db import save_detection

logger = logging.getLogger(__name__)


# ── Class constants ────────────────────────────────────────────────────────────

OBJECT_CLASSES: frozenset[str] = frozenset({
    "person", "chair", "dining table", "door", "potted plant",
    "bench", "bottle", "cell phone", "laptop", "backpack",
    "handbag", "suitcase", "umbrella", "bicycle", "motorcycle",
    "car", "bus", "truck", "dog", "cat", "bird",
    "couch", "bed", "toilet", "keyboard", "mouse",
})

TRAFFIC_CLASSES: frozenset[str] = frozenset({
    "traffic light", "stop sign",
})

VEHICLE_CLASSES: frozenset[str] = frozenset({
    "bicycle", "car", "motorcycle", "bus", "truck",
})

_TRAFFIC_VOICE: dict[str, str] = {
    "red":    "Red signal. Please wait.",
    "green":  "Green signal. Safe to cross.",
    "yellow": "Yellow signal. Proceed with caution.",
}


# ── Service class ──────────────────────────────────────────────────────────────

class DetectionService:
    """
    Stateless service for all computer-vision detection operations.

    Module 3: Every public method now returns priority-sorted detections with
    an AI metrics envelope.  All existing response keys are preserved.
    """

    # ── Public API ─────────────────────────────────────────────────────────

    def detect_objects(self, image_bytes: bytes) -> dict:
        """
        Detect everyday objects — sorted priority-first, confidence second.

        Returns dict with keys:
            detections, count, voice_message          ← unchanged
            processing_time_ms, pipeline_confidence,
            low_confidence, source_module              ← new (Module 3)
        """
        t0 = start_timer()
        detections = self._run_yolo(
            image_bytes,
            filter_classes=OBJECT_CLASSES,
        )

        # Highest-priority detection drives pipeline confidence.
        top_conf = detections[0]["confidence"] if detections else 0.0
        top_priority = detections[0]["priority"] if detections else 4

        metrics = build_metrics(
            source_module="yolo",
            processing_time_ms=elapsed_ms(t0),
            pipeline_confidence=top_conf,
            low_conf_threshold=_tier_threshold(top_priority),
        )

        if detections:
            try:
                save_detection(
                    label=detections[0]["label"],
                    det_type="object",
                    confidence=detections[0]["confidence"],
                    position=detections[0]["position"],
                )
            except Exception as db_exc:
                logger.warning(
                    "Detection completed, but database save failed: %s",
                    db_exc,
                )

        log_result("detect_objects", metrics)

        return {
            "detections": detections,
            "count": len(detections),
            "voice_message": build_priority_voice_message(detections),
            **metrics,
        }
    def detect_traffic(self, image_bytes: bytes) -> dict:
        """
        Detect traffic signals and analyse colour state.

        Traffic signals are PRIORITY_CRITICAL — always announced first.

        Returns dict with keys:
            detections, traffic_light_color, count, voice_message  ← unchanged
            processing_time_ms, pipeline_confidence,
            low_confidence, source_module                           ← new
        """
        t0 = start_timer()
        detections = self._run_yolo(image_bytes, filter_classes=TRAFFIC_CLASSES)
        img = decode_image_safe(image_bytes)

        if img is None:
            logger.warning(
                "detect_traffic: could not decode image bytes."
            )

        traffic_color = (
            self._analyze_traffic_color(img)
            if img is not None
            else None
        )
        top_conf = detections[0]["confidence"] if detections else 0.0
        metrics = build_metrics(
            source_module="yolo",
            processing_time_ms=elapsed_ms(t0),
            pipeline_confidence=top_conf,
            low_conf_threshold=0.30,  # CRITICAL tier threshold
        )
        log_result("detect_traffic", metrics)

        if traffic_color:
            voice = _TRAFFIC_VOICE.get(traffic_color, "Traffic signal detected.")
        elif detections:
            voice = build_priority_voice_message(detections)
        else:
            voice = "No traffic signals detected."

        return {
            "detections":         detections,
            "traffic_light_color": traffic_color,
            "count":              len(detections),
            "voice_message":      voice,
            **metrics,
        }

    def detect_vehicles(self, image_bytes: bytes) -> dict:
        """
        Detect approaching vehicles with priority-first directional warnings.

        All vehicles are PRIORITY_CRITICAL.  "Warning!" prefix is always applied.

        Returns dict with keys:
            detections, count, voice_message           ← unchanged
            processing_time_ms, pipeline_confidence,
            low_confidence, source_module               ← new
        """
        t0 = start_timer()
        detections = self._run_yolo(image_bytes, filter_classes=VEHICLE_CLASSES)

        # Vehicles are always CRITICAL — build a safety-first message.
        voice_parts: list[str] = []
        for d in detections[:3]:
            if should_announce(d):
                voice_parts.append(f"Warning! {d['label']} on your {d['position']}.")

        voice = " ".join(voice_parts) if voice_parts else "No vehicles detected."

        top_conf = detections[0]["confidence"] if detections else 0.0
        metrics = build_metrics(
            source_module="yolo",
            processing_time_ms=elapsed_ms(t0),
            pipeline_confidence=top_conf,
            low_conf_threshold=0.30,  # CRITICAL tier threshold
        )
        log_result("detect_vehicles", metrics)

        return {
            "detections":    detections,
            "count":         len(detections),
            "voice_message": voice,
            **metrics,
        }

    def detect_faces(self, image_bytes: bytes) -> dict:
        """
        Detect faces using MediaPipe, sorted by confidence descending.

        Returns dict with keys:
            detections, count, voice_message           ← unchanged
            processing_time_ms, pipeline_confidence,
            low_confidence, source_module               ← new
        """
        t0 = start_timer()
        img = decode_image_safe(image_bytes)
        if img is None:
            logger.warning("detect_faces: could not decode image bytes.")
            metrics = build_metrics(
                source_module="mediapipe",
                processing_time_ms=elapsed_ms(t0),
                pipeline_confidence=0.0,
                low_confidence=True,
            )
            return {
                "detections":    [],
                "count":         0,
                "voice_message": "No faces detected.",
                **metrics,
            }

        rgb = img[:, :, ::-1]   # BGR → RGB for MediaPipe
        detector = get_face_detector()
        results = detector.process(rgb)

        detections: list[dict] = []
        if results.detections:
            h, w = img.shape[:2]
            for i, detection in enumerate(results.detections):
                bbox = detection.location_data.relative_bounding_box
                cx = (bbox.xmin + bbox.width / 2) * w
                position = compute_position(cx, w)
                score = detection.score[0] if detection.score else 0.0
                priority = PRIORITY_HIGH  # faces are always HIGH priority
                detections.append({
                    "label":      f"Face {i + 1}",
                    "confidence": round(float(score), 2),
                    "position":   position,
                    "category":   "face",
                    "priority":   priority,
                    "bbox": {
                        "x1": bbox.xmin,
                        "y1": bbox.ymin,
                        "x2": bbox.xmin + bbox.width,
                        "y2": bbox.ymin + bbox.height,
                    },
                })

        # Sort by confidence within the same (HIGH) tier.
        detections.sort(key=lambda d: d["confidence"], reverse=True)

        n = len(detections)
        voice = (
            f"{n} {'face' if n == 1 else 'faces'} detected."
            if n else "No faces detected."
        )

        top_conf = detections[0]["confidence"] if detections else 0.0
        metrics = build_metrics(
            source_module="mediapipe",
            processing_time_ms=elapsed_ms(t0),
            pipeline_confidence=top_conf,
            low_conf_threshold=0.40,  # HIGH tier threshold
        )
        log_result("detect_faces", metrics)

        return {
            "detections":    detections,
            "count":         n,
            "voice_message": voice,
            **metrics,
        }

    def detect_colors(self, image_bytes: bytes) -> dict:
        """
        Detect dominant colours using HSV masking.

        Returns dict with keys:
            colors, voice_message                      ← unchanged
            processing_time_ms, pipeline_confidence,
            low_confidence, source_module               ← new
        """
        t0 = start_timer()
        img = decode_image_safe(image_bytes)
        if img is None:
            logger.warning("detect_colors: could not decode image bytes.")
            metrics = build_metrics(
                source_module="opencv_hsv",
                processing_time_ms=elapsed_ms(t0),
                pipeline_confidence=0.0,
                low_confidence=True,
            )
            return {
                "colors":        [{"name": "Unknown", "percentage": 0}],
                "voice_message": "Could not detect colors. Please try again.",
                **metrics,
            }

        colors = detect_dominant_colors(img)

        # Use the top color's percentage as a proxy for confidence.
        top_pct = colors[0]["percentage"] / 100.0 if colors else 0.0

        voice_parts = [f"Primary color is {colors[0]['name']}."]
        if len(colors) > 1:
            voice_parts.append(f"Also {colors[1]['name']}.")

        metrics = build_metrics(
            source_module="opencv_hsv",
            processing_time_ms=elapsed_ms(t0),
            pipeline_confidence=top_pct,
            low_conf_threshold=LOW_CONFIDENCE_THRESHOLD,
        )
        log_result("detect_colors", metrics)

        return {
            "colors":        colors,
            "voice_message": " ".join(voice_parts),
            **metrics,
        }

    # ── Private helpers ────────────────────────────────────────────────────

    def _run_yolo(
        self,
        image_bytes: bytes,
        filter_classes: frozenset[str] | None = None,
    ) -> list[dict]:
        """
        Run YOLOv8 inference on *image_bytes*.

        Module 3 changes vs Module 2:
        - Each detection dict now includes a ``priority`` integer.
        - Detections are sorted by priority-first, confidence-second
          (instead of confidence-only).
        """
        model = get_yolo_model()
        img = decode_image_safe(image_bytes)
        if img is None:
            logger.warning("_run_yolo: could not decode image bytes — skipping frame.")
            return []

        img = resize_for_inference(img, max_side=640)
        h, w = img.shape[:2]

        results = model.predict(
            img,
            imgsz=640,
            conf=0.35,
            verbose=False,
            device="cpu",
        )

        detections: list[dict] = []
        for result in results:
            for box in result.boxes:
                label = model.names[int(box.cls)]
                if filter_classes and label not in filter_classes:
                    continue

                conf = float(box.conf)
                x1, y1, x2, y2 = map(float, box.xyxy[0])

                bbox = {
                    "x1": x1 / w,
                    "y1": y1 / h,
                    "x2": x2 / w,
                    "y2": y2 / h,
                }

                cx = (x1 + x2) / 2
                position = compute_position(cx, w)
                priority = get_priority(label)

                detections.append({
                    "label":      label.capitalize(),
                    "confidence": round(conf, 2),
                    "position":   position,
                    "bbox":       bbox,
                    "category":   self._categorize(label),
                    "priority":   priority,  # ← new (Module 3)
                })

        # ── Priority-first sort (Module 3) ────────────────────────────────
        # Previously: sort by confidence only.
        # Now: sort by priority tier first, then by confidence descending.
        # This guarantees a vehicle at 70 % is always before a chair at 92 %.
        return sort_by_priority(detections)

    @staticmethod
    def _categorize(label: str) -> str:
        if label in VEHICLE_CLASSES:
            return "vehicle"
        if label in TRAFFIC_CLASSES:
            return "traffic"
        if label == "person":
            return "person"
        return "object"

    @staticmethod
    def _analyze_traffic_color(img: np.ndarray) -> str | None:
        """
        Analyse the dominant HSV colour in the upper image region to infer
        traffic light state.

        Returns 'red', 'yellow', 'green', or None when no signal is dominant.
        """
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
        h, _ = img.shape[:2]
        roi = hsv[:h // 3, :]   # Upper third — where traffic lights appear

        red1   = cv2.countNonZero(cv2.inRange(roi, np.array([0,   100, 100]), np.array([10,  255, 255])))
        red2   = cv2.countNonZero(cv2.inRange(roi, np.array([160, 100, 100]), np.array([180, 255, 255])))
        yellow = cv2.countNonZero(cv2.inRange(roi, np.array([15,  100, 100]), np.array([35,  255, 255])))
        green  = cv2.countNonZero(cv2.inRange(roi, np.array([40,  50,  50]),  np.array([90,  255, 255])))

        counts = {"red": red1 + red2, "yellow": yellow, "green": green}
        dominant = max(counts, key=counts.get)
        return dominant if counts[dominant] > 100 else None


# ── Private module helper ──────────────────────────────────────────────────────

def _tier_threshold(priority: int) -> float:
    """Return the confidence threshold for a given priority tier."""
    from utils.object_priority import _TIER_THRESHOLDS   # local import to avoid circular
    return _TIER_THRESHOLDS.get(priority, LOW_CONFIDENCE_THRESHOLD)


# ── Module-level singleton ─────────────────────────────────────────────────────
detection_service = DetectionService()
