import CoreData
import XCTest
@testable import Lazyflow

final class SecurityTests: XCTestCase {

    // MARK: - Core Data File Protection

    func testPersistentStoreDescription_HasFileProtection() {
        let controller = PersistenceController(inMemory: false, configureViewContext: true, enableCloudKit: false)
        guard let description = controller.container.persistentStoreDescriptions.first else {
            XCTFail("No persistent store description found")
            return
        }

        let fileProtection = description.options[NSPersistentStoreFileProtectionKey] as? FileProtectionType
        XCTAssertEqual(fileProtection, .complete, "Core Data store should use NSFileProtectionComplete")
    }

    func testPersistentStoreDescription_HasHistoryTracking() {
        let controller = PersistenceController(inMemory: false, configureViewContext: true, enableCloudKit: false)
        guard let description = controller.container.persistentStoreDescriptions.first else {
            XCTFail("No persistent store description found")
            return
        }

        let historyTracking = description.options[NSPersistentHistoryTrackingKey] as? NSNumber
        XCTAssertEqual(historyTracking, true, "Persistent history tracking should be enabled")
    }

    // MARK: - AppStorage Audit (No Sensitive Data)

    func testNoSensitiveKeysInUserDefaults() {
        // Verify that app-specific UserDefaults keys do not store sensitive data
        // Filter to only app keys (exclude Apple/system framework prefixes)
        let systemPrefixes = ["NS", "Apple", "AK", "com.apple", "PK", "INNext", "WebKit"]
        let sensitivePatterns = ["password", "secret", "apikey", "api_key", "bearer", "credential"]
        let defaults = UserDefaults.standard.dictionaryRepresentation()

        let appKeys = defaults.keys.filter { key in
            !systemPrefixes.contains(where: { key.hasPrefix($0) })
        }

        for key in appKeys {
            let lowercased = key.lowercased()
            for pattern in sensitivePatterns {
                XCTAssertFalse(
                    lowercased.contains(pattern),
                    "UserDefaults key '\(key)' appears to contain sensitive data (matched '\(pattern)')"
                )
            }
        }
    }

    // MARK: - OpenResponsesConfig Codable Security

    func testOpenResponsesConfig_APIKeyExcludedFromCodable() throws {
        let config = OpenResponsesConfig(
            endpoint: "https://api.example.com/v1/responses",
            apiKey: "sk-secret-key-12345",
            model: "gpt-4"
        )

        let encoded = try JSONEncoder().encode(config)
        let jsonString = String(data: encoded, encoding: .utf8)!

        XCTAssertFalse(jsonString.contains("sk-secret-key"), "API key must NOT appear in encoded JSON")
        XCTAssertFalse(jsonString.contains("apiKey"), "apiKey field must NOT appear in encoded JSON")
        XCTAssertTrue(jsonString.contains("api.example.com"), "Endpoint should be in encoded JSON")
        XCTAssertTrue(jsonString.contains("gpt-4"), "Model should be in encoded JSON")
    }

    func testOpenResponsesConfig_DecodedAPIKeyIsNil() throws {
        let json = """
        {"endpoint": "https://api.example.com/v1/responses", "model": "gpt-4"}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(OpenResponsesConfig.self, from: data)

        XCTAssertNil(decoded.apiKey, "Decoded config should have nil apiKey (loaded from Keychain separately)")
    }

    // MARK: - In-Memory Store (No File Protection Expected)

    func testInMemoryStore_DoesNotRequireFileProtection() {
        let controller = PersistenceController(inMemory: true, enableCloudKit: false)
        XCTAssertTrue(controller.isLoaded, "In-memory store should load successfully")
    }
}
