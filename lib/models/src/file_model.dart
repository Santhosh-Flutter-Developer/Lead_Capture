/// Parses numeric fields from Firestore (int, double, or string).
int? parseFirestoreInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

class FileModel {
  final String name;
  final String url;
  final int size;
  final String extension;
  final String mimeType;
  final DateTime? createdAt;

  /// True for WhatsApp-style voice notes recorded in the chat composer.
  /// Older messages don't have this field and default to false.
  final bool isVoice;

  /// Length of a voice note in milliseconds (0 when unknown).
  final int durationMs;

  /// Downsampled loudness bars (0-100) used to draw the voice-note waveform.
  final List<int> waveform;

  FileModel({
    required this.name,
    required this.url,
    required this.size,
    required this.extension,
    required this.mimeType,
    this.createdAt,
    this.isVoice = false,
    this.durationMs = 0,
    this.waveform = const [],
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'url': url,
      'size': size,
      'extension': extension,
      'mimeType': mimeType,
      "createdAt": createdAt?.millisecondsSinceEpoch,
      if (isVoice) 'isVoice': true,
      if (durationMs > 0) 'durationMs': durationMs,
      if (waveform.isNotEmpty) 'waveform': waveform,
    };
  }

  factory FileModel.fromMap(Map<String, dynamic> map) {
    return FileModel(
      name: map['name'] != null && map['name'] is String ? map['name'] : '',
      url: map['url'] != null && map['url'] is String ? map['url'] : '',
      size: parseFirestoreInt(map['size']) ?? 0,
      extension: map['extension'] != null && map['extension'] is String
          ? map['extension']
          : '',
      mimeType: map['mimeType'] != null && map['mimeType'] is String
          ? map['mimeType']
          : '',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : null,
      isVoice: map['isVoice'] == true,
      durationMs: parseFirestoreInt(map['durationMs']) ?? 0,
      waveform: map['waveform'] is List
          ? (map['waveform'] as List)
                .map((e) => e is num ? e.toInt() : 0)
                .toList()
          : const [],
    );
  }
}
