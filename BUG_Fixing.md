# Bug Fixes

## Bug: "Current locations" displayed instead of actual location name

**Description:**
On the welcome screen of the iOS application, when a user's current location is detected but does not match a predefined category (e.g., Home, Office), the UI displays "Current Location" instead of the actual name of the detected location (e.g., "123 Main St, Anytown"). This occurs in the `SmartTemplateSelectionView`'s `contextIndicatorView`.

**Root Cause:**
The `contextIndicatorView` in `SmartTemplateSelectionView.swift` has a conditional logic that checks `context.location != .unknown`. If `context.location` is `.unknown` (meaning no categorized location is matched), but `routineService.routineSelector.locationCoordinator.currentLocation` is not `nil` (meaning a raw location is available), the view falls into a branch that explicitly displays the hardcoded string "Current Location". The `context.location` is only updated when a categorized location is found, not for every detected location.

**Solution:**
Modify the `SmartTemplateSelectionView.swift` to display the actual detected location name when `context.location` is `.unknown` but `coordinator.currentLocation` is available. This will involve using the `LocationCoordinator` to resolve the raw `CLLocation` into a human-readable address string.

**Steps to Fix:**
1.  **Identify the relevant code:** The issue is within the `contextIndicatorView` computed property in `SmartTemplateSelectionView.swift`.
2.  **Modify the conditional logic:** Change the `else if coordinator.currentLocation != nil` block to attempt to resolve the `coordinator.currentLocation` into a displayable address.
3.  **Utilize `LocationCoordinator`:** The `LocationCoordinator` already has methods to handle location updates and potentially reverse geocode coordinates. We need to ensure that the `currentLocation` property of `LocationCoordinator` is being observed and its display name is used when available.

**Affected File:**
`HabitTrackerPackage/Sources/HabitTrackerFeature/Views/SmartTemplateSelectionView.swift`

## Bug: Blank screen on first location interaction

**Description:**
When the user attempts to set, change, or remove a location for the first time, a blank screen appears. Subsequent attempts to interact with location settings work as expected.

**Root Cause:**
This issue likely stems from an initialization problem or a race condition where necessary location services or UI components are not fully ready or authorized on the very first interaction. It could be related to:
-   **Permissions:** The app might be requesting location permissions for the first time, and the UI doesn't handle the asynchronous permission flow gracefully, leading to a blank screen until permissions are granted and the view is re-rendered.
-   **Service Initialization:** Core location services or managers (e.g., `CLLocationManager`, `LocationCoordinator`) might not be fully initialized or their delegates set up before the UI attempts to interact with them.
-   **Data Loading:** The view responsible for location management might be trying to load or display data from location services before that data is available, causing an empty state.
-   **UI Lifecycle:** The view's lifecycle methods might not be correctly handling the initial presentation, especially if it relies on data that becomes available asynchronously.

**Solution:**
Investigate the initialization flow of location-related views and services, particularly `LocationSetupView` and `LocationCoordinator`. Ensure that:
-   Location permission requests are handled robustly, with appropriate UI feedback (e.g., loading indicators, permission prompts).
-   Location services are fully initialized and ready before any UI interaction attempts to use them.
-   Any data dependencies for the location UI are loaded asynchronously and the UI updates reactively when data becomes available.

**Steps to Fix:**
1.  **Examine `LocationSetupView.swift`:** This view is likely the primary entry point for location interactions. Check its `onAppear` and other lifecycle methods for potential issues.
2.  **Review `LocationCoordinator` and `LocationTrackingService` initialization:** Ensure these services are initialized early enough and handle permission requests properly.
3.  **Add Debugging:** Insert print statements or breakpoints to trace the execution flow and state of location services during the first interaction.
4.  **Implement Loading States:** If data loading is asynchronous, ensure the UI displays a loading state or placeholder until data is ready.

**Affected Files (potential):**
-   `HabitTrackerPackage/Sources/HabitTrackerFeature/Views/LocationSetupView.swift`
-   `HabitTrackerPackage/Sources/HabitTrackerFeature/Services/Location/LocationCoordinator.swift`
-   `HabitTrackerPackage/Sources/HabitTrackerFeature/Services/Location/LocationTrackingService.swift`
-   Any other views or services directly involved in the initial location setup or modification.