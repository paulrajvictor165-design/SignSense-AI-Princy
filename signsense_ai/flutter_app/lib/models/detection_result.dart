/// SignSense AI — Detection Result Model
///
/// Module 3 additions (backward-compatible)
/// -----------------------------------------
/// New optional fields added to carry the AI Pipeline metadata returned by the
/// backend since Module 3:
///
///   priority         — int (1–4): 1=Critical, 2=High, 3=Normal, 4=Low.
///                      Drives voice announcement ordering and bounding-box
///                      colour in [DetectionOverlay].
///   processingTimeMs — int: wall-clock inference time from the backend.
///   lowConfidence    — bool: true when pipeline_confidence < tier threshold.
///                      Screens use this to display a rescan prompt.
///
/// All new fields are optional with safe defaults so existing code that
/// constructs [DetectionResult] without them continues to compile unchanged.
/// [DetectionResult.fromJson] reads them from the backend JSON if present.
class DetectionResult {
  final String label;
  final double confidence;
  final String position; // "left", "right", "ahead", "center"
  final BoundingBox? bbox;
  final String category; // "object", "traffic", "vehicle", "face", etc.

  // ── Module 3 additions ────────────────────────────────────────────────────
  /// Priority tier: 1=Critical, 2=High, 3=Normal, 4=Low.
  /// Defaults to 3 (Normal) for backward compatibility.
  final int priority;

  /// Wall-clock inference time in milliseconds (from backend).
  /// Defaults to 0 when not provided by an older backend response.
  final int processingTimeMs;

  /// True when the backend flagged this result as low-confidence.
  /// Screens should show a "try again" prompt when this is true.
  final bool lowConfidence;

  const DetectionResult({
    required this.label,
    required this.confidence,
    required this.position,
    this.bbox,
    this.category = 'object',
    // Module 3 fields — optional, safe defaults for backward compatibility.
    this.priority = 3,
    this.processingTimeMs = 0,
    this.lowConfidence = false,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      label:           json['label']    as String? ?? 'Unknown',
      confidence:      (json['confidence'] as num?)?.toDouble() ?? 0.0,
      position:        json['position'] as String? ?? 'ahead',
      category:        json['category'] as String? ?? 'object',
      bbox: json['bbox'] != null
          ? BoundingBox.fromJson(json['bbox'] as Map<String, dynamic>)
          : null,
      // Module 3 fields — read if present, default otherwise.
      priority:         json['priority']          as int?  ?? 3,
      processingTimeMs: json['processing_time_ms'] as int?  ?? 0,
      lowConfidence:    json['low_confidence']     as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'label':             label,
        'confidence':        confidence,
        'position':          position,
        'category':          category,
        'bbox':              bbox?.toJson(),
        'priority':          priority,
        'processing_time_ms': processingTimeMs,
        'low_confidence':    lowConfidence,
      };

  // ── Derived helpers ───────────────────────────────────────────────────────

  /// True when this detection is safety-critical (vehicles, traffic signals).
  bool get isCritical => priority == 1;

  /// True when this detection is a navigation hazard (doors, people, stairs).
  bool get isHighPriority => priority == 2;

  /// Generate accessibility voice message for this detection.
  ///
  /// Module 3: Critical objects are prefixed with "Warning!" and
  /// high-priority objects with "Caution!" to match the backend's
  /// [build_priority_voice_message] output.
  String get voiceMessage {
    final String prefix = isCritical
        ? 'Warning! '
        : isHighPriority
            ? 'Caution! '
            : '';

    switch (position) {
      case 'left':
        return '${prefix}$label on your left.';
      case 'right':
        return '${prefix}$label on your right.';
      case 'ahead':
        return '${prefix}$label ahead.';
      case 'close':
        return 'Warning! $label very close.';
      default:
        return '${prefix}$label detected.';
    }
  }
}

class BoundingBox {
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  const BoundingBox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      x1: (json['x1'] as num).toDouble(),
      y1: (json['y1'] as num).toDouble(),
      x2: (json['x2'] as num).toDouble(),
      y2: (json['y2'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'x1': x1,
        'y1': y1,
        'x2': x2,
        'y2': y2,
      };

  double get width  => x2 - x1;
  double get height => y2 - y1;
  double get centerX => (x1 + x2) / 2;
  double get centerY => (y1 + y2) / 2;
}
