"""
Image utilities shared across detection modules.
"""

import io
import cv2
import numpy as np
from PIL import Image, UnidentifiedImageError


def decode_image(image_bytes: bytes) -> np.ndarray:
    """
    Decode image bytes to an OpenCV BGR numpy array.

    Accepts any PIL-supported format (JPEG, PNG, WebP, BMP, …).
    Raises ``ValueError`` with a human-readable message when the bytes cannot
    be parsed — callers should catch this and return an appropriate 400 / 500
    response rather than letting a cryptic exception bubble up.

    Why the extra guard?
    ─────────────────────
    The original pipeline sent raw YUV420 plane[0] bytes labeled as "JPEG".
    PIL.Image.open() raises ``UnidentifiedImageError`` on those bytes rather
    than producing a valid image.  The guard below converts that opaque
    exception into a clear ``ValueError`` so Flask routes can return a
    meaningful error message.
    """
    try:
        img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    except UnidentifiedImageError as exc:
        raise ValueError(
            "Could not decode image bytes. "
            "Expected a valid JPEG/PNG/WebP file. "
            f"PIL reported: {exc}"
        ) from exc
    except Exception as exc:
        raise ValueError(f"Image decode failed: {exc}") from exc

    # PIL RGB → OpenCV BGR
    return cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)


def decode_image_safe(image_bytes: bytes) -> np.ndarray | None:
    """
    Non-raising wrapper around :func:`decode_image`.

    Returns ``None`` when decoding fails.  Use this in inference loops where
    a single bad frame should not abort the whole request.
    """
    try:
        return decode_image(image_bytes)
    except ValueError:
        return None


def compute_position(center_x: float, image_width: int) -> str:
    """
    Classify horizontal position of a bounding box center.

    Args:
        center_x: Pixel x-coordinate of bounding box center
        image_width: Total image width in pixels

    Returns:
        ``"left"`` | ``"ahead"`` | ``"right"``
    """
    if image_width <= 0:
        return "ahead"
    ratio = center_x / image_width
    if ratio < 0.33:
        return "left"
    elif ratio > 0.67:
        return "right"
    else:
        return "ahead"


def resize_for_inference(img: np.ndarray, max_side: int = 640) -> np.ndarray:
    """
    Resize an image so its longest side is at most *max_side* pixels.

    Maintains aspect ratio.  Returns the original array unchanged when it
    already fits within the constraint.

    Args:
        img:      OpenCV BGR image as a numpy array.
        max_side: Maximum allowed size for the longest dimension (default 640).

    Returns:
        Resized (or original) numpy array.
    """
    h, w = img.shape[:2]
    if max(h, w) <= max_side:
        return img
    scale = max_side / max(h, w)
    new_w = int(w * scale)
    new_h = int(h * scale)
    return cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_AREA)
