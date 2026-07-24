"""
SignSense AI — Navigation Routes (Controller Layer)
====================================================
HTTP controller for walking route calculation.

Architecture (Module 2)
------------------------
Before: Route contained geocoding, ORS HTTP calls, coordinate transformation,
        fallback logic, and voice message construction — all mixed in a single
        function across 184 lines.

After:  Thin controller — validates JSON body, delegates to NavigationService,
        returns JSON.  All business logic lives in services/navigation_service.py.

API contract
------------
POST /api/navigation/route
    Request:  {start_lat, start_lng, destination}
    Response: {route_points, instructions, distance_meters, duration_seconds,
               voice_message}
Response shape is 100% backward compatible.
"""

import logging
from flask import Blueprint, request, jsonify

from middleware.request_validator import validate_json_body
from middleware.error_handler import error_response, ErrorCode
from services.navigation_service import navigation_service

logger = logging.getLogger(__name__)
navigation_bp = Blueprint("navigation", __name__)


@navigation_bp.route("/route", methods=["POST"])
def get_route():
    """
    Calculate a walking route from current coordinates to a named destination.
    Uses Nominatim for geocoding and OpenRouteService for turn-by-turn routing.
    """
    # Validate required JSON fields.
    validation_error = validate_json_body("start_lat", "start_lng", "destination")
    if validation_error:
        return validation_error

    try:
        data = request.get_json(force=True)

        start_lat = float(data["start_lat"])
        start_lng = float(data["start_lng"])
        destination = str(data["destination"]).strip()

        if not destination:
            return error_response(
                ErrorCode.VALIDATION_ERROR,
                "Destination cannot be empty.",
                400,
            )

        if not -90 <= start_lat <= 90:
            return error_response(
                ErrorCode.VALIDATION_ERROR,
                "start_lat must be between -90 and 90.",
                400,
            )

        if not -180 <= start_lng <= 180:
            return error_response(
                ErrorCode.VALIDATION_ERROR,
                "start_lng must be between -180 and 180.",
                400,
            )

        result = navigation_service.get_route(
            start_lat,
            start_lng,
            destination,
        )
        return jsonify(result)   
    except ValueError as exc:
        error_message = str(exc)

        if "Could not find location" in error_message:
            logger.warning(
                "Navigation route: destination not found — %s",
                exc,
            )
            return jsonify({
                "error": error_message,
                "voice_message": (
                    f"Could not find {destination}. "
                    "Please try a different address or landmark name."
                ),
            }), 404

        logger.warning(
            "Navigation route: invalid numeric value — %s",
            exc,
        )
        return error_response(
            ErrorCode.VALIDATION_ERROR,
            "Latitude and longitude must be valid numbers.",
            400,
        )   
    except (TypeError, KeyError) as exc:
        logger.warning("Navigation route: invalid request data — %s", exc)
        return error_response(
            ErrorCode.VALIDATION_ERROR,
            "Invalid navigation request data.",
            400,
        )

    except Exception as exc:
        logger.exception("Navigation route failed: %s", exc)
        return error_response(
            ErrorCode.INTERNAL_ERROR,
            "Navigation service failed. Please try again.",
            500,
        )