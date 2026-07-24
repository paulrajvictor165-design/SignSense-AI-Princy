"""
SQLite database initialization and helper functions.
"""

import os
import sqlite3
import logging
from flask import Flask, g

logger = logging.getLogger(__name__)
DATABASE_PATH = os.path.join(os.path.dirname(__file__), "signsense.db")


def get_db():
    """Get a database connection, creating one if needed for this request context."""
    if "db" not in g:
        g.db = sqlite3.connect(DATABASE_PATH, detect_types=sqlite3.PARSE_DECLTYPES)
        g.db.row_factory = sqlite3.Row
    return g.db


def close_db(e=None):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_db(app: Flask):
    """Create tables and register teardown."""
    with app.app_context():
        db = sqlite3.connect(DATABASE_PATH)
        _create_tables(db)
        db.close()
    app.teardown_appcontext(close_db)


def _create_tables(db: sqlite3.Connection):
    db.executescript("""
        CREATE TABLE IF NOT EXISTS detection_history (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            label     TEXT    NOT NULL,
            type      TEXT    NOT NULL,
            confidence REAL   DEFAULT 0.0,
            position  TEXT    DEFAULT '',
            timestamp TEXT    NOT NULL DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS ocr_history (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            text      TEXT    NOT NULL,
            timestamp TEXT    NOT NULL DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS navigation_history (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            destination TEXT    NOT NULL,
            timestamp   TEXT    NOT NULL DEFAULT (datetime('now'))
        );
    """)
    db.commit()


def save_detection(
    label: str,
    det_type: str,
    confidence: float = 0.0,
    position: str = "",
):
    try:
        db = sqlite3.connect(DATABASE_PATH)
        db.execute(
            "INSERT INTO detection_history (label, type, confidence, position) VALUES (?, ?, ?, ?)",
            (label, det_type, confidence, position),
        )
        db.commit()
        db.close()
    except Exception as exc:
        logger.warning("Failed to save detection: %s", exc)


def save_ocr_result(text: str):
    try:
        db = sqlite3.connect(DATABASE_PATH)
        db.execute("INSERT INTO ocr_history (text) VALUES (?)", (text,))
        db.commit()
        db.close()
    except Exception as exc:
        logger.warning("Failed to save OCR result: %s", exc)


def save_navigation(destination: str):
    """Persist a navigation request to the navigation_history table."""
    try:
        db = sqlite3.connect(DATABASE_PATH)
        db.execute(
            "INSERT INTO navigation_history (destination) VALUES (?)",
            (destination,),
        )
        db.commit()
        db.close()
    except Exception as exc:
        logger.warning("Failed to save navigation history: %s", exc)
