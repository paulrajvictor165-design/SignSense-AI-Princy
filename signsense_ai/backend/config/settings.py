"""
SignSense AI — Central Application Settings
============================================
Single source of truth for all configuration values.

All values are read from environment variables (via python-dotenv in app.py).
Missing required keys raise a clear RuntimeError at startup, preventing the
application from starting in a silently broken state.

Usage
-----
    from config.settings import settings

    api_key = settings.GEMINI_API_KEY
    debug   = settings.DEBUG
"""

from __future__ import annotations

import os
import logging

logger = logging.getLogger(__name__)


class _Settings:
    """
    Reads and validates all environment variables at instantiation time.

    Design decisions
    ----------------
    * Required keys (those with no default) raise RuntimeError immediately
      when missing.  This surfaces misconfiguration before the first request
      rather than at runtime inside a route.
    * Optional keys fall back to documented defaults and log a warning so
      developers see exactly what is not configured.
    * No third-party library (Pydantic, dynaconf) is used — the project's
      existing requirements.txt does not include one and adding a dependency
      for config reading alone is not justified.
    """

    # ── Google Gemini ─────────────────────────────────────────────────────────
    GEMINI_API_KEY: str

    # ── OpenRouteService ──────────────────────────────────────────────────────
    ORS_API_KEY: str

    # ── Roboflow (optional) ───────────────────────────────────────────────────
    ROBOFLOW_API_KEY: str

    # ── Flask application ─────────────────────────────────────────────────────
    DEBUG: bool
    PORT: int
    SECRET_KEY: str

    # ── AI model paths ────────────────────────────────────────────────────────
    YOLO_MODEL_PATH: str
    CURRENCY_MODEL_PATH: str

    # ── Request limits ────────────────────────────────────────────────────────
    MAX_UPLOAD_BYTES: int          # 32 MB default
    MAX_IMAGE_DIMENSION: int       # Max pixel side for safety

    # ── CORS ─────────────────────────────────────────────────────────────────
    CORS_ORIGINS: list[str]

    def __init__(self) -> None:
        # ── Required keys ─────────────────────────────────────────────────
        # GEMINI_API_KEY is required for Scene Description and Currency fallback.
        # If not set, those features will return a clear error — but the server
        # can still start so Object Detection and MediaPipe work without a key.
        self.GEMINI_API_KEY = self._optional(
            "GEMINI_API_KEY", "",
            warn_if_default=True,
        )

        # ORS_API_KEY is optional — navigation won't work without it, but
        # all other features are unaffected.
        self.ORS_API_KEY = self._optional("ORS_API_KEY", "", warn_if_default=False)

        # ── Optional keys with defaults ───────────────────────────────────
        self.ROBOFLOW_API_KEY = self._optional("ROBOFLOW_API_KEY", "")

        self.SECRET_KEY = self._optional(
            "SECRET_KEY",
            "signsense-ai-secret-key-change-in-production",
            warn_if_default=True,
        )

        self.DEBUG = self._optional("DEBUG", "true").lower() == "true"
        self.PORT  = int(self._optional("PORT", "5000"))

        self.YOLO_MODEL_PATH = self._optional(
            "YOLO_MODEL_PATH", "yolov8n.pt"
        )
        self.CURRENCY_MODEL_PATH = self._optional(
            "CURRENCY_MODEL_PATH", ""
        )

        self.MAX_UPLOAD_BYTES    = int(self._optional("MAX_UPLOAD_BYTES", str(32 * 1024 * 1024)))
        self.MAX_IMAGE_DIMENSION = int(self._optional("MAX_IMAGE_DIMENSION", "4096"))

        raw_cors = self._optional("CORS_ORIGINS", "*")
        self.CORS_ORIGINS = [o.strip() for o in raw_cors.split(",")]

        logger.info("Settings loaded — DEBUG=%s  PORT=%s", self.DEBUG, self.PORT)

    # ── Internal helpers ──────────────────────────────────────────────────────

    @staticmethod
    def _require(key: str) -> str:
        """
        Return the value of *key* from the environment.

        Raises
        ------
        RuntimeError
            When the key is absent or set to an empty string.
        """
        value = os.getenv(key, "").strip()
        if not value:
            raise RuntimeError(
                f"[SignSense AI] Required environment variable '{key}' is not set. "
                f"Copy backend/.env.example to backend/.env and fill in the value."
            )
        return value

    @staticmethod
    def _optional(
        key: str,
        default: str,
        warn_if_default: bool = False,
    ) -> str:
        """
        Return the value of *key* from the environment, or *default*.

        Parameters
        ----------
        key:
            Environment variable name.
        default:
            Fallback value used when the key is absent.
        warn_if_default:
            When True, emit a warning log when the default is used.
            Useful for security-sensitive values like SECRET_KEY.
        """
        value = os.getenv(key, "").strip()
        if not value:
            if warn_if_default:
                logger.warning(
                    "[SignSense AI] '%s' not set — using default. "
                    "Override in .env before deploying to production.",
                    key,
                )
            return default
        return value


# ── Module-level singleton ────────────────────────────────────────────────────
# Instantiated once at import time.  Any configuration error surfaces
# immediately when the Flask app starts, not on the first request.
settings = _Settings()
