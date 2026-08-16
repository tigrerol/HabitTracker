import Foundation

/// Carries the app's preference data between devices through iCloud's
/// key-value store.
///
/// Routines, sessions, mood and locations ride SwiftData's CloudKit mirroring.
/// Modes, day categories and location categories are plain UserDefaults blobs
/// outside that store, and `NSUbiquitousKeyValueStore` is the right size of
/// hammer for them: a handful of small values, last-writer-wins, no schema.
///
/// Paused and interrupted sessions deliberately do not travel — resuming a
/// half-finished routine on a different device isn't meaningful, and a stale
/// snapshot arriving mid-routine would be actively confusing.
@MainActor
public final class UbiquitousSettingsSync {
    public static let shared = UbiquitousSettingsSync()

    /// Posted once remote values have landed in UserDefaults, so the services
    /// holding them in memory can reload.
    public static let didChangeNotification = Notification.Name("HabitTrackerUbiquitousSettingsDidChange")

    /// The preference keys that travel between devices.
    public static let syncedKeys = [
        PersistenceKeys.dayCategorySettings,
        PersistenceKeys.locationCategorySettings,
        PersistenceKeys.routineModes
    ]

    private let store: NSUbiquitousKeyValueStore
    private let defaults: UserDefaults
    private var observers: [any NSObjectProtocol] = []

    /// Guards the echo: applying a remote value writes to UserDefaults, which
    /// would otherwise push that same value straight back up.
    private var isApplyingRemoteChange = false

    public init(
        store: NSUbiquitousKeyValueStore = .default,
        defaults: UserDefaults = .standard
    ) {
        self.store = store
        self.defaults = defaults
    }

    /// Begin mirroring. Safe to call more than once.
    ///
    /// Observers are held weakly and never torn down: the app-wide instance
    /// lives as long as the process, and the ones tests create simply go quiet
    /// when they deallocate.
    public func start() {
        guard observers.isEmpty else { return }

        observers.append(
            NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: store,
                queue: .main
            ) { [weak self] notification in
                // Read the keys out here: Notification isn't Sendable, a
                // [String] is.
                let changed = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
                MainActor.assumeIsolated {
                    self?.applyRemoteValues(for: changed ?? Self.syncedKeys)
                }
            }
        )

        observers.append(
            NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: defaults,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.pushLocalValues()
                }
            }
        )

        store.synchronize()

        // Remote first, then push only what iCloud doesn't have yet: a fresh
        // device must not overwrite good cloud data with its defaults.
        applyRemoteValues(for: Self.syncedKeys)
        pushLocalValues(onlyMissingRemotely: true)
    }

    // MARK: - Directions

    /// Copy iCloud's values into UserDefaults, announcing what changed.
    private func applyRemoteValues(for keys: [String]) {
        let relevant = keys.filter { Self.syncedKeys.contains($0) }
        guard !relevant.isEmpty else { return }

        var changedKeys: [String] = []
        isApplyingRemoteChange = true
        for key in relevant {
            guard let remote = store.data(forKey: key) else { continue }
            guard remote != defaults.data(forKey: key) else { continue }
            defaults.set(remote, forKey: key)
            changedKeys.append(key)
        }
        isApplyingRemoteChange = false

        guard !changedKeys.isEmpty else { return }
        LoggingService.shared.info(
            "Applied iCloud settings: \(changedKeys.joined(separator: ", "))",
            category: .app
        )
        reloadServices(for: changedKeys)
        NotificationCenter.default.post(
            name: Self.didChangeNotification,
            object: nil,
            userInfo: [NSUbiquitousKeyValueStoreChangedKeysKey: changedKeys]
        )
    }

    /// These services cache their settings in memory, so a fresh value in
    /// UserDefaults is invisible until they re-read it. Told directly rather
    /// than via the notification: each is a singleton, and per-instance
    /// observers would outlive the short-lived copies tests create.
    private func reloadServices(for changedKeys: [String]) {
        if changedKeys.contains(PersistenceKeys.routineModes) {
            RoutineModeService.shared.reload()
        }
        if changedKeys.contains(PersistenceKeys.dayCategorySettings) {
            DayCategoryManager.shared.reload()
        }
        if changedKeys.contains(PersistenceKeys.locationCategorySettings) {
            LocationCategoryManager.shared.reload()
        }
    }

    /// Copy local values up to iCloud.
    private func pushLocalValues(onlyMissingRemotely: Bool = false) {
        guard !isApplyingRemoteChange else { return }

        var pushed = false
        for key in Self.syncedKeys {
            guard let local = defaults.data(forKey: key) else { continue }
            let remote = store.data(forKey: key)
            if onlyMissingRemotely {
                guard remote == nil else { continue }
            } else {
                guard remote != local else { continue }
            }
            store.set(local, forKey: key)
            pushed = true
        }

        if pushed {
            store.synchronize()
        }
    }
}
