"""
SignSense AI — Request Validation Middleware
=============================================
Provides decorators and helper functions to validate incoming requests
before they reach route handlers or AI processing.

Why this matters
----------------
Previously, a malformed request (empty body, text file uploaded as 'image',
5 MB JSON payload) would reach the YOLO/EasyOCR/Gemini pipeline and produce
an uninformative Python traceback converted to a 500 response.

This module intercepts bad requests early, returning structured 400 errors
with messages the Flutter client can display directly.

Usage
-----
Decorator style (recommended for routes):

    from middleware.request_validator import require_image_file

    @detection_bp.route("/objects", methods=["POST"])
    @require_image_file
    def detect_objects():
        image_bytes = request.files["image"].read()
        ...

Function style (for inline use):

    from middleware.request_validator import validate_image_file
    from middleware.error_handler import error_response, ErrorCode

    result = validate_image_file(request)
    if result is not None:
        return result        # already an error response tuple
    image_bytes = request.files["image"].read()
"""

from __future__ import annotations

import functools
import logging
from typing import Callable

from flask import request
from middleware.error_handler import error_response, ErrorCode

logger = logging.getLogger(__name__)

# ── Configuration ─────────────────────────────────────────────────────────────

# Accepted MIME types for the 'image' field.
# Note: the camera pipeline sends 'image/jpeg'; allow common alternatives
# for static screens (OCR, Currency, Scene) that use image_picker.
_ALLOWED_MIME_TYPES: frozenset[str] = frozenset({
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
    "image/bmp",
    "application/octet-stream",   # some Android camera plugins report this
})

# Maximum image file size in bytes (32 MB — overrides Flask's global limit
# for per-route use when needed).
_MAX_IMAGE_BYTES: int = 32 * 1024 * 1024  # 32 MB


# ── Core validator ────────────────────────────────────────────────────────────

def validate_image_file(req=None):
    """
    Validate that the current (or provided) request contains a valid 'image'
    file upload.

    Returns None when validation passes (caller continues normally).
    Returns a Flask response tuple when validation fails (caller should
    return this directly).

    Parameters
    ----------
    req:
        The Flask request object.  Defaults to the thread-local ``request``
        when not provided.
    """
    if req is None:
        req = request

    # 1. Check multipart field exists.
    if "image" not in req.files:
        return error_response(
            ErrorCode.VALIDATION_ERROR,
            "No image provided. Please include an 'image' field in the request.",
            400,
        )

    file = req.files["image"]

    # 2. Check the file has a name (not an empty upload slot).
    if file.filename == "":
        return error_response(
            ErrorCode.VALIDATION_ERROR,
            "Empty image file received. Please capture or select an image first.",
            400,
        )

    # 3. MIME type check.
    mime = (file.mimetype or "").lower().strip()
    if mime and mime not in _ALLOWED_MIME_TYPES:
        logger.warning("Rejected MIME type: %s from %s", mime, req.remote_addr)
        return error_response(
            ErrorCode.VALIDATION_ERROR,
            f"Unsupported image format '{mime}'. "
            "Please use JPEG, PNG, or WebP.",
            400,
        )

    # 4. Size check — read header Content-Length when available.
    #    (Full body size is enforced by Flask's MAX_CONTENT_LENGTH, but that
    #    raises a 413 which is already handled by the error_handler middleware.)
    content_length = req.content_length
    if content_length and content_length > _MAX_IMAGE_BYTES:
        return error_response(
            ErrorCode.PAYLOAD_TOO_LARGE,
            f"Image is too large ({content_length // (1024 * 1024)} MB). "
            "Maximum allowed size is 32 MB.",
            413,
        )

    return None  # Validation passed.


def validate_json_body(*required_keys: str):
    """
    Validate that the request has a JSON body containing all *required_keys*.

    Returns None when validation passes, or a Flask error response tuple.

    Usage
    -----
        result = validate_json_body("start_lat", "start_lng", "destination")
        if result is not None:
            return result
        data = request.get_json(force=True)
    """
    data = request.get_json(silent=True)

    if data is None:
        return error_response(
            ErrorCode.VALIDATION_ERROR,
            "Request body must be valid JSON.",
            400,
        )

    missing = [k for k in required_keys if k not in data or data[k] is None]
    if missing:
        return error_response(
            ErrorCode.VALIDATION_ERROR,
            f"Missing required fields: {', '.join(missing)}.",
            400,
        )

    return None  # Validation passed.


# ── Decorator ─────────────────────────────────────────────────────────────────

def require_image_file(func: Callable) -> Callable:
    """
    Route decorator that validates the 'image' file field before calling
    the route handler.

    If validation fails, the error response is returned directly without
    entering the route function.

    Example
    -------
        @detection_bp.route("/objects", methods=["POST"])
        @require_image_file
        def detect_objects():
            image_bytes = request.files["image"].read()
            ...
    """
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        result = validate_image_file()
        if result is not None:
            return result
        return func(*args, **kwargs)
    return wrapper
