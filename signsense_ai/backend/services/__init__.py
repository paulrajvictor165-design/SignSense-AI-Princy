"""
SignSense AI — Services package
================================
Exports singleton service instances so that consumers can import from a
single location:

    from services import detection_service, ocr_service, scene_service, ...

Each singleton is lazily initialised on first import of its own module.
"""

from services.detection_service import detection_service
from services.ocr_service import ocr_service
from services.scene_service import scene_service
from services.currency_service import currency_service
from services.navigation_service import navigation_service

__all__ = [
    "detection_service",
    "ocr_service",
    "scene_service",
    "currency_service",
    "navigation_service",
]
