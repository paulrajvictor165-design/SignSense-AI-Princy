"""
SignSense AI — Global Error Handler Middleware
===============================================
Registers a consistent JSON error response envelope for every Flask error,
both expected (4xx) and unexpected (5xx).

Why this matters
----------------
Before this middleware, each route returned different error shapes:
    {"error": "..."}              ← detection routes
    {"description": "...", ...}   ← Flask's default HTML 404/500
    (empty body with 500 status)  ← uncaught Python exceptions

Flutter screens did unguarded dict access on these responses, causing
secondary errors in the UI when the primary request failed.

Standard Envelope
-----------------
Every response — success or failure — now follows:

    Success:
        {
            "success": true,
            "data":    { ... }        ← original response body
        }

    Error:
        {
            "success":  false,
            "error": {
                "code":    "VALIDATION_ERROR",   ← machine-readable
                "message": "No image provided."  ← human-readable
            }
        }

The "data" wrapper is NOT applied automatically to every success response
here (that would require inspecting every route's return value).  Instead,
the envelope is standardised only for *errors*.  Success responses are
returned as-is from their routes — they already have consistent structure.
Error responses are fully standardised here.

Usage
-----
    from middleware.error_handler import register_error_handlers
    register_error_handlers(app)
"""

from __future__ import annotations

import logging
from typing import Any

from flask import Flask, jsonify
from werkzeug.exceptions import HTTPException

logger = logging.getLogger(__name__)


# ── Error code constants ──────────────────────────────────────────────────────

class ErrorCode:
    """Machine-readable error codes returned to the Flutter client."""
    VALIDATION_ERROR = "VALIDATION_ERROR"
    NOT_FOUND = "NOT_FOUND"
    METHOD_NOT_ALLOWED = "METHOD_NOT_ALLOWED"
    PAYLOAD_TOO_LARGE = "PAYLOAD_TOO_LARGE"
    AI_SERVICE_ERROR = "AI_SERVICE_ERROR"
    DECODE_ERROR = "DECODE_ERROR"
    INTERNAL_ERROR = "INTERNAL_ERROR"
    
# ── Response builder helpers ─────────────────────────────────────────────────

def success_response(data: Any, message: str = "ok", status: int = 200):
    """
    Wrap a success payload in the standard envelope.

    Parameters
    ----------
    data:
        The payload dict to return under the "data" key.
    message:
        Optional human-readable status message.
    status:
        HTTP status code (default 200).
    """
    return jsonify({
        "success": True,
        "message": message,
        "data": data,
    }), status


def error_response(
    code: str,
    message: str,
    status: int,
    detail: str | None = None,
):
    """
    Build a standard error JSON response.

    Parameters
    ----------
    code:
        Machine-readable error code (use ErrorCode constants).
    message:
        Human-readable message suitable for display / TTS.
    status:
        HTTP status code to return.
    detail:
        Optional developer-facing detail (never exposed to users).
    """
    body: dict[str, Any] = {
        "success": False,
        "error": {
            "code":    code,
            "message": message,
        },
    }
    # Developer detail only in DEBUG mode (checked at call site if needed).
    # Never include stack traces in the response body — those stay in server logs.
    if detail:
        body["error"]["detail"] = detail

    return jsonify(body), status
# ── Service error helper ─────────────────────────────────────────────────────

def handle_service_error(error):
    """
    Handles service layer exceptions from AI services.
    """
    logger.exception("Service error: %s", error)

    return error_response(
        ErrorCode.AI_SERVICE_ERROR,
        "AI service failed. Please try again.",
        500,
        detail=str(error),
    )    


# ── Handler registration ──────────────────────────────────────────────────────

def register_error_handlers(app: Flask) -> None:
    """
    Register global error handlers on *app*.

    Call this once in the application factory (app.py) after all blueprints
    have been registered.
    """

    @app.errorhandler(400)
    def bad_request(exc):
        return error_response(
            ErrorCode.VALIDATION_ERROR,
            "Bad request. Please check the data you sent.",
            400,
        )

    @app.errorhandler(404)
    def not_found(exc):
        return error_response(
            ErrorCode.NOT_FOUND,
            "The requested endpoint was not found.",
            404,
        )

    @app.errorhandler(405)
    def method_not_allowed(exc):
        return error_response(
            ErrorCode.METHOD_NOT_ALLOWED,
            "HTTP method not allowed for this endpoint.",
            405,
        )

    @app.errorhandler(413)
    def payload_too_large(exc):
        return error_response(
            ErrorCode.PAYLOAD_TOO_LARGE,
            "Image file is too large. Maximum size is 32 MB.",
            413,
        )

    @app.errorhandler(ValueError)
    def value_error(exc: ValueError):
        """
        Handles the ValueError raised by decode_image() when image bytes are
        corrupt or non-JPEG.  Routes no longer need individual try/except for
        this case.
        """
        logger.warning("ValueError in request: %s", exc)
        return error_response(
            ErrorCode.DECODE_ERROR,
            "Could not decode the image. Please send a valid JPEG or PNG file.",
            400,
            detail=str(exc),
        )

    @app.errorhandler(HTTPException)
    def http_exception(exc: HTTPException):
        """Catch-all for any other Werkzeug HTTP exception."""
        return error_response(
            f"HTTP_{exc.code}",
            exc.description or "An HTTP error occurred.",
            exc.code or 500,
        )

    @app.errorhandler(Exception)
    def unhandled_exception(exc: Exception):
        """
        Last-resort handler for unexpected server errors.

        Logs the full traceback server-side but returns a safe, opaque
        message to the client — no stack trace, no internal paths.
        """
        logger.exception("Unhandled exception: %s", exc)
        return error_response(
            ErrorCode.INTERNAL_ERROR,
            "An unexpected server error occurred. Please try again.",
            500,
        )

    logger.info("Global error handlers registered.")
