import 'package:flutter/foundation.dart';
import '../models/driver_data.dart';
 
/// Extracts driver data from the fireUp preCache response.
///
/// The fireUp response contains a preCache map with a 'p=staff' entry.
/// That entry has vars.drivers which is an HTML string containing
/// data-driver attributes with comma-separated skill values.
class DriverService {
  /// Parse drivers from the full fireUp JSON response.
  ///
  /// Path: json['preCache']['p=staff']['vars']['drivers']
  static List<DriverData> parseFromFireUp(Map<String, dynamic> fireUpJson) {
    try {
      final preCache = fireUpJson['preCache'] as Map<String, dynamic>?;
      if (preCache == null) return [];
 
      final staff = preCache['p=staff'] as Map<String, dynamic>?;
      if (staff == null) return [];
 
      final vars = staff['vars'] as Map<String, dynamic>?;
      if (vars == null) return [];
 
      final driversHtml = vars['drivers']?.toString() ?? '';
      if (driversHtml.isEmpty) return [];
 
      final drivers = DriverData.parseFromStaffHtml(driversHtml);
      debugPrint('[DriverService] Parsed ${drivers.length} driver(s): '
          '${drivers.map((d) => '${d.fullName} H:${d.heightCm}cm').join(', ')}');
      return drivers;
    } catch (e) {
      debugPrint('[DriverService] Error parsing drivers: $e');
      return [];
    }
  }
}