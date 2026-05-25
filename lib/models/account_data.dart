import '../models/driver_data.dart';
import '../services/driver_service.dart';
/// Live game data for one account, parsed from the fireUp endpoint.
/// Owned by the account's Riverpod family slot — refreshed on demand.
class AccountData {
  // ─── Identity ─────────────────────────────────────────────
  final String  userId;
  final bool    isGuest;
 
  // ─── Manager ──────────────────────────────────────────────
  final String  managerName;
  final int     managerLevel;
  final int     tokens;
  final int     reputation;       // "rep" field
  final String  currency;         // "$", "€", etc.
  // ─── Drivers ──────────────────────────────────────────────
  final List<DriverData> drivers;
  // ─── Team ─────────────────────────────────────────────────
  final String  teamId;
  final String  teamName;
  final String  teamColor;        // hex without #
  final int     balance;          // _balance as int
  final String  leagueId;
  final int     tier;
  final int     racesDone;
  final int     numDrivers;
  final int     numCars;       // 1 or 2 — from team._numCars
 
  // ─── Next race ────────────────────────────────────────────
  final String?   nextRaceId;
  final DateTime? nextRaceTime;
  final int?      nextRaceNumber;
 
  const AccountData({
    required this.userId,
    required this.isGuest,
    required this.managerName,
    required this.managerLevel,
    required this.tokens,
    required this.reputation,
    required this.currency,
    required this.teamId,
    required this.teamName,
    required this.teamColor,
    required this.balance,
    required this.leagueId,
    required this.tier,
    required this.racesDone,
    required this.numDrivers,
    required this.numCars,
    required this.drivers,
    this.nextRaceId,
    this.nextRaceTime,
    this.nextRaceNumber,
  });
 
  /// Parse directly from the fireUp JSON response.
  factory AccountData.fromFireUp(Map<String, dynamic> json) {
    final team    = json['team']    as Map<String, dynamic>? ?? {};
    final manager = json['manager'] as Map<String, dynamic>? ?? {};
   
        
 
    // Next race timestamp (Unix seconds → DateTime)
    final nextRaceTs = int.tryParse(
      team['_nextLeagueRaceTime']?.toString() ?? '',
    );
 
    return AccountData(
      userId:        json['user']?.toString()               ?? '',
      isGuest:       json['guestAccount'] as bool?          ?? true,
      managerName:   '${manager['fName'] ?? ''} ${manager['lName'] ?? ''}'.trim(),
      managerLevel:  _toInt(manager['level']),
      tokens:        _toInt(manager['tokens']),
      reputation:    _toInt(manager['rep']),
      currency:      manager['currency']?.toString()        ?? '\$',
      teamId:        team['_id']?.toString()                ?? '',
      teamName:      team['_name']?.toString()              ?? '',
      teamColor:     team['color']?.toString()              ?? '000000',
      balance:       _toInt(team['_balance']),
      leagueId:      team['_league']?.toString()            ?? '',
      tier:          _toInt(team['_tier']),
      racesDone:     _toInt(team['_racesDone']),
      drivers:       DriverService.parseFromFireUp(json),
      numDrivers:    _toInt(team['_drivers']),
      numCars:       _toInt(team['_numCars']),
      nextRaceId:    team['_nextLeagueRace']?.toString(),
      nextRaceTime:  nextRaceTs != null
          ? DateTime.fromMillisecondsSinceEpoch(nextRaceTs * 1000)
          : null,
      nextRaceNumber: int.tryParse(
        team['_nextLeagueRaceNum']?.toString() ?? '',
      ),
    );
  }
 
  static int _toInt(dynamic v) =>
      v == null ? 0 : int.tryParse(v.toString()) ?? 0;
 
  /// Formatted balance string using the account's currency symbol.
  String get formattedBalance {
    if (balance >= 1000000) {
      return '$currency${(balance / 1000000).toStringAsFixed(1)}m';
    }
    if (balance >= 1000) {
      return '$currency${(balance / 1000).toStringAsFixed(0)}k';
    }
    return '$currency$balance';
  }
 
  /// True if the next race is within the next hour.
  bool get raceImminent {
    if (nextRaceTime == null) return false;
    return nextRaceTime!.difference(DateTime.now()).inHours < 1;
  }
 
  @override
  String toString() =>
      'AccountData($teamName, L$managerLevel, $formattedBalance)';
}