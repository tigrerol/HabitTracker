# MUST-DO Refactoring Tasks for HabitTracker

This document distills the most critical refactoring tasks from the code reviews conducted by Claude and Gemini.

## High-Priority (Critical)

1.  **Fix Memory Leaks in `LocationService`:** The current implementation of the `locationUpdateCallback` in `LocationService` has a high risk of creating retain cycles, which can lead to memory leaks and app instability. This must be fixed by using weak references or other memory management techniques.

2.  **Resolve Actor Isolation Inconsistencies:** The mixed use of `@MainActor` and `actor` for different services creates a high risk of deadlocks and other concurrency issues. The architecture should be standardized to use `@MainActor` for all UI-related services and `actor` only for truly concurrent operations.

3.  **Implement Proper Error Presentation:** The current error handling often fails to present errors to the user, leading to a poor user experience. A consistent error presentation mechanism (e.g., using alerts) must be implemented to inform users of any issues.

4.  **Add Comprehensive Test Coverage for Error Scenarios:** The existing tests primarily cover the "happy path." To ensure the app is robust, it is essential to add comprehensive test coverage for error conditions, edge cases, and failure scenarios.

## Medium-Priority (Important)

5.  **Refactor Large Views:** Large, complex views like `RoutineExecutionView` and `RoutineBuilderView` are difficult to maintain and test. They should be broken down into smaller, more manageable components to improve code quality and maintainability.

6.  **Consolidate Persistence Layer:** The mixed use of `UserDefaults` and `SwiftData` is confusing and inefficient. All persistence should be consolidated into `SwiftData` to create a unified and more powerful data layer.
