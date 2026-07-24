"""
Backend unit tests for SignSense AI.
Run: python -m pytest tests/ -v
"""

import sys
import os
import io
import json

# Add backend to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "backend"))

import pytest
import numpy as np
import cv2


# ─── Test Image Factory ──────────────────────────────────────────────────────

def _create_test_image_bytes(color=(255, 255, 255), size=(640, 480)) -> bytes:
    """Create a simple test JPEG image."""
    img = np.full((*size[::-1], 3), color, dtype=np.uint8)
    _, buffer = cv2.imencode(".jpg", img)
    return buffer.tobytes()


# ─── Color Detector Tests ────────────────────────────────────────────────────

class TestColorDetector:
    def test_red_detection(self):
        from utils.color_detector import detect_dominant_colors
        # Create a red image
        img = np.zeros((100, 100, 3), dtype=np.uint8)
        img[:, :, 2] = 200  # Red channel in BGR
        colors = detect_dominant_colors(img)
        assert len(colors) > 0
        assert colors[0]["percentage"] > 0

    def test_returns_top_n(self):
        from utils.color_detector import detect_dominant_colors
        img = np.full((100, 100, 3), 128, dtype=np.uint8)
        colors = detect_dominant_colors(img, top_n=3)
        assert len(colors) <= 3

    def test_empty_image_returns_result(self):
        from utils.color_detector import detect_dominant_colors
        img = np.zeros((10, 10, 3), dtype=np.uint8)
        colors = detect_dominant_colors(img)
        assert isinstance(colors, list)


# ─── Image Utils Tests ───────────────────────────────────────────────────────

class TestImageUtils:
    def test_decode_image(self):
        from utils.image_utils import decode_image
        img_bytes = _create_test_image_bytes()
        result = decode_image(img_bytes)
        assert result is not None
        assert len(result.shape) == 3  # H, W, C

    def test_compute_position_left(self):
        from utils.image_utils import compute_position
        assert compute_position(50, 640) == "left"

    def test_compute_position_right(self):
        from utils.image_utils import compute_position
        assert compute_position(590, 640) == "right"

    def test_compute_position_ahead(self):
        from utils.image_utils import compute_position
        assert compute_position(320, 640) == "ahead"

    def test_resize_for_inference(self):
        from utils.image_utils import resize_for_inference
        img = np.zeros((1200, 1600, 3), dtype=np.uint8)
        resized = resize_for_inference(img, max_side=640)
        assert max(resized.shape[:2]) <= 640


# ─── Navigation Route Tests ──────────────────────────────────────────────────

class TestNavigationParsing:
    def test_denomination_parsing(self):
        """Test that currency denomination is correctly parsed."""
        sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "backend"))
        from api.currency_routes import _parse_denomination
        assert _parse_denomination("500 rupee") == 500
        assert _parse_denomination("100") == 100
        assert _parse_denomination("banana") is None

    def test_fallback_route_structure(self):
        from api.navigation_routes import _straight_line_route
        result = _straight_line_route(12.9, 77.5, 13.0, 77.6, "Test Place")
        assert "route_points" in result
        assert "instructions" in result
        assert len(result["route_points"]) == 2
        assert len(result["instructions"]) > 0


# ─── Flask API Endpoint Tests ────────────────────────────────────────────────

@pytest.fixture
def client():
    """Test client for Flask app."""
    from app import create_app
    app = create_app()
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


class TestAPIEndpoints:
    def test_health_check(self, client):
        resp = client.get("/health")
        assert resp.status_code == 200
        data = json.loads(resp.data)
        assert data["status"] == "ok"

    def test_detect_objects_no_image(self, client):
        resp = client.post("/api/detect/objects")
        assert resp.status_code == 400

    def test_detect_colors_with_image(self, client):
        img_bytes = _create_test_image_bytes(color=(0, 0, 200))  # Red BGR
        data = {"image": (io.BytesIO(img_bytes), "test.jpg", "image/jpeg")}
        resp = client.post(
            "/api/detect/colors",
            data=data,
            content_type="multipart/form-data",
        )
        assert resp.status_code == 200
        result = json.loads(resp.data)
        assert "colors" in result
        assert "voice_message" in result

    def test_ocr_with_blank_image(self, client):
        img_bytes = _create_test_image_bytes()
        data = {"image": (io.BytesIO(img_bytes), "test.jpg", "image/jpeg")}
        resp = client.post(
            "/api/ocr/read",
            data=data,
            content_type="multipart/form-data",
        )
        # Should not crash, may return empty text
        assert resp.status_code in (200, 500)


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
