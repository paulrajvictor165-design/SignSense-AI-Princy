"""
SignSense AI — Sign Language Recognition Service

Architecture
────────────
  sign_routes.py
      ↓
  SignLanguageService.recognize()      → full sign classification
  SignLanguageService.get_landmarks()  → raw MediaPipe landmarks only
      ↓
  _get_hand_detector()   (MediaPipe Hands — lazy-loaded singleton)
      ↓
  _classify_landmarks()  (rule-based ISL classifier)
      ↓
  response dict

Design decisions
────────────────
1. MediaPipe Hands provides 21 3D landmarks per hand.
   We normalize them relative to the wrist (landmark 0) and compute
   finger-state vectors (extended / folded) as features.

2. Classification is rule-based for ISL digits 0–9 and common alphabet
   letters that can be represented as static hand poses.

3. voice_message is always crafted here so the Flutter screen can speak it
   without any business logic in the UI layer.

4. low_confidence is True when the MediaPipe detection confidence is below
   SIGN_CONFIDENCE_THRESHOLD (default 0.70) to prompt the user to re-frame.

5. The service is deliberately stateless — one instance shared across all
   requests. MediaPipe Hands in static_image_mode=True is thread-safe.

6. get_landmarks() returns raw landmark data only — no classification.
   Useful for Flutter overlay visualization and future ML integration.

Note on sign-language classification models
────────────────────────────────────────────
MediaPipe alone is NOT a full sign-language translator.
A trained classification model is required for full ISL translation.

Expected TFLite model location:
    signsense_ai/ml_models/tflite/sign_language_model.tflite
    signsense_ai/ml_models/tflite/labels.txt

Input shape: (1, 63) — 21 landmarks × 3 coordinates (x, y, z), normalized.
Labels file: one label per line, index matches model output index.

Until a trained model is installed, this service uses the rule-based
classifier for basic poses only and returns "UNKNOWN" for others.
"""

import logging
import os
import time
from typing import Optional

import numpy as np

logger = logging.getLogger(__name__)

# Confidence threshold below which we flag low_confidence
_CONFIDENCE_THRESHOLD = 0.70

# Absolute path helpers for TFLite model
_THIS_DIR    = os.path.dirname(os.path.abspath(__file__))
_BACKEND_DIR = os.path.dirname(_THIS_DIR)
_PROJECT_DIR = os.path.dirname(_BACKEND_DIR)
_TFLITE_DIR  = os.path.join(_PROJECT_DIR, "ml_models", "tflite")
_TFLITE_MODEL_PATH  = os.path.join(_TFLITE_DIR, "sign_language_model.tflite")
_TFLITE_LABELS_PATH = os.path.join(_TFLITE_DIR, "labels.txt")


class SignLanguageService:
    """Recognize ISL hand signs from a JPEG image."""

    # ─── ISL static sign mapping ──────────────────────────────────────────────
    # Each entry maps a tuple of finger-states (thumb, index, middle, ring, pinky)
    # where True = extended, False = folded.
    # This covers ISL digits 0–9 and the most common alphabet signs.

    _SIGN_MAP: dict[tuple, str] = {
        # Digits
        (False, False, False, False, False): "0",
        (False, True,  False, False, False): "1",
        (False, True,  True,  False, False): "2",
        (False, True,  True,  True,  False): "3",
        (False, True,  True,  True,  True ): "4",
        (True,  True,  True,  True,  True ): "5",
        (True,  False, False, False, True ): "6",
        (True,  True,  False, False, False): "7",
        (True,  True,  True,  False, False): "8",
        (True,  True,  True,  True,  False): "9",
        # Common alphabet signs (static poses only)
        (True,  False, False, False, False): "A",
        (False, True,  True,  True,  True ): "B",
        (True,  False, False, False, True ): "Y",
    }

    _SIGN_DESCRIPTIONS: dict[str, str] = {
        "0": "Digit zero",
        "1": "Digit one",
        "2": "Digit two",
        "3": "Digit three",
        "4": "Digit four",
        "5": "Digit five",
        "6": "Digit six",
        "7": "Digit seven",
        "8": "Digit eight",
        "9": "Digit nine",
        "A": "Letter A",
        "B": "Letter B",
        "Y": "Letter Y",
    }

    # ─── TFLite model loader ───────────────────────────────────────────────────
    _tflite_interpreter = None
    _tflite_labels: list[str] = []
    _tflite_loaded: bool = False
    _tflite_checked: bool = False

    @classmethod
    def _try_load_tflite(cls) -> bool:
        """
        Attempt to load the TFLite sign-language model once.
        Returns True if loaded successfully, False otherwise.

        Expected input shape:  (1, 63)  — 21 landmarks × x,y,z normalized
        Expected output shape: (1, N)   — N = number of sign classes
        """
        if cls._tflite_checked:
            return cls._tflite_loaded
        cls._tflite_checked = True

        if not os.path.isfile(_TFLITE_MODEL_PATH):
            logger.info(
                "SignLanguageService: TFLite model not found at %s — "
                "using rule-based classifier only.", _TFLITE_MODEL_PATH
            )
            return False

        try:
            import tflite_runtime.interpreter as tflite
        except ImportError:
            try:
                import tensorflow.lite as tflite
            except ImportError:
                logger.warning(
                    "SignLanguageService: Neither tflite_runtime nor tensorflow is installed. "
                    "TFLite inference unavailable."
                )
                return False

        try:
            interp = tflite.Interpreter(model_path=_TFLITE_MODEL_PATH)
            interp.allocate_tensors()
            input_details  = interp.get_input_details()
            output_details = interp.get_output_details()
            input_shape = input_details[0]['shape']   # expected (1, 63)
            logger.info(
                "TFLite model loaded. Input shape: %s  Output shape: %s",
                input_shape, output_details[0]['shape']
            )
            cls._tflite_interpreter = interp

            # Load labels if available.
            if os.path.isfile(_TFLITE_LABELS_PATH):
                with open(_TFLITE_LABELS_PATH, "r", encoding="utf-8") as f:
                    cls._tflite_labels = [ln.strip() for ln in f if ln.strip()]
                logger.info("TFLite labels loaded: %d classes", len(cls._tflite_labels))
            else:
                logger.warning("TFLite labels.txt not found at %s", _TFLITE_LABELS_PATH)

            cls._tflite_loaded = True
            return True

        except Exception as e:
            logger.error("Failed to load TFLite model: %s", e)
            return False

    # ─── Public API ───────────────────────────────────────────────────────────

    def recognize(self, image_bytes: bytes) -> dict:
        """
        Analyze hand landmarks in image_bytes and return a result dict.

        Returns
        -------
        {
          sign_label:        str,    # e.g. "A", "5", "UNKNOWN", "NO_HAND"
          confidence:        float,
          description:       str,
          voice_message:     str,
          low_confidence:    bool,
          processing_time_ms: float,
          source_module:     "mediapipe_sign" | "tflite_sign",
          model_status:      str,   # human-readable model availability
        }
        """
        t_start = time.perf_counter()

        try:
            result = self._run_inference(image_bytes)
        except Exception as exc:
            logger.error("Sign recognition inference error: %s", exc, exc_info=True)
            result = self._no_hand_result()

        result["processing_time_ms"] = round(
            (time.perf_counter() - t_start) * 1000, 2
        )
        return result

    def get_landmarks(self, image_bytes: bytes) -> dict:
        """
        Extract raw MediaPipe hand landmarks without sign classification.

        Returns
        -------
        {
          hands_detected:    bool,
          num_hands:         int,
          hands:             list of {
            handedness:      str,     # "Left" or "Right"
            confidence:      float,
            landmarks:       list of {x, y, z},  # 21 normalized coords
          },
          processing_time_ms: float,
          source_module:     "mediapipe_hands",
        }
        """
        t_start = time.perf_counter()
        try:
            result = self._extract_landmarks(image_bytes)
        except Exception as exc:
            logger.error("Landmark extraction error: %s", exc, exc_info=True)
            result = {
                "hands_detected": False,
                "num_hands": 0,
                "hands": [],
                "voice_message": "Hand landmark extraction failed.",
            }

        result["processing_time_ms"] = round(
            (time.perf_counter() - t_start) * 1000, 2
        )
        result["source_module"] = "mediapipe_hands"
        return result

    # ─── Private helpers ──────────────────────────────────────────────────────

    def _run_inference(self, image_bytes: bytes) -> dict:
        import cv2

        # Decode image
        nparr = np.frombuffer(image_bytes, np.uint8)
        bgr = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if bgr is None:
            return self._error_result("Could not decode image.")

        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)

        hands = _get_hand_detector()
        detection_result = hands.process(rgb)

        if not detection_result.multi_hand_landmarks:
            return self._no_hand_result()

        # Use the first detected hand
        hand_landmarks = detection_result.multi_hand_landmarks[0]
        handedness_label = "Unknown"
        confidence = 0.5
        if detection_result.multi_handedness:
            clf = detection_result.multi_handedness[0].classification[0]
            confidence = clf.score
            handedness_label = clf.label

        low_conf = confidence < _CONFIDENCE_THRESHOLD

        # Try TFLite inference first (if model available)
        tflite_available = self._try_load_tflite()
        if tflite_available and self._tflite_interpreter is not None:
            return self._run_tflite_inference(
                hand_landmarks, confidence, handedness_label, low_conf
            )

        # Fallback to rule-based classifier
        finger_states = self._finger_states(hand_landmarks)
        sign_label = self._SIGN_MAP.get(finger_states, "UNKNOWN")
        description = self._SIGN_DESCRIPTIONS.get(
            sign_label, f"Unrecognized sign (pose: {finger_states})"
        )
        voice_msg = self._build_voice_message(sign_label, description, low_conf)

        # Model status message
        model_status = (
            "Using rule-based classifier. "
            "Install sign_language_model.tflite for full ISL translation."
        )

        return {
            "sign_label":    sign_label,
            "confidence":    round(float(confidence), 3),
            "description":   description,
            "voice_message": voice_msg,
            "low_confidence": low_conf,
            "handedness":    handedness_label,
            "source_module": "mediapipe_sign",
            "model_status":  model_status,
        }

    def _run_tflite_inference(
        self,
        hand_landmarks,
        confidence: float,
        handedness_label: str,
        low_conf: bool,
    ) -> dict:
        """Run TFLite model inference on landmark features."""
        try:
            # Build feature vector: 21 landmarks × 3 (x, y, z) = 63 values
            lm = hand_landmarks.landmark
            features = []
            # Normalize relative to wrist (landmark 0)
            wrist_x, wrist_y, wrist_z = lm[0].x, lm[0].y, lm[0].z
            for point in lm:
                features.extend([
                    point.x - wrist_x,
                    point.y - wrist_y,
                    point.z - wrist_z,
                ])

            input_data = np.array([features], dtype=np.float32)
            interp = self._tflite_interpreter
            input_details  = interp.get_input_details()
            output_details = interp.get_output_details()

            interp.set_tensor(input_details[0]['index'], input_data)
            interp.invoke()
            output_data = interp.get_tensor(output_details[0]['index'])[0]

            pred_idx = int(np.argmax(output_data))
            pred_conf = float(output_data[pred_idx])

            if self._tflite_labels and pred_idx < len(self._tflite_labels):
                sign_label = self._tflite_labels[pred_idx]
            else:
                sign_label = str(pred_idx)

            if pred_conf < 0.5:
                sign_label = "UNKNOWN"

            description = self._SIGN_DESCRIPTIONS.get(
                sign_label, f"Sign: {sign_label}"
            )
            voice_msg = self._build_voice_message(sign_label, description, low_conf)

            return {
                "sign_label":    sign_label,
                "confidence":    round(pred_conf, 3),
                "description":   description,
                "voice_message": voice_msg,
                "low_confidence": low_conf or (pred_conf < 0.5),
                "handedness":    handedness_label,
                "source_module": "tflite_sign",
                "model_status":  "TFLite model active.",
            }

        except Exception as exc:
            logger.error("TFLite inference failed, falling back: %s", exc)
            # Fallback to rule-based
            finger_states = self._finger_states(hand_landmarks)
            sign_label = self._SIGN_MAP.get(finger_states, "UNKNOWN")
            description = self._SIGN_DESCRIPTIONS.get(sign_label, "Unrecognized sign")
            voice_msg = self._build_voice_message(sign_label, description, low_conf)
            return {
                "sign_label":    sign_label,
                "confidence":    round(float(confidence), 3),
                "description":   description,
                "voice_message": voice_msg,
                "low_confidence": low_conf,
                "handedness":    handedness_label,
                "source_module": "mediapipe_sign",
                "model_status":  "TFLite inference failed, using rule-based classifier.",
            }

    def _extract_landmarks(self, image_bytes: bytes) -> dict:
        """Extract raw landmark data without classification."""
        import cv2

        nparr = np.frombuffer(image_bytes, np.uint8)
        bgr = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if bgr is None:
            return {
                "hands_detected": False,
                "num_hands": 0,
                "hands": [],
                "voice_message": "Could not decode image.",
            }

        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
        hands_detector = _get_hand_detector()
        detection_result = hands_detector.process(rgb)

        if not detection_result.multi_hand_landmarks:
            return {
                "hands_detected": False,
                "num_hands": 0,
                "hands": [],
                "voice_message": "No hand detected. Please show your hand clearly.",
            }

        hands_data = []
        for i, hand_lm in enumerate(detection_result.multi_hand_landmarks):
            handedness = "Unknown"
            conf = 0.5
            if detection_result.multi_handedness and i < len(detection_result.multi_handedness):
                clf = detection_result.multi_handedness[i].classification[0]
                handedness = clf.label
                conf = clf.score

            landmarks = [
                {"x": round(lm.x, 4), "y": round(lm.y, 4), "z": round(lm.z, 4)}
                for lm in hand_lm.landmark
            ]
            hands_data.append({
                "handedness": handedness,
                "confidence": round(float(conf), 3),
                "landmarks": landmarks,
            })

        num_hands = len(hands_data)
        voice = f"{num_hands} hand{'s' if num_hands > 1 else ''} detected."

        return {
            "hands_detected": True,
            "num_hands": num_hands,
            "hands": hands_data,
            "voice_message": voice,
        }

    # MediaPipe Hands landmark indices
    # Wrist=0, Thumb: 1-4, Index: 5-8, Middle: 9-12, Ring: 13-16, Pinky: 17-20
    # A finger is "extended" when its tip (lm[tip_idx]) is above its MCP joint
    # (lm[mcp_idx]) in image coordinates (y decreases upward in normalized space).

    _FINGER_TIP_MCP = [
        (4, 2),   # thumb  tip vs IP joint (heuristic)
        (8, 5),   # index
        (12, 9),  # middle
        (16, 13), # ring
        (20, 17), # pinky
    ]

    def _finger_states(self, hand_landmarks) -> tuple:
        lm = hand_landmarks.landmark
        states = []
        for tip_idx, mcp_idx in self._FINGER_TIP_MCP:
            extended = lm[tip_idx].y < lm[mcp_idx].y
            states.append(extended)
        return tuple(states)

    @staticmethod
    def _build_voice_message(
        sign_label: str, description: str, low_conf: bool
    ) -> str:
        if sign_label == "NO_HAND":
            return "No hand detected. Please show your hand clearly."
        if sign_label == "UNKNOWN":
            msg = "Sign not recognized. Try again."
        else:
            msg = f"Sign detected: {description}."
        if low_conf:
            msg += " Low confidence. Improve lighting or move closer."
        return msg

    @staticmethod
    def _no_hand_result() -> dict:
        return {
            "sign_label":    "NO_HAND",
            "confidence":    0.0,
            "description":   "No hand detected in the image.",
            "voice_message": "No hand detected. Please show your hand clearly.",
            "low_confidence": True,
            "handedness":    "Unknown",
            "source_module": "mediapipe_sign",
            "model_status":  "MediaPipe active. No trained TFLite model installed.",
        }

    @staticmethod
    def _error_result(detail: str) -> dict:
        return {
            "sign_label":    "ERROR",
            "confidence":    0.0,
            "description":   detail,
            "voice_message": "Sign recognition failed. Please try again.",
            "low_confidence": True,
            "handedness":    "Unknown",
            "source_module": "mediapipe_sign",
            "model_status":  "Error during processing.",
        }


# ── Module-level lazy loader (mirrors pattern in ai_modules/__init__.py) ──────

_hand_detector = None
_hand_lock = None


def _get_hand_detector():
    """
    Lazy-load MediaPipe Hands in static_image_mode.
    Thread-safe: uses a module-level lock.
    Raises ImportError with a clear message if mediapipe is not installed.
    """
    global _hand_detector, _hand_lock
    import threading

    if _hand_lock is None:
        _hand_lock = threading.Lock()

    with _hand_lock:
        if _hand_detector is None:
            try:
                import mediapipe as mp
                logger.info("Loading MediaPipe Hands model (max_num_hands=2)...")
                _hand_detector = mp.solutions.hands.Hands(
                    static_image_mode=True,
                    max_num_hands=2,
                    min_detection_confidence=0.5,
                    min_tracking_confidence=0.5,
                )
                logger.info("MediaPipe Hands loaded successfully.")
            except ImportError as e:
                logger.error(
                    "MediaPipe is not installed: %s\n"
                    "Install it with: pip install mediapipe", e
                )
                raise
    return _hand_detector


# ── Module-level singleton ─────────────────────────────────────────────────────
sign_language_service = SignLanguageService()
