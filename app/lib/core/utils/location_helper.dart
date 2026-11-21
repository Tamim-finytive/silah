class LocationHelper {
  /// Extracts latitude and longitude from a Google Maps URL, short link, or raw coordinate string.
  static Map<String, double>? extractLatLng(String input) {
    if (input.trim().isEmpty) return null;
    final str = input.trim();

    // Pattern 1: @13.060422,80.249583
    final atPattern = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
    final atMatch = atPattern.firstMatch(str);
    if (atMatch != null) {
      final lat = double.tryParse(atMatch.group(1)!);
      final lng = double.tryParse(atMatch.group(2)!);
      if (lat != null && lng != null) return {'lat': lat, 'lng': lng};
    }

    // Pattern 2: q=13.0827,80.2707 or query=13.0827,80.2707 or ll=13.0827,80.2707
    final qPattern = RegExp(r'(?:q|query|ll)=(-?\d+\.\d+)(?:%2C|,)(-?\d+\.\d+)');
    final qMatch = qPattern.firstMatch(str);
    if (qMatch != null) {
      final lat = double.tryParse(qMatch.group(1)!);
      final lng = double.tryParse(qMatch.group(2)!);
      if (lat != null && lng != null) return {'lat': lat, 'lng': lng};
    }

    // Pattern 3: raw "13.0827, 80.2707" or "13.0827,80.2707"
    final rawPattern = RegExp(r'^(-?\d{1,2}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)$');
    final rawMatch = rawPattern.firstMatch(str);
    if (rawMatch != null) {
      final lat = double.tryParse(rawMatch.group(1)!);
      final lng = double.tryParse(rawMatch.group(2)!);
      if (lat != null && lng != null) return {'lat': lat, 'lng': lng};
    }

    // Pattern 4: any two decimal coordinates in string
    final genPattern = RegExp(r'(-?\d{1,2}\.\d{3,10})\s*,\s*(-?\d{1,3}\.\d{3,10})');
    final genMatch = genPattern.firstMatch(str);
    if (genMatch != null) {
      final lat = double.tryParse(genMatch.group(1)!);
      final lng = double.tryParse(genMatch.group(2)!);
      if (lat != null && lng != null) return {'lat': lat, 'lng': lng};
    }

    return null;
  }
}
