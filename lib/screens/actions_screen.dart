import 'package:flutter/material.dart';
import '../main.dart'; // Import accountsNotifier
import '../utils/helpers.dart'; // Import CarSetup
import '../models/account.dart'; // Import Account class

class ActionsScreen extends StatefulWidget {
  const ActionsScreen({super.key});

  @override
  State<ActionsScreen> createState() => _ActionsScreenState();
}

class _ActionsScreenState extends State<ActionsScreen> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () {
              // Iterate through accounts and call claimDailyReward for enabled ones
              for (var account in accountsNotifier.value) {
                if (account.enabled) {
                  account.claimDailyReward();
                }
              }
              // Notify listeners that the accounts list might have been updated (e.g., nDailyReward removed)
              accountsNotifier.value = List.from(accountsNotifier.value);
            },
            child: const Text('Claim Daily Reward for Enabled Accounts'),
          ),
          ElevatedButton(
            onPressed: () {
              // Iterate through accounts and perform car setup for enabled ones
              for (var account in accountsNotifier.value) {
                if (account.enabled) {
                  final fireUpData = account.fireUpData;
                  if (fireUpData != null) {
                    final drivers = fireUpData['drivers'];
                    final team = fireUpData['team'];
                    final raceData = account.raceData;

                    if (drivers != null && team != null && raceData != null) {
                      // Assuming carIndex 0 for simplicity, modify if needed
                      const int carIndex = 0;
                      if (carIndex < drivers.length) {
                        final driverAttributes = drivers[carIndex]?.attributes;
                        final tier = team['_tier'];
                        final raceNameHtml = raceData['vars']['raceName'];

                        if (driverAttributes != null && driverAttributes.length > 13 && tier != null && raceNameHtml != null) {
                          final double height = driverAttributes[13];
                          final int tierValue = int.tryParse(tier) ?? 1;

                          // Assuming CarSetup class is accessible
                          final CarSetup carSetup = CarSetup(account.raceData?['vars']['trackId'], height, tierValue);
                          final int suggestedRide = carSetup.ride;
                          final int suggestedWing = carSetup.wing;
                          final int suggestedSuspension = carSetup.suspension + 1;

                          // Update the underlying raceData as well
                          String suspensionKey = 'd${carIndex + 1}Suspension';
                          String rideHeightKey = 'd${carIndex + 1}Ride';
                          String aerodynamicsKey = 'd${carIndex + 1}Aerodynamics';
                          account.raceData?['vars']?[suspensionKey] = suggestedSuspension.toString(); // Store as string '1', '2', '3'
                          account.raceData?['vars']?[rideHeightKey] = suggestedRide;
                          account.raceData?['vars']?[aerodynamicsKey] = suggestedWing;
                       
                          print('Performed car setup for account: ${account.email}');
                        }
                      }
                    }
                  }
                }
              }
              // Notify listeners that the accounts list (specifically raceData within accounts) has been updated
              
            },
            child: const Text('Perform Car Setup for Enabled Accounts'),
          ),
                    ElevatedButton(
            onPressed: () {
              // Iterate through accounts and call claimDailyReward for enabled ones
              for (var account in accountsNotifier.value) {
                if (account.enabled) {
                  account.saveStrategy();
                }
              }
              // Notify listeners that the accounts list might have been updated (e.g., nDailyReward removed)
              accountsNotifier.value = List.from(accountsNotifier.value);
            },
            child: const Text('Save Strategy for Enabled Accounts'),
          ),
        ],
      ),
    );
  }
}