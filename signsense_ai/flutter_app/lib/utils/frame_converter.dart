import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// Converts a raw [CameraImage] to a JPEG [Uint8List] that can be sent to the
/// Flask backend's multipart/form-data endpoint.
///
/// Why this class exists
/// ──────────────────────
/// The camera plugin delivers frames in one of two formats:
///
/// • **Android** — [ImageFormatGroup.yuv420] (three planes: Y, U, V).
///   Plane 0 is the luma (Y) channel.  Planes 1 and 2 are the chroma (U/V)
///   channels at half resolution with a per-pixel byte stride of 2 on most
///   HALs (interleaved NV21/NV12).  Sending just plane[0].bytes to the server
///   as "JPEG" sends a raw grayscale Y buffer that PIL/OpenCV cannot decode —
///   this was the root-cause bug in the original code.
///
/// • **iOS** — [ImageFormatGroup.bgra8888] (single plane, 4 bytes per pixel).
///   Simpler to handle but still cannot be sent as-is to PIL.Image.open().
///
/// Solution
/// ─────────
/// Both paths are converted to a proper colour JPEG using the `image` package
/// (already a dependency).  The conversion runs inside a Dart [Isolate] so the
/// main thread (and therefore the camera preview UI) is never stalled.
///
/// Quality / size trade-off
/// ─────────────────────────
/// JPEG quality 80 gives a good balance: ~15–30 KB per 640×480 frame, fast to
/// encode, and easily decoded by PIL on the backend.  For OCR a higher-quality
/// crop can be extracted separately by the service layer.
class FrameConverter {
  // --------------------------------------------------------------------------
  // Public API
  // --------------------------------------------------------------------------

  /// Convert [image] to JPEG bytes.
  ///
  /// Returns `null` if the image format is unrecognised or conversion fails.
  /// Runs on the calling isolate by default; use [convertInBackground] for the
  /// non-blocking version.
  static Uint8List? convert(CameraImage image, {int jpegQuality = 80}) {
    try {
      if (image.planes.isEmpty) return null;

      final img.Image? decoded = _decodeToImage(image);
      if (decoded == null) return null;

      return img.encodeJpg(decoded, quality: jpegQuality);
    } catch (_) {
      return null;
    }
  }

  /// Convert [image] to JPEG bytes on a background [Isolate].
  ///
  /// Use this from the camera-image stream callback so the UI thread is never
  /// blocked by pixel manipulation.  Returns `null` on any failure.
  static Future<Uint8List?> convertInBackground(
    CameraImage image, {
    int jpegQuality = 80,
  }) async {
    // Package all the data the isolate needs into a plain map (no custom
    // objects that cannot cross isolate boundaries).
    final _IsolatePayload payload = _IsolatePayload(
      format: image.format.group,
      width: image.width,
      height: image.height,
      planes: image.planes
          .map(
            (p) => _PlaneData(
              bytes: Uint8List.fromList(p.bytes),
              bytesPerRow: p.bytesPerRow,
              bytesPerPixel: p.bytesPerPixel ?? 1,
            ),
          )
          .toList(),
      jpegQuality: jpegQuality,
    );

    final ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(
      _isolateConvert,
      _IsolateMessage(sendPort: receivePort.sendPort, payload: payload),
    );

    final result = await receivePort.first;
    return result as Uint8List?;
  }

  // --------------------------------------------------------------------------
  // Internal — conversion logic
  // --------------------------------------------------------------------------

  /// Entry point for the background isolate.
  static void _isolateConvert(_IsolateMessage message) {
    Uint8List? result;
    try {
      final img.Image? decoded = _decodePayload(message.payload);
      if (decoded != null) {
        result = img.encodeJpg(decoded, quality: message.payload.jpegQuality);
      }
    } catch (_) {
      result = null;
    }
    message.sendPort.send(result);
  }

  /// Dispatch to the correct decoder based on [CameraImage.format].
  static img.Image? _decodeToImage(CameraImage image) {
    switch (image.format.group) {
      case ImageFormatGroup.yuv420:
        return _yuv420ToImage(
          planes: image.planes,
          width: image.width,
          height: image.height,
        );
      case ImageFormatGroup.bgra8888:
        return _bgra8888ToImage(
          bytes: image.planes[0].bytes,
          width: image.width,
          height: image.height,
        );
      default:
        // Unknown format — attempt to treat as raw JPEG/PNG bytes (rare path).
        return img.decodeImage(image.planes[0].bytes);
    }
  }

  /// Same dispatch but operates on the serialisable [_IsolatePayload].
  static img.Image? _decodePayload(_IsolatePayload p) {
    switch (p.format) {
      case ImageFormatGroup.yuv420:
        return _yuv420ToImageFromPlanes(
          planes: p.planes,
          width: p.width,
          height: p.height,
        );
      case ImageFormatGroup.bgra8888:
        return _bgra8888ToImage(
          bytes: p.planes[0].bytes,
          width: p.width,
          height: p.height,
        );
      default:
        return img.decodeImage(p.planes[0].bytes);
    }
  }

  // --------------------------------------------------------------------------
  // YUV420 conversion
  // --------------------------------------------------------------------------
  //
  // YUV420 layout (Android camera2):
  //
  //   Plane 0 — Y  (luma)       : width × height bytes, 1 byte/pixel
  //   Plane 1 — U  (Cb, chroma) : (width/2) × (height/2), bytesPerPixel = 2
  //   Plane 2 — V  (Cr, chroma) : same size/stride as plane 1
  //
  // Most Android HALs deliver NV12 (interleaved UV, plane 1 = U0 V0 U1 V1 …)
  // or NV21 (interleaved VU, plane 2 = V0 U0 V1 U1 …) with bytesPerRow and
  // bytesPerPixel reflecting the interleaving.  We iterate each output pixel
  // and reconstruct RGB using the standard BT.601 integer approximation.

  static img.Image _yuv420ToImage({
    required List<Plane> planes,
    required int width,
    required int height,
  }) {
    final yPlane = planes[0].bytes;
    final uPlane = planes[1].bytes;
    final vPlane = planes[2].bytes;
    final int uvRowStride = planes[1].bytesPerRow;
    final int uvPixelStride = planes[1].bytesPerPixel ?? 2;

    return _buildRgbImage(
      yBytes: yPlane,
      uBytes: uPlane,
      vBytes: vPlane,
      uvRowStride: uvRowStride,
      uvPixelStride: uvPixelStride,
      width: width,
      height: height,
    );
  }

  static img.Image _yuv420ToImageFromPlanes({
    required List<_PlaneData> planes,
    required int width,
    required int height,
  }) {
    return _buildRgbImage(
      yBytes: planes[0].bytes,
      uBytes: planes[1].bytes,
      vBytes: planes[2].bytes,
      uvRowStride: planes[1].bytesPerRow,
      uvPixelStride: planes[1].bytesPerPixel,
      width: width,
      height: height,
    );
  }

  static img.Image _buildRgbImage({
    required Uint8List yBytes,
    required Uint8List uBytes,
    required Uint8List vBytes,
    required int uvRowStride,
    required int uvPixelStride,
    required int width,
    required int height,
  }) {
    final image = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // Luma
        final int yVal = yBytes[y * width + x] & 0xFF;

        // Chroma — shared by 2×2 luma block
        final int uvIndex = (y >> 1) * uvRowStride + (x >> 1) * uvPixelStride;

        // Guard against out-of-bounds on unusual HAL implementations.
        if (uvIndex >= uBytes.length || uvIndex >= vBytes.length) {
          image.setPixelRgb(x, y, yVal, yVal, yVal);
          continue;
        }

        final int uVal = uBytes[uvIndex] & 0xFF;
        final int vVal = vBytes[uvIndex] & 0xFF;

        // BT.601 full-range conversion (integer approximation).
        final int r = (yVal + (1.370705 * (vVal - 128))).clamp(0, 255).toInt();
        final int g = (yVal - (0.337633 * (uVal - 128)) - (0.698001 * (vVal - 128)))
            .clamp(0, 255)
            .toInt();
        final int b = (yVal + (1.732446 * (uVal - 128))).clamp(0, 255).toInt();

        image.setPixelRgb(x, y, r, g, b);
      }
    }

    return image;
  }

  // --------------------------------------------------------------------------
  // BGRA8888 conversion (iOS)
  // --------------------------------------------------------------------------

  static img.Image _bgra8888ToImage({
    required Uint8List bytes,
    required int width,
    required int height,
  }) {
    // The `image` package's fromBytes constructor expects RGBA ordering.
    // BGRA → RGBA: swap B and R channels in-place on a copy.
    final rgba = Uint8List(bytes.length);
    for (int i = 0; i < bytes.length; i += 4) {
      rgba[i] = bytes[i + 2]; // R ← B
      rgba[i + 1] = bytes[i + 1]; // G ← G
      rgba[i + 2] = bytes[i]; // B ← R
      rgba[i + 3] = bytes[i + 3]; // A ← A
    }
    return img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,
      format: img.Format.uint8,
      numChannels: 4,
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Private data-transfer objects (must be trivially serialisable for Isolate)
// ────────────────────────────────────────────────────────────────────────────

class _PlaneData {
  final Uint8List bytes;
  final int bytesPerRow;
  final int bytesPerPixel;

  const _PlaneData({
    required this.bytes,
    required this.bytesPerRow,
    required this.bytesPerPixel,
  });
}

class _IsolatePayload {
  final ImageFormatGroup format;
  final int width;
  final int height;
  final List<_PlaneData> planes;
  final int jpegQuality;

  const _IsolatePayload({
    required this.format,
    required this.width,
    required this.height,
    required this.planes,
    required this.jpegQuality,
  });
}

class _IsolateMessage {
  final SendPort sendPort;
  final _IsolatePayload payload;

  const _IsolateMessage({required this.sendPort, required this.payload});
}
