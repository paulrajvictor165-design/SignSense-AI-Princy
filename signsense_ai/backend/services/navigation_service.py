"""
SignSense AI — Navigation Service
===================================
Business logic for walking route calculation and geocoding.

Extracted from navigation_routes.py (Module 2 refactor).

Problems fixed
--------------
1. ``os.getenv("ORS_API_KEY")`` called inside every route request.
   Fixed by reading from ``settings.ORS_API_KEY`` at construction time.

2. All geocoding logic, ORS HTTP calls, coordinate transformation, fallback
   logic, and voice message construction were inside the route function.
   Fixed by extracting each concern to a dedicated method.

3. Duplicate routing logic existed in both the Flask backend AND in the
   Flutter NavigationService (Dart) — this is problem C6 from Phase 1.
   This module is now the single authoritative source for routing on the
   backend side.  Module 6 will remove the duplicate Dart implementation.

Pipeline (unchanged)
---------------------
1. Geocode destination name via Nominatim.
2. Calculate walking route via OpenRouteService.
3. Parse ORS GeoJSON into a flat, Flutter-consumable structure.
4. Fall back to a straight-line route when ORS is unavailable.

API contract preserved
-----------------------
Response keys route_points, instructions, distance_meters, duration_seconds,
voice_message are identical to the original route implementation.
"""

from __future__ import annotations

import logging
import requests

from config.settings import settings
from database.db import save_navigation

logger = logging.getLogger(__name__)

# ── External API endpoints ─────────────────────────────────────────────────────
_NOMINATIM_URL = "https://nominatim.openstreetmap.org/search"
_ORS_URL       = "https://api.openrouteservice.org/v2/directions/foot-walking/geojson"

# ── ORS turn instruction types → human-readable text ──────────────────────────
_TURN_INSTRUCTIONS: dict[int, str] = {
    0:  "Head straight.",
    1:  "Turn right.",
    2:  "Turn right.",
    3:  "Turn right.",
    4:  "Turn left.",
    5:  "Turn left.",
    6:  "Turn left.",
    7:  "Continue straight.",
    8:  "Enter roundabout.",
    9:  "Exit roundabout.",
    10: "U-turn.",
    11: "Goal reached. You have arrived.",
    12: "Destination on left.",
    13: "Destination on right.",
}


class NavigationService:
    """
    Service for walking route calculation.

    All external HTTP calls (Nominatim, ORS) are encapsulated here.
    The route layer calls only ``get_route()`` — the breakdown of steps
    is hidden from HTTP-layer code.
    """

    def __init__(self) -> None:
        self._ors_key: str = settings.ORS_API_KEY
        logger.info("NavigationService initialised. ORS key present: %s", bool(self._ors_key))

    def get_route(
        self,
        start_lat: float,
        start_lng: float,
        destination: str,
    ) -> dict:
        """
        Calculate a walking route from *start_lat/lng* to *destination*.

        Parameters
        ----------
        start_lat, start_lng:
            Current GPS coordinates of the user.
        destination:
            Place name or address string (will be geocoded).

        Returns
        -------
        dict with keys:
            route_points      — List of {lat, lng} dicts.
            instructions      — List of turn-by-turn instruction strings.
            distance_meters   — Total route distance.
            duration_seconds  — Estimated walking time.
            voice_message     — TTS-ready route summary.

        Raises
        ------
        ValueError
            When the destination cannot be geocoded.
        """
        destination = destination.strip()

        if not destination:
            raise ValueError("Destination cannot be empty.")        
        # Step 1: Geocode destination name → coordinates.
        dest_coords = self.geocode(destination)
        if dest_coords is None:
            raise ValueError(
                f"Could not find location: '{destination}'. "
                "Please try a different address or landmark name."
            )
        end_lat, end_lng = dest_coords

        # Persist the navigation request (best-effort — never blocks the response).
        try:
            save_navigation(destination)
        except Exception as db_exc:
            logger.warning(
                "Navigation request completed, but database save failed: %s",
                db_exc,
            )

        # Step 2: Try ORS for a real walking route; fall back on failure.
        if self._ors_key:
            try:
                return self._get_ors_route(start_lat, start_lng, end_lat, end_lng)
            except Exception as exc:
                logger.error("ORS routing failed: %s — using straight-line fallback.", exc)

        return self._straight_line_fallback(
            start_lat, start_lng, end_lat, end_lng, destination
        )

    def geocode(self, place: str) -> tuple[float, float] | None:
        """
        Geocode a place name using Nominatim.

        Returns (lat, lng) on success, None on failure.
        Never raises — failures are logged and return None.
        """
        try:
            resp = requests.get(
                _NOMINATIM_URL,
                params={"q": place, "format": "json", "limit": 1},
                headers={"User-Agent": "SignSenseAI/1.0 (accessibility project)"},
                timeout=10,
            )
            resp.raise_for_status()
            results = resp.json()
            if results:
                return float(results[0]["lat"]), float(results[0]["lon"])
            logger.warning("Nominatim returned no results for: %s", place)
        except Exception as exc:
            logger.warning("Geocoding failed for '%s': %s", place, exc)
        return None

    # ── Private helpers ────────────────────────────────────────────────────

    def _get_ors_route(
        self,
        start_lat: float,
        start_lng: float,
        end_lat: float,
        end_lng: float,
    ) -> dict:
        """Call ORS, parse GeoJSON, and return the Flutter-ready dict."""
        resp = requests.post(
            _ORS_URL,
            json={
                "coordinates": [[start_lng, start_lat], [end_lng, end_lat]],
                "language":    "en",
                "units":       "m",
                "instructions": True,
            },
            headers={
                "Authorization": self._ors_key,
                "Content-Type":  "application/json",
            },
            timeout=15,
        )
        resp.raise_for_status()
        data = resp.json()

        features = data.get("features", [])
        if not features:
            raise ValueError("ORS returned no route features.")

        feature  = features[0]
        geometry = feature["geometry"]["coordinates"]
        props    = feature["properties"]
        segments = props.get("segments", [])

        route_points = [{"lat": c[1], "lng": c[0]} for c in geometry]

        instructions: list[str] = []
        for seg in segments:
            for step in seg.get("steps", []):
                step_type   = step.get("type", 0)
                instruction = step.get("instruction") or _TURN_INSTRUCTIONS.get(step_type, "Continue.")
                distance    = step.get("distance", 0)
                if distance > 0:
                    instruction = f"{instruction} for {int(distance)} meters."
                instructions.append(instruction)

        summary      = props.get("summary", {})
        distance_m   = summary.get("distance", 0)
        duration_s   = summary.get("duration", 0)
        duration_min = int(duration_s / 60)

        return {
            "route_points":     route_points,
            "instructions":     instructions,
            "distance_meters":  distance_m,
            "duration_seconds": duration_s,
            "voice_message": (
                f"Route found. {len(instructions)} steps. "
                f"Distance: {int(distance_m)} meters. "
                f"Estimated time: {duration_min} minutes. "
                f"{instructions[0] if instructions else 'Start walking.'}"
            ),
        }

    @staticmethod
    def _straight_line_fallback(
        start_lat: float,
        start_lng: float,
        end_lat: float,
        end_lng: float,
        destination: str,
    ) -> dict:
        """Return a minimal two-point route when ORS is unavailable."""
        return {
            "route_points": [
                {"lat": start_lat, "lng": start_lng},
                {"lat": end_lat,   "lng": end_lng},
            ],
            "instructions": [
                f"Head towards {destination}.",
                "Continue straight.",
                "You have arrived at your destination.",
            ],
            "distance_meters":  0,
            "duration_seconds": 0,
            "voice_message": (
                f"Detailed walking directions to {destination} "
                "are temporarily unavailable. "
                "An approximate destination line is shown on the map. "
                "Please proceed carefully and use assistance if required."
            ),            
        }


# ── Module-level singleton ─────────────────────────────────────────────────────
navigation_service = NavigationService()
