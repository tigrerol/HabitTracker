import Testing
import Foundation
@testable import HabitTrackerFeature

/// In-memory stand-in for iCloud's key-value store — the real one needs an
/// account and a network, neither of which belongs in a unit test.
private final class FakeKeyValueStore: NSUbiquitousKeyValueStore, @unchecked Sendable {
    private var storage: [String: Data] = [:]
    private(set) var synchronizeCount = 0

    override func data(forKey defaultName: String) -> Data? {
        storage[defaultName]
    }

    override func set(_ aData: Data?, forKey defaultName: String) {
        storage[defaultName] = aData
    }

    override func synchronize() -> Bool {
        synchronizeCount += 1
        return true
    }
}

@Suite("iCloud settings sync")
@MainActor
struct UbiquitousSettingsSyncTests {

    private func makeSync(_ label: String = "kvs") throws -> (UbiquitousSettingsSync, FakeKeyValueStore, UserDefaults) {
        let defaults = try makeIsolatedDefaults(label)
        let store = FakeKeyValueStore()
        return (UbiquitousSettingsSync(store: store, defaults: defaults), store, defaults)
    }

    private func modesData(_ name: String) throws -> Data {
        let settings = RoutineModeSettings(modes: [RoutineMode(name: name)], activeModeId: nil)
        return try JSONEncoder().encode(settings)
    }

    @Test("A fresh device picks up settings from iCloud")
    func remoteValuesLandLocally() throws {
        let (sync, store, defaults) = try makeSync()
        let remote = try modesData("Vacation")
        store.set(remote, forKey: PersistenceKeys.routineModes)

        sync.start()

        #expect(defaults.data(forKey: PersistenceKeys.routineModes) == remote)
    }

    @Test("Local settings are pushed up when iCloud has none")
    func localValuesPushUp() throws {
        let (sync, store, defaults) = try makeSync()
        let local = try modesData("Sick Day")
        defaults.set(local, forKey: PersistenceKeys.routineModes)

        sync.start()

        #expect(store.data(forKey: PersistenceKeys.routineModes) == local)
    }

    @Test("iCloud wins at launch, so a fresh device can't clobber it")
    func remoteWinsOverLocalAtLaunch() throws {
        let (sync, store, defaults) = try makeSync()
        let remote = try modesData("Vacation")
        let local = try modesData("Local Only")
        store.set(remote, forKey: PersistenceKeys.routineModes)
        defaults.set(local, forKey: PersistenceKeys.routineModes)

        sync.start()

        #expect(defaults.data(forKey: PersistenceKeys.routineModes) == remote)
        #expect(store.data(forKey: PersistenceKeys.routineModes) == remote)
    }

    @Test("Device-local keys never travel")
    func unsyncedKeysStayPut() throws {
        let (sync, store, defaults) = try makeSync()
        defaults.set(Data([0x01]), forKey: PersistenceKeys.pausedSessions)
        defaults.set(Data([0x02]), forKey: PersistenceKeys.interruptedSession)

        sync.start()

        #expect(store.data(forKey: PersistenceKeys.pausedSessions) == nil)
        #expect(store.data(forKey: PersistenceKeys.interruptedSession) == nil)
    }

    @Test("Every synced key travels")
    func allSyncedKeysPushUp() throws {
        let (sync, store, defaults) = try makeSync()
        for (index, key) in UbiquitousSettingsSync.syncedKeys.enumerated() {
            defaults.set(Data([UInt8(index)]), forKey: key)
        }

        sync.start()

        for (index, key) in UbiquitousSettingsSync.syncedKeys.enumerated() {
            #expect(store.data(forKey: key) == Data([UInt8(index)]))
        }
    }

    @Test("Applying a remote value doesn't echo it back up")
    func remoteApplyDoesNotEcho() throws {
        let (sync, store, defaults) = try makeSync()
        let remote = try modesData("Vacation")
        store.set(remote, forKey: PersistenceKeys.routineModes)

        sync.start()
        let afterStart = store.synchronizeCount

        // A local write of the same value has nothing new to say.
        defaults.set(remote, forKey: PersistenceKeys.routineModes)

        #expect(store.data(forKey: PersistenceKeys.routineModes) == remote)
        #expect(store.synchronizeCount == afterStart)
    }

    @Test("Starting twice doesn't double-register")
    func startIsIdempotent() throws {
        let (sync, store, defaults) = try makeSync()
        defaults.set(try modesData("Travel"), forKey: PersistenceKeys.routineModes)

        sync.start()
        let afterFirst = store.synchronizeCount
        sync.start()

        #expect(store.synchronizeCount == afterFirst)
    }
}
