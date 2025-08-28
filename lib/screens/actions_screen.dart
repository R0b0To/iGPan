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
  Future<void> _showLoadingDialog(String text) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text(text),
            ],
          ),
        );
      },
    );
  }

  void _hideLoadingDialog() {
    Navigator.of(context).pop();
  }

  Future<void> _runWithLoadingDialog(
      String message, Future<void> Function() action) async {
    _showLoadingDialog(message);
    try {
      await action();
    } finally {
      _hideLoadingDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () {
              _claimDailyReward();
            },
            child: const Text('1| Claim Daily Reward for Enabled Accounts'),
          ),
          const SizedBox(height: 5), // Add some space
          ElevatedButton(
            onPressed: () {
              _performCarSetup();
            },
            child: const Text('2| Perform Car Setup for Enabled Accounts'),
          ),
          const SizedBox(height: 5), // Add some space
          ElevatedButton(
            onPressed: () async {
              await _repairAllCars();
            },
            child: const Text('3| Repair All Cars for Enabled Accounts'),
          ),
          const SizedBox(height: 5), // Add some space
          ElevatedButton(
            onPressed: () async {
              await _setDefaultStrategy();
            },
            child: const Text('4| Set default strategy for Enabled Accounts'),
          ),
          const SizedBox(height: 5), // Add some space
          Tooltip(
            message:
                'Fills the smallest gap by priority, then picks the attribute with the highest research gain.',
            child: ElevatedButton(
              onPressed: () async {
                await _distributeResearchPoints();
              },
              child: const Text(
                  '5| Distribute Research Points for Enabled Accounts'),
            ),
          ),
          const SizedBox(height: 5), // Add some space
          ElevatedButton(
            onPressed: () {
              _saveStrategy();
            },
            child: const Text('6| Save Strategy for Enabled Accounts'),
          ),
          const SizedBox(height: 30), // Add some space
          ElevatedButton(
            onPressed: () async {
              await _executeAllActions();
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(200, 80), // Make the button big
              textStyle: const TextStyle(fontSize: 20), // Make the text big
            ),
            child: const Text('Execute All Actions'),
          ),
        ],
      ),
    );
  }

  Future<void> _claimDailyReward() async {
    for (var account in accountsNotifier.value) {
      if (account.enabled) {
        account.claimDailyReward();
      }
    }
    accountsNotifier.value = List.from(accountsNotifier.value);
  }

  Future<void> _performCarSetup() async {
    for (var account in accountsNotifier.value) {
      if (account.enabled) {
        final fireUpData = account.fireUpData;
        if (fireUpData != null) {
          final drivers = fireUpData['drivers'];
          final team = fireUpData['team'];
          final raceData = account.raceData;

          if (drivers != null && team != null && raceData != null) {
            for (int carIndex = 0;
                carIndex < drivers.length && carIndex < 2;
                carIndex++) {
              final driverAttributes = drivers[carIndex]?.attributes;
              final tier = team['_tier'];
              final raceNameHtml = raceData['vars']['raceName'];

              if (driverAttributes != null &&
                  driverAttributes.length > 13 &&
                  tier != null &&
                  raceNameHtml != null) {
                final double height = driverAttributes[13];
                final int tierValue = int.tryParse(tier) ?? 1;

                final CarSetup carSetup = CarSetup(
                    account.raceData?['vars']['trackId'], height, tierValue);
                final int suggestedRide = carSetup.ride;
                final int suggestedWing = carSetup.wing;
                final int suggestedSuspension = carSetup.suspension + 1;

                String suspensionKey = 'd${carIndex + 1}Suspension';
                String rideHeightKey = 'd${carIndex + 1}Ride';
                String aerodynamicsKey = 'd${carIndex + 1}Aerodynamics';
                account.raceData?['vars']?[suspensionKey] =
                    suggestedSuspension.toString();
                account.raceData?['vars']?[rideHeightKey] = suggestedRide;
                account.raceData?['vars']?[aerodynamicsKey] = suggestedWing;

                print('Performed car setup for account: ${account.email}');
              }
            }
          }
        }
      }
    }
  }

  Future<void> _repairAllCars() async {
    for (var account in accountsNotifier.value) {
      if (account.enabled) {
        final numCarsString = account.fireUpData?['team']?['_numCars'];
        final numCars = numCarsString is int
            ? numCarsString
            : (int.tryParse(numCarsString ?? '1') ?? 1);

        for (int i = 1; i <= numCars; i++) {
          await account.repairCar(i, 'parts');
          await account.repairCar(i, 'engine');
        }
      }
    }
    accountsNotifier.value = List.from(accountsNotifier.value);
  }

  Future<void> _setDefaultStrategyInternal() async {
    for (var account in accountsNotifier.value) {
      if (account.enabled) {
        await account.setDefaultStrategy();
      }
    }
    accountsNotifier.value = List.from(accountsNotifier.value);
  }

  Future<void> _setDefaultStrategy() async {
    await _runWithLoadingDialog(
        "Setting default strategy...", _setDefaultStrategyInternal);
  }

  Future<void> _distributeResearchPoints() async {
    for (var account in accountsNotifier.value) {
      if (account.enabled) {
        final researchData = await account.requestResearch();
        if (researchData != null) {
          List<int> myCarValues = List<int>.from(researchData['myCar']);
          List<int> bestCarAttributes = List<int>.from(researchData['best']);
          int remainingDesignPoints = researchData['points'] as int;
          double originalMaxResearch = researchData['maxResearch'] as double;

          List<String> attributeNames = [
            'acceleration',
            'braking',
            'cooling',
            'downforce',
            'fuel_economy',
            'handling',
            'reliability',
            'tyre_economy'
          ];

          List<int> priorityOrder = [0, 1, 3, 5, 4, 7];

          int? bestAttributeIndex;
          int smallestGap = 999999;

          for (int i in [0, 1, 3, 5]) {
            final gap = bestCarAttributes[i] - myCarValues[i];
            if (gap > 0) {
              if (gap < smallestGap) {
                smallestGap = gap;
                bestAttributeIndex = i;
              }
            }
          }

          if (bestAttributeIndex == null) {
            for (int i in [4, 7]) {
              final gap = bestCarAttributes[i] - myCarValues[i];
              if (gap >= 0) {
                if (gap < smallestGap) {
                  smallestGap = gap;
                  bestAttributeIndex = i;
                }
              }
            }
          }

          if (bestAttributeIndex == null) {
            if (bestCarAttributes[4] - myCarValues[4] == 0) {
              bestAttributeIndex = 4;
            } else if (bestCarAttributes[7] - myCarValues[7] == 0) {
              bestAttributeIndex = 7;
            }
          }

          if (bestAttributeIndex != null) {
            final maxDp = researchData['maxDp'] as int;
            List<Map<String, int>> gaps = [];
            for (int i in priorityOrder) {
              final gap = bestCarAttributes[i] - myCarValues[i];
              if (gap > 0) {
                gaps.add({'index': i, 'gap': gap});
              }
            }
            gaps.sort((a, b) => a['gap']!.compareTo(b['gap']!));

            for (var gapInfo in gaps) {
              if (remainingDesignPoints <= 0) break;

              final index = gapInfo['index']!;
              final gap = gapInfo['gap']!;
              final pointsToAdd =
                  gap < remainingDesignPoints ? gap : remainingDesignPoints;

              if (myCarValues[index] + pointsToAdd > maxDp) {
                final maxPointsToAdd = maxDp - myCarValues[index];
                myCarValues[index] += maxPointsToAdd;
                remainingDesignPoints -= maxPointsToAdd;
              } else {
                myCarValues[index] += pointsToAdd;
                remainingDesignPoints -= pointsToAdd;
              }
            }

            final Map<String, dynamic> researchSettings = {
              'maxDp': originalMaxResearch.toInt(),
              'attributes': <String>[],
            };

            int? largestGapAttributeIndex;
            int currentLargestGap = -1;

            for (int i in priorityOrder) {
              if (i == 2 || i == 6) continue;

              final currentGap = bestCarAttributes[i] - myCarValues[i];
              if (currentGap > currentLargestGap) {
                currentLargestGap = currentGap;
                largestGapAttributeIndex = i;
              }
            }

            if (largestGapAttributeIndex != null) {
              researchSettings['attributes']
                  .add(attributeNames[largestGapAttributeIndex]);
            }

            List<String> designList = [];
            for (int i = 0; i < attributeNames.length; i++) {
              designList.add('&${attributeNames[i]}=${myCarValues[i]}');
            }

            await account.saveDesign(researchSettings, designList);
          } else {
            // Handle case where no suitable attribute is found
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Failed to fetch research data for ${account.email}')),
          );
        }
      }
    }
    accountsNotifier.value = List.from(accountsNotifier.value);
  }

  Future<void> _saveStrategy() async {
    for (var account in accountsNotifier.value) {
      if (account.enabled) {
        account.saveStrategy();
      }
    }
    accountsNotifier.value = List.from(accountsNotifier.value);
  }

  Future<void> _executeAllActions() async {
    await _runWithLoadingDialog("Executing all actions...", () async {
      await _claimDailyReward();
      await _performCarSetup();
      await _repairAllCars();
      await _setDefaultStrategyInternal(); // Call internal to avoid nested dialogs
      await _distributeResearchPoints();
      await _saveStrategy();
    });
  }
}