# watchOS App Development Plan

This document outlines the plan for creating a watchOS companion app for the HabitTracker project. The watch app will allow users to view and execute routines that have been created on the iOS app.

## 1. Project Setup

This section outlines the initial setup for the watchOS application, including the creation of the new target and the resulting file structure.

**Status:** Complete


### 1.1. Add watchOS Target

1.  **Add watchOS Target:** In Xcode, go to **File > New > Target...** and select the **watchOS** tab. Choose the **App** template and click **Next**.
2.  **Target Options:**
    *   **Product Name:** `HabitTrackerWatch`
    *   **Interface:** SwiftUI
    *   **Lifecycle:** SwiftUI App
    *   **Language:** Swift
    *   **Include Notification Scene:** Unchecked
3.  **Activate Scheme:** Xcode will ask if you want to activate the new scheme. Click **Activate**.

### 1.2. Resulting File Structure

This will create a new folder in the project named `HabitTrackerWatch` with the following structure:

```
HabitTrackerWatch/
├── HabitTrackerWatchApp.swift
├── Assets.xcassets/
└── Preview Content/
```

*   **`HabitTrackerWatchApp.swift`:** The main entry point for the watchOS app.
*   **`Assets.xcassets`:** Contains the app icons and other assets for the watch app.
*   **`Preview Content`:** Contains assets for SwiftUI previews.


## 2. Communication between iOS and watchOS

We will use the **WatchConnectivity** framework to transfer data between the iOS and watchOS apps. This framework provides a reliable way to send data between the two devices.

### 2.1. Frameworks

*   **[WatchConnectivity](https://developer.apple.com/documentation/watchconnectivity):** This framework is the core of the communication between the iOS and watchOS apps. We will use it to send and receive data.
*   **[SwiftUI](https://developer.apple.com/documentation/swiftui):** We will use SwiftUI to build the UI for both the iOS and watchOS apps.


### 2.2. iOS App Implementation

*   **`WatchConnectivityManager.swift`:** Create a new file named `WatchConnectivityManager.swift` in the `HabitTrackerPackage/Sources/HabitTrackerFeature/Services` directory. This file will contain a singleton class responsible for managing the `WCSession`.

    ```swift
    import WatchConnectivity
    import Foundation

    class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
        static let shared = WatchConnectivityManager()

        private override init() {
            super.init()
            if WCSession.isSupported() {
                WCSession.default.delegate = self
                WCSession.default.activate()
            }
        }

        // MARK: - WCSessionDelegate

        func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
            if let error = error {
                print("WCSession activation failed with error: \(error.localizedDescription)")
                return
            }
            print("WCSession activated with state: \(activationState.rawValue)")
        }

        func sessionDidBecomeInactive(_ session: WCSession) {
            print("WCSession became inactive.")
        }

        func sessionDidDeactivate(_ session: WCSession) {
            print("WCSession deactivated. Reactivating...")
            WCSession.default.activate()
        }

        func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
            // Handle incoming messages from Watch (if any, though plan focuses on Watch receiving)
            print("Received message from Watch: \(message)")
        }

        func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
            // Handle incoming user info from Watch (if any)
            print("Received user info from Watch: \(userInfo)")
        }

        func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
            // Handle incoming application context from Watch (if any)
            print("Received application context from Watch: \(applicationContext)")
        }

        func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
            if let error = error {
                print("File transfer failed with error: \(error.localizedDescription)")
                return
            }
            print("File transfer finished: \(fileTransfer.file.fileURL.lastPathComponent ?? "unknown file")")
        }

        // MARK: - Sending Data to Watch

        func sendRoutineDataToWatch(routineData: [String: Any]) {
            guard WCSession.default.isReachable else {
                print("Watch is not reachable. Data will be queued.")
                // Implement queuing mechanism for offline scenarios if needed
                return
            }

            WCSession.default.transferUserInfo(routineData)
            print("Sent routine data to Watch.")
        }
    }
    ```

*   **`WCSessionDelegate`:** The `WatchConnectivityManager` will conform to the `WCSessionDelegate` protocol and implement the following methods:
    *   `session(_:activationDidCompleteWith:error:)`
    *   `sessionDidBecomeInactive(_:)`
    *   `sessionDidDeactivate(_:)`
*   **Sending Data:** When a user creates or updates a routine, the `RoutineService` will call a method on the `WatchConnectivityManager` to send the routine data to the watch. This method will use the `transferUserInfo` method to send a dictionary containing the routine data.

### 2.3. watchOS App Implementation

*   **`WatchConnectivityManager.swift`:** Create a new file named `WatchConnectivityManager.swift` in the `HabitTrackerWatch/Services` directory. This file will contain a singleton class responsible for managing the `WCSession`.

    ```swift
    import WatchConnectivity
    import Foundation
    import SwiftData // Assuming SwiftData is used for local storage

    class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
        static let shared = WatchConnectivityManager()

        private override init() {
            super.init()
            if WCSession.isSupported() {
                WCSession.default.delegate = self
                WCSession.default.activate()
            }
        }

        // MARK: - WCSessionDelegate

        func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
            if let error = error {
                print("WCSession activation failed with error: \(error.localizedDescription)")
                return
            }
            print("WCSession activated with state: \(activationState.rawValue)")
        }

        func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
            // This method is called on a background queue.
            // Dispatch to main queue for UI updates or background queue for data processing.
            Task { @MainActor in // Or use DispatchQueue.main.async
                print("Received user info from iOS: \(userInfo)")
                // Example: Process routine data
                if let routineData = userInfo["routine"] as? Data {
                    do {
                        let decoder = JSONDecoder()
                        // Assuming RoutineTemplate is Decodable
                        // let routine = try decoder.decode(RoutineTemplate.self, from: routineData)
                        // Save to SwiftData
                        // PersistenceService.shared.saveRoutine(routine)
                        print("Successfully processed routine data.")
                    } catch {
                        print("Error decoding routine data: \(error.localizedDescription)")
                    }
                }
            }
        }

        func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
            // Handle incoming application context from iOS (if any)
            print("Received application context from iOS: \(applicationContext)")
        }

        func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
            // Handle incoming messages from iOS (if any)
            print("Received message from iOS: \(message)")
        }

        func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
            if let error = error {
                print("File transfer failed with error: \(error.localizedDescription)")
                return
            }
            print("File transfer finished: \(fileTransfer.file.fileURL.lastPathComponent ?? "unknown file")")
        }
    }
    ```

*   **`WCSessionDelegate`:** The `WatchConnectivityManager` will conform to the `WCSessionDelegate` protocol and implement the following methods:
    *   `session(_:activationDidCompleteWith:error:)`
    *   `session(_:didReceiveUserInfo:)`
*   **Receiving Data:** When the watch app receives new routine data in the `session(_:didReceiveUserInfo:)` method, it will decode the data and update its local SwiftData store. This will be done on a background queue to avoid blocking the main thread.

### 2.4. Common Mistakes & Debugging Strategies for WatchConnectivity

**Common Mistakes:**

*   **Forgetting to activate the session:** `WCSession.default.activate()` must be called on both sides.
*   **Not setting the delegate:** `WCSession.default.delegate = self` is crucial for receiving callbacks.
*   **Incorrectly handling `isReachable`:** `isReachable` only indicates if the counterpart app is currently running and able to receive messages *immediately*. For background transfers, `transferUserInfo` or `transferFile` are more appropriate.
*   **UI updates on background thread:** Attempting to update SwiftUI views directly from `WCSessionDelegate` methods (which are called on a background queue) will lead to crashes. Always dispatch UI updates to the main thread using `@MainActor` or `DispatchQueue.main.async`.
*   **Data serialization/deserialization issues:** Ensure that the data sent (e.g., `[String: Any]`) can be correctly encoded/decoded on both ends. For custom types, `Codable` is highly recommended.
*   **Missing entitlements:** Ensure both targets have the "App Groups" capability enabled and share a common app group if you plan to use shared containers for data. While not strictly necessary for `WatchConnectivity` itself, it's good practice for shared data.

**Debugging Strategies:**

*   **Print statements:** Use `print()` statements in all `WCSessionDelegate` methods to track the session's state and data flow.
*   **Xcode Console:** Pay close attention to the Xcode console for WatchConnectivity-related errors or warnings.
*   **Device Logs:** For more detailed logs, use the Devices and Simulators window (Window > Devices and Simulators) to view the device logs for both the iPhone and Apple Watch.
*   **Breakpoints:** Set breakpoints in your `WCSessionDelegate` methods to step through the code and inspect the `session` and `userInfo` objects.
*   **Reachability Check:** Regularly check `WCSession.default.isReachable` on the iOS side before attempting interactive messages.
*   **Test on real devices:** While simulators are useful, WatchConnectivity behavior can sometimes differ on physical devices. Test thoroughly on both.
*   **Background App Refresh:** Ensure "Background App Refresh" is enabled for your app on both the iPhone and Apple Watch (Settings > General > Background App Refresh).
*   **Reset Simulator:** If you encounter persistent issues, try resetting the simulator (Hardware > Erase All Content and Settings).


## 7. Offline Functionality

The watch app should be able to function offline. This means that the user should be able to start and complete routines even when the watch is not connected to the iPhone.

### 7.1. File Structure

We will create the following file for the offline functionality:

```
HabitTrackerWatch/
└── Services/
    └── OfflineQueueManager.swift
```

### 7.2. Data Caching

The watch app will cache all routine data locally using SwiftData. This will allow the user to view and interact with their routines even when the watch is offline.

### 7.3. Queueing Data

When the user completes a routine offline, the watch app will store the completion data in a local queue. This queue will be managed by the `OfflineQueueManager`. The `OfflineQueueManager` will be responsible for storing the data and sending it to the iOS app the next time the watch is connected to the iPhone.



## 3. Data Management on watchOS

The watch app will need to store a local copy of the user's routines. We will use **SwiftData** for this, as it is already in use in the iOS app.

### 3.1. Frameworks

*   **[SwiftData](https://developer.apple.com/documentation/SwiftData):** We will use SwiftData to store the user's routines on the watch. This will allow the app to function offline.


### 3.2. Data Model

We will reuse the existing `RoutineTemplate` and related models from the `HabitTrackerPackage`. This will ensure that the data is consistent between the iOS and watchOS apps.

### 3.3. Persistence

We will create a SwiftData container in the watch app to store the routines. This will be done in the `HabitTrackerWatchApp.swift` file.

### 3.4. Data Syncing

The watch app will update its local data store whenever it receives new data from the iOS app via WatchConnectivity. This will be done in the `WatchConnectivityManager`.


## 4. User Interface (UI)

The watch app's UI will be simple and focused on the core task of running routines. We will use SwiftUI to build the UI.

### 4.1. File Structure

We will create the following files for the UI:

```
HabitTrackerWatch/
├── Views/
│   ├── RoutineListView.swift
│   └── RoutineExecutionView.swift
└── ViewModels/
    ├── RoutineListViewModel.swift
    └── RoutineExecutionViewModel.swift
```

### 4.2. Main View

*   **`RoutineListView.swift`:** This view will display a list of the user's available routines.
*   **`NavigationStack`:** The `RoutineListView` will be embedded in a `NavigationStack` to allow navigation to the routine execution view.
*   **`@StateObject`:** The `RoutineListView` will use a `@StateObject` to observe a `RoutineListViewModel`.

### 4.3. Routine Execution View

*   **`RoutineExecutionView.swift`:** This view will display the current habit in a routine and allow the user to mark it as complete.
*   **`TabView`:** The `RoutineExecutionView` will use a `TabView` with a `PageTabViewStyle` to allow the user to swipe between habits in the routine.
*   **`@StateObject`:** The `RoutineExecutionView` will use a `@StateObject` to observe a `RoutineExecutionViewModel`.

### 4.4. ViewModels

*   **`RoutineListViewModel.swift`:** This view model will be responsible for fetching the user's routines from the SwiftData store and providing them to the `RoutineListView`.
*   **`RoutineExecutionViewModel.swift`:** This view model will be responsible for managing the state of the routine execution, including the current habit, the user's progress, and the completion of the routine.



## 5. Concurrency

watchOS apps have strict performance and memory constraints. It is crucial to handle concurrency correctly to avoid performance issues.

### 5.1. Frameworks

*   **[Combine](https://developer.apple.com/documentation/combine):** We will use the Combine framework to manage asynchronous operations, such as fetching data from SwiftData and communicating with the iOS app.
*   **[Swift Concurrency](https://developer.apple.com/documentation/swift/concurrency):** We will use Swift's modern concurrency features, such as `async/await` and actors, to write safe and efficient asynchronous code.

### 5.2. Background Tasks

We will use **[WKApplicationRefreshBackgroundTask](https://developer.apple.com/documentation/watchkit/wkapplicationrefreshbackgroundtask)** to update the app's data in the background. This will be used to sync data with the iOS app when the watch is not connected.

### 5.3. Main Actor

All UI updates must be performed on the main thread. We will use the **[@MainActor](https://developer.apple.com/documentation/swift/mainactor)** attribute to ensure that all UI-related code is executed on the main thread.


### 5.4. WatchConnectivity

All WatchConnectivity delegate methods will be called on a background queue. We will need to dispatch to the main queue before updating the UI. We will do this by wrapping the UI update code in a `DispatchQueue.main.async` block.

### 5.5. SwiftData

All SwiftData operations should be performed on a background queue to avoid blocking the main thread. We will use a separate `ModelContext` for background operations.






## 8. Notifications

We will mirror the iPhone's notifications on the Apple Watch. This will keep the notification logic in one place and avoid duplicating code.

### 8.1. Frameworks

*   **[UserNotifications](https://developer.apple.com/documentation/usernotifications):** We will use the UserNotifications framework to handle notifications on both the iOS and watchOS apps.


### 8.2. Mirroring

When the iPhone app sends a notification, it will automatically be mirrored on the watch. This is the default behavior for watchOS apps.

### 8.3. "Show on Apple Watch" Setting

In the iOS app, we will add a setting that allows the user to choose whether or not to show notifications on their Apple Watch. This will give the user more control over their notification experience.

