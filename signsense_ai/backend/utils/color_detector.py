"""
Color detection utility — identifies dominant colors in an image.
"""

import cv2
import numpy as np
from typing import List


# Named color ranges in HSV space
COLOR_RANGES = {
    "Red": [(0, 100, 100, 10, 255, 255), (160, 100, 100, 180, 255, 255)],
    "Orange": [(11, 100, 100, 25, 255, 255)],
    "Yellow": [(26, 100, 100, 35, 255, 255)],
    "Green": [(36, 40, 40, 90, 255, 255)],
    "Cyan": [(91, 100, 100, 100, 255, 255)],
    "Blue": [(101, 80, 80, 130, 255, 255)],
    "Purple": [(131, 50, 50, 160, 255, 255)],
    "Pink": [(161, 50, 50, 170, 255, 255)],
    "White": [(0, 0, 200, 180, 30, 255)],
    "Grey": [(0, 0, 80, 180, 30, 200)],
    "Black": [(0, 0, 0, 180, 255, 50)],
    "Brown": [(10, 60, 40, 20, 200, 160)],
}


def detect_dominant_colors(
    img: np.ndarray,
    top_n: int = 3,
) -> List[dict]:
    """
    Detect the top N dominant colors in an image using HSV masking.

    Args:
        img: OpenCV BGR image
        top_n: Number of top colors to return

    Returns:
        List of dicts with 'name' and 'percentage'
    """
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    total_pixels = hsv.shape[0] * hsv.shape[1]
    scores: dict[str, int] = {}

    for color_name, ranges in COLOR_RANGES.items():
        count = 0
        for r in ranges:
            if len(r) == 6:
                lower = np.array([r[0], r[1], r[2]], dtype=np.uint8)
                upper = np.array([r[3], r[4], r[5]], dtype=np.uint8)
                mask = cv2.inRange(hsv, lower, upper)
                count += cv2.countNonZero(mask)
        scores[color_name] = count

    # Sort by pixel count descending
    sorted_colors = sorted(scores.items(), key=lambda x: x[1], reverse=True)

    results = []
    for name, count in sorted_colors[:top_n]:
        if count > 0:
            pct = round((count / total_pixels) * 100, 1)
            results.append({"name": name, "percentage": pct})

    return results if results else [{"name": "Unknown", "percentage": 0}]
