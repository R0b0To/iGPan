import 'dart:convert';
import 'package:flutter/material.dart'; // Keep if used by fireUpData/raceData, otherwise remove

// Consider moving fireUpData and raceData to a more specific model if they have a defined structure
// For now, keeping them as Map<String, dynamic>

class Account {
  final String email;
  final String password;
  final String? nickname;
  bool enabled; // Add enabled field

  Map<String, dynamic>? fireUpData; // To store fireUp response data
  Map<String, dynamic>? raceData; // To store race data

  Account({
    required this.email,
    required this.password,
    this.nickname,
    this.fireUpData,
    this.raceData,
    this.enabled = true, // Initialize enabled to true
  });

  // Factory constructor to create an Account from a JSON map
  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      email: json['email'],
      password: json['password'],
      nickname: json['nickname'],
      fireUpData: null, // fireUpData is not stored in JSON
      raceData: null,   // raceData is not stored in JSON
      enabled: json['enabled'] ?? true, // Load enabled state, default to true if not present
    );
  }

  // Method to convert an Account object to a JSON map for storage
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'nickname': nickname,
      // fireUpData and raceData are runtime data, not typically stored with account credentials
      'enabled': enabled, // Include enabled state in JSON
    };
  }
}