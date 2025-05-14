// Export Models
export 'models/account.dart';
export 'models/driver.dart';

// Export Core API Client functionalities and global variables
export 'services/api_client_core.dart' 
    show 
        accounts, // Global list of accounts
        cookieJars, // Global map of cookie jars
        appDocumentPath, // Global app document path
        initializeAppDocumentPath, // Function to initialize the path
        loadAccounts, // Function to load accounts from storage
        saveAccounts, // Function to save accounts to storage
        startClientSessionForAccount, // Function to start/validate a session
        login; // Function for full login




// Export specific utility/parser functions if they are directly used by UI/other non-service logic.
// Most parsers are now used internally by services. If any parser needs to be public, add it here.
// e.g., export 'utils/data_parsers.dart' show someSpecificPublicParser;

// Note: Functions like claimDailyReward, fetchRaceData, etc., are now methods
// of their respective service classes.
// To use them, you would typically instantiate the service:
//
// Example:
// import 'package:your_app_name/igp_client.dart'; // Assuming this path
//
// AccountActionsService().claimDailyReward(someAccount);
// RaceService().fetchRaceData(anotherAccount);
//
// Or, if you prefer to manage service instances globally or via DI:
// final raceService = RaceService();
// raceService.fetchRaceData(account);

// The global variables (accounts, dioClients, cookieJars, appDocumentPath)
// are directly accessible after importing igp_client.dart if needed,
// though direct manipulation from UI should be minimized.