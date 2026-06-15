import Foundation
import XCTest
@testable import AeroMux

@MainActor
final class SettingsStoreTests: XCTestCase {
    func test_windowMode_defaultsToStandardAndPersists() throws {
        let fixture = try SettingsFixture()
        let store = SettingsStore(
            defaults: fixture.defaults,
            fileManager: fixture.fileManager,
            logger: AppLogger()
        )

        XCTAssertEqual(store.windowMode, .standard)
        XCTAssertEqual(store.windowTransparency, 0)
        XCTAssertEqual(store.windowBackgroundOpacity, 1)

        store.windowMode = .floating
        store.windowTransparency = 42
        store.persist()

        let reloaded = SettingsStore(
            defaults: fixture.defaults,
            fileManager: fixture.fileManager,
            logger: AppLogger()
        )
        XCTAssertEqual(reloaded.windowMode, .floating)
        XCTAssertEqual(reloaded.windowTransparency, 42)
        XCTAssertEqual(reloaded.windowBackgroundOpacity, 0.58, accuracy: 0.001)

        let payload = try fixture.settingsPayload()
        XCTAssertEqual(payload["windowMode"] as? String, "floating")
        XCTAssertEqual((payload["windowTransparency"] as? NSNumber)?.doubleValue, 42)
    }

    func test_unknownWindowModeFallsBackToStandard() throws {
        let fixture = try SettingsFixture()
        try fixture.writeSettingsPayload([
            "compactMode": false,
            "launchAtLogin": false,
            "pinActiveWorkspaceFirst": false,
            "sidebarWidth": 260,
            "windowMode": "hovercraft",
        ])

        let store = SettingsStore(
            defaults: fixture.defaults,
            fileManager: fixture.fileManager,
            logger: AppLogger()
        )

        XCTAssertEqual(store.windowMode, .standard)
    }

    func test_windowTransparency_isClampedAndPersists() throws {
        let fixture = try SettingsFixture()
        try fixture.writeSettingsPayload([
            "compactMode": false,
            "launchAtLogin": false,
            "pinActiveWorkspaceFirst": false,
            "sidebarWidth": 260,
            "windowMode": "standard",
            "windowTransparency": 90,
        ])

        let store = SettingsStore(
            defaults: fixture.defaults,
            fileManager: fixture.fileManager,
            logger: AppLogger()
        )

        XCTAssertEqual(store.windowTransparency, 65)
        XCTAssertEqual(store.windowBackgroundOpacity, 0.35, accuracy: 0.001)

        store.setWindowTransparency(-10)
        XCTAssertEqual(store.windowTransparency, 0)
        XCTAssertEqual(store.windowBackgroundOpacity, 1)

        let payload = try fixture.settingsPayload()
        XCTAssertEqual((payload["windowTransparency"] as? NSNumber)?.doubleValue, 0)
    }
}

private final class TemporaryHomeFileManager: FileManager {
    private let homeURL: URL

    init(homeURL: URL) {
        self.homeURL = homeURL
        super.init()
    }

    override var homeDirectoryForCurrentUser: URL {
        homeURL
    }
}

private struct SettingsFixture {
    let homeURL: URL
    let fileManager: FileManager
    let defaults: UserDefaults

    init() throws {
        let id = UUID().uuidString
        homeURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "AeroMuxSettingsStoreTests-\(id)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: homeURL, withIntermediateDirectories: true)
        fileManager = TemporaryHomeFileManager(homeURL: homeURL)

        let suiteName = "AeroMuxTests.SettingsStore.\(id)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Unable to create isolated UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        self.defaults = defaults
    }

    func settingsPayload() throws -> [String: Any] {
        let data = try Data(contentsOf: settingsURL)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let payload = object as? [String: Any] else {
            XCTFail("Expected settings payload to be a JSON object")
            return [:]
        }
        return payload
    }

    func writeSettingsPayload(_ payload: [String: Any]) throws {
        try FileManager.default.createDirectory(at: configURL, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: settingsURL, options: .atomic)
    }

    private var configURL: URL {
        homeURL
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("aeromux", isDirectory: true)
    }

    private var settingsURL: URL {
        configURL.appendingPathComponent("settings.json")
    }
}
