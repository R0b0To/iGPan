
/// Circuit base setups and height-based ride adjustment.
///
/// ride    = base.ride + heightAdjustment(driverHeight)
/// wing    = base.wing   (clamped 1-100)
/// suspension = base.suspension (clamped 1-100)
class SetupSuggestion {
  /// Compute a suggested setup for a given track flag code and driver height.
  ///
  /// [trackFlagCode] — 2-letter country code from the race track flag image,
  ///   e.g. "fr", "gb", "au". Extracted from raceName flag HTML.
  /// [driverHeightCm] — from DriverData.heightCm.
  /// [overrides] — optional per-account override for this track.
  static SuggestedSetup? forTrack(
    String trackFlagCode,
    int    driverHeightCm, {
    CircuitSetup? overrides,
  }) {
    final base = overrides ?? _circuits[trackFlagCode.toLowerCase()];
    if (base == null) return null;
 
    final adj  = heightAdjustment(driverHeightCm);
    final ride = (base.ride + adj).clamp(1, 100);
    final wing = base.wing.clamp(1, 100);
    final susp = base.suspension.clamp(1, 100);
 
    return SuggestedSetup(
      ride:       ride,
      wing:       wing,
      suspension: susp,
      trackCode:  trackFlagCode,
    );
  }
 
  static int heightAdjustment(int heightCm) {
    // Scale: height → ride adjustment
    // Taller driver → lower ride (negative adj), shorter → higher ride
    const scale = {
      190: -8,
      185: -6,
      180: -4,
      175: -2,
      170:  0,
      165:  2,
    };
    // Find the highest key that is <= driverHeight
    final keys = scale.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final k in keys) {
      if (heightCm >= k) return scale[k]!;
    }
    return scale[keys.last]!; // shortest bucket
  }
 
  // ─── All circuit base setups ───────────────────────────────
  static const Map<String, CircuitSetup> _circuits = {
    'ae': CircuitSetup(ride: 25, wing:   5, suspension: 60), // Abu Dhabi
    'at': CircuitSetup(ride: 18, wing:   0, suspension: 70), // Austria
    'au': CircuitSetup(ride: 38, wing:  15, suspension: 40), // Australia
    'az': CircuitSetup(ride: 33, wing:   5, suspension: 60), // Azerbaijan
    'be': CircuitSetup(ride: 23, wing:  12, suspension: 45), // Belgium
    'bh': CircuitSetup(ride: 15, wing:   0, suspension: 70), // Bahrain
    'br': CircuitSetup(ride: 15, wing:  10, suspension: 50), // Brazil
    'ca': CircuitSetup(ride: 18, wing:  -5, suspension: 80), // Canada
    'cn': CircuitSetup(ride: 10, wing:  10, suspension: 50), // China
    'de': CircuitSetup(ride: 15, wing:  10, suspension: 50), // Germany
    'es': CircuitSetup(ride: 10, wing:  20, suspension: 30), // Spain
    'eu': CircuitSetup(ride: 23, wing:  20, suspension: 30), // Europe
    'fr': CircuitSetup(ride: 33, wing:  10, suspension: 50), // France
    'gb': CircuitSetup(ride: 18, wing:   0, suspension: 70), // Great Britain
    'hu': CircuitSetup(ride: 20, wing:  25, suspension: 20), // Hungary
    'it': CircuitSetup(ride: 23, wing: -10, suspension: 90), // Italy
    'jp': CircuitSetup(ride: 23, wing:  20, suspension: 30), // Japan
    'mc': CircuitSetup(ride: 43, wing:  35, suspension:  1), // Monaco
    'mx': CircuitSetup(ride: 13, wing:  10, suspension: 50), // Mexico
    'my': CircuitSetup(ride: 23, wing:   5, suspension: 60), // Malaysia
    'ru': CircuitSetup(ride:  8, wing:  10, suspension: 50), // Russia
    'sg': CircuitSetup(ride: 33, wing:  27, suspension: 15), // Singapore
    'tr': CircuitSetup(ride: 25, wing:  10, suspension: 50), // Turkey
    'us': CircuitSetup(ride:  8, wing:   7, suspension: 55), // USA
    'nl': CircuitSetup(ride: 25, wing:   5, suspension: 50), // Netherlands
  };
 
  /// Returns a copy of the defaults map merged with any per-account overrides.
  static Map<String, CircuitSetup> allCircuits({
    Map<String, CircuitSetup>? accountOverrides,
  }) {
    if (accountOverrides == null || accountOverrides.isEmpty) {
      return Map.unmodifiable(_circuits);
    }
    return {..._circuits, ...accountOverrides};
  }
 
  /// All known track codes.
  static List<String> get allCodes => _circuits.keys.toList()..sort();
}
 
/// Base setup values for one circuit.
class CircuitSetup {
  final int ride;
  final int wing;
  final int suspension;

 
  const CircuitSetup({
    required this.ride,
    required this.wing,
    required this.suspension,
  });
 
  CircuitSetup copyWith({int? ride, int? wing, int? suspension,}) =>
      CircuitSetup(
        ride:       ride       ?? this.ride,
        wing:       wing       ?? this.wing,
        suspension: suspension ?? this.suspension,
      );
 
  factory CircuitSetup.fromJson(Map<String, dynamic> j) => CircuitSetup(
    ride:       j['ride']       as int? ?? 50,
    wing:       j['wing']       as int? ?? 50,
    suspension: j['suspension'] as int? ?? 50
  );
 
  Map<String, dynamic> toJson() => {
    'ride':       ride,
    'wing':       wing,
    'suspension': suspension,
  };
}
 
/// The computed setup suggestion for one driver at one track.
class SuggestedSetup {
  final int    ride;
  final int    wing;
  final int    suspension;
  final String trackCode;
 
  const SuggestedSetup({
    required this.ride,
    required this.wing,
    required this.suspension,
    required this.trackCode,
  });
}