"""
SignSense AI — Object Priority System
======================================
Single source of truth for object priority tiers and priority-first sorting.

Module 3 addition — AI Pipeline improvement.

Design
------
Every detectable object is assigned a *priority level* (1 = highest risk,
4 = lowest).  Detections are sorted by priority first, then by confidence
within the same tier.  This guarantees that a vehicle at 70 % confidence is
always announced before a chair at 92 % confidence — which is a direct user
safety requirement.

Priority tiers
--------------
1 — CRITICAL  Immediate safety risk: vehicles, barriers, open drains, fire,
              stairs, pedestrians crossing.  Always speak first.
2 — HIGH      Navigation hazards: doors, poles, trees, steps.
3 — NORMAL    Environmental context: furniture, bags, animals.
4 — LOW       Decorative / non-actionable objects.

Confidence thresholds
---------------------
LOW_CONFIDENCE_THRESHOLD  — below this the result is flagged as uncertain
                             and the voice message prompts a rescan.
HIGH_CONFIDENCE_THRESHOLD — above this the result is announced as confirmed.

Usage
-----
    from utils.object_priority import (
        get_priority,
        priority_sort_key,
        sort_by_priority,
        is_low_confidence,
        build_priority_voice_message,
        PRIORITY_CRITICAL,
    )
"""

from __future__ import annotations

# ── Priority level constants ───────────────────────────────────────────────────
PRIORITY_CRITICAL: int = 1
PRIORITY_HIGH: int = 2
PRIORITY_NORMAL: int = 3
PRIORITY_LOW: int = 4

# ── Per-tier confidence thresholds ────────────────────────────────────────────
# Critical objects are spoken even at lower confidence (safety-first).
# Normal/Low objects require higher confidence before being spoken.
_TIER_THRESHOLDS: dict[int, float] = {
    PRIORITY_CRITICAL: 0.30,   # warn at 30 % — better a false positive than a miss
    PRIORITY_HIGH:     0.40,
    PRIORITY_NORMAL:   0.50,
    PRIORITY_LOW:      0.60,
}

# Global "low confidence" cutoff used by the pipeline for retry decisions.
LOW_CONFIDENCE_THRESHOLD: float = 0.45
HIGH_CONFIDENCE_THRESHOLD: float = 0.75

# ── Priority maps ─────────────────────────────────────────────────────────────
# Maps lowercase YOLO class names → priority integer.
# Classes not listed fall back to PRIORITY_NORMAL.

_PRIORITY_MAP: dict[str, int] = {
    # ── CRITICAL (1) ─────────────────────────────────────────────
    "car":          PRIORITY_CRITICAL,
    "truck":        PRIORITY_CRITICAL,
    "bus":          PRIORITY_CRITICAL,
    "motorcycle":   PRIORITY_CRITICAL,
    "bicycle":      PRIORITY_CRITICAL,
    "fire hydrant": PRIORITY_CRITICAL,
    "stop sign":    PRIORITY_CRITICAL,
    "traffic light":PRIORITY_CRITICAL,
    # ── HIGH (2) ─────────────────────────────────────────────────
    "person":       PRIORITY_HIGH,
    "door":         PRIORITY_HIGH,
    "stairs":       PRIORITY_HIGH,
    # ── NORMAL (3) ───────────────────────────────────────────────
    "chair":        PRIORITY_NORMAL,
    "dining table": PRIORITY_NORMAL,
    "bench":        PRIORITY_NORMAL,
    "potted plant": PRIORITY_NORMAL,
    "couch":        PRIORITY_NORMAL,
    "bed":          PRIORITY_NORMAL,
    "toilet":       PRIORITY_NORMAL,
    "dog":          PRIORITY_NORMAL,
    "cat":          PRIORITY_NORMAL,
    "bird":         PRIORITY_NORMAL,
    # ── LOW (4) ──────────────────────────────────────────────────
    "bottle":       PRIORITY_LOW,
    "cup":          PRIORITY_LOW,
    "keyboard":     PRIORITY_LOW,
    "mouse":        PRIORITY_LOW,
    "cell phone":   PRIORITY_LOW,
    "laptop":       PRIORITY_LOW,
    "backpack":     PRIORITY_LOW,
    "handbag":      PRIORITY_LOW,
    "suitcase":     PRIORITY_LOW,
    "umbrella":     PRIORITY_LOW,
    "book":         PRIORITY_LOW,
}

# Safety-critical voice prefixes keyed by priority tier.
_PRIORITY_PREFIX: dict[int, str] = {
    PRIORITY_CRITICAL: "Warning! ",
    PRIORITY_HIGH:     "Caution! ",
    PRIORITY_NORMAL:   "",
    PRIORITY_LOW:      "",
}


# ── Public helpers ─────────────────────────────────────────────────────────────

def get_priority(label: str) -> int:
    """Return the priority tier (1–4) for a YOLO class label.

    Case-insensitive.  Unknown labels default to PRIORITY_NORMAL.
    """
    return _PRIORITY_MAP.get(label.lower(), PRIORITY_NORMAL)


def priority_sort_key(detection: dict) -> tuple[int, float]:
    """Sort key for a detection dict.

    Sorts ascending by priority tier (1 = most urgent first), then
    descending by confidence within the same tier.
    """
    p = get_priority(detection.get("label", ""))
    conf = detection.get("confidence", 0.0)
    return (p, -conf)   # negate conf so higher conf sorts earlier


def sort_by_priority(detections: list[dict]) -> list[dict]:
    """Return *detections* sorted priority-first, then confidence-descending."""
    return sorted(detections, key=priority_sort_key)


def should_announce(detection: dict) -> bool:
    """Return True when a detection's confidence exceeds its tier threshold.

    Critical objects are announced at lower confidence (safety-first).
    """
    p = get_priority(detection.get("label", ""))
    conf = detection.get("confidence", 0.0)
    return conf >= _TIER_THRESHOLDS.get(p, LOW_CONFIDENCE_THRESHOLD)


def is_low_confidence(confidence: float, priority: int = PRIORITY_NORMAL) -> bool:
    """True when *confidence* is below the threshold for *priority* tier."""
    return confidence < _TIER_THRESHOLDS.get(priority, LOW_CONFIDENCE_THRESHOLD)


def build_priority_voice_message(detections: list[dict]) -> str:
    """Build a TTS-ready voice message from a priority-sorted detection list.

    Announces the top 3 announceable detections.  Prepends a safety prefix
    for critical and high-priority objects.  Never announces low-confidence
    detections below their tier threshold.
    """
    spoken: list[str] = []
    for det in detections:
        if not should_announce(det):
            continue
        p = get_priority(det.get("label", ""))
        prefix = _PRIORITY_PREFIX.get(p, "")
        label = det.get("label", "Object")
        position = det.get("position", "ahead")
        spoken.append(f"{prefix}{label} {position}.")
        if len(spoken) == 3:
            break

    return " ".join(spoken) if spoken else "No objects detected."
