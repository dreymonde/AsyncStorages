import Foundation
import Testing
@testable import AsyncStorages

enum TestError: Error, Equatable {
    case missing
    case fallback
    case transform
    case writeFailed
}

actor TestStoreState<Key: Hashable, Value> {
    private var values: [Key: Value]

    init(_ values: [Key: Value] = [:]) {
        self.values = values
    }

    func value(for key: Key) throws -> Value {
        guard let value = values[key] else {
            throw TestError.missing
        }
        return value
    }

    func set(_ value: Value, for key: Key) {
        values[key] = value
    }

    func update(
        for key: Key,
        _ modify: (inout Value) -> Void
    ) throws -> Value {
        guard var value = values[key] else {
            throw TestError.missing
        }

        modify(&value)
        values[key] = value
        return value
    }

    func snapshot() -> [Key: Value] {
        values
    }
}

final class RecorderStorage<Key: Hashable, Value>: UpdateableStorage {
    let storageName: String

    private let state: TestStoreState<Key, Value>

    init(
        _ initialValues: [Key: Value] = [:],
        name: String = "RecorderStorage"
    ) {
        self.storageName = name
        self.state = TestStoreState(initialValues)
    }

    func retrieve(forKey key: Key) async throws -> Value {
        try await state.value(for: key)
    }

    func set(_ value: Value, forKey key: Key) async throws {
        await state.set(value, for: key)
    }

    func update(
        forKey key: Key,
        _ modify: @escaping (inout Value) -> Void
    ) async throws -> Value {
        try await state.update(for: key, modify)
    }

    var _wrappedStorages: [any StorageDesign] {
        []
    }

    func snapshot() async -> [Key: Value] {
        await state.snapshot()
    }
}

struct ConstantReadOnlyStorage<Key, Value>: ReadOnlyStorage {
    let storageName: String
    let value: Value

    init(value: Value, name: String = "ConstantReadOnlyStorage") {
        self.storageName = name
        self.value = value
    }

    func retrieve(forKey key: Key) async throws -> Value {
        value
    }

    var _wrappedStorages: [any StorageDesign] {
        []
    }
}

struct FailingReadOnlyStorage<Key, Value>: ReadOnlyStorage {
    let storageName: String
    let error: Error

    init(error: Error = TestError.missing, name: String = "FailingReadOnlyStorage") {
        self.storageName = name
        self.error = error
    }

    func retrieve(forKey key: Key) async throws -> Value {
        throw error
    }

    var _wrappedStorages: [any StorageDesign] {
        []
    }
}

struct DefaultNamedStorage: ReadOnlyStorage {
    func retrieve(forKey key: String) async throws -> Int {
        1
    }

    var _wrappedStorages: [any StorageDesign] {
        []
    }
}

actor OrderedRecorder<Element: Sendable> {
    private var values: [Element] = []

    func append(_ value: Element) {
        values.append(value)
    }

    func snapshot() -> [Element] {
        values
    }
}

struct UserProfile: Codable, Equatable {
    let id: Int
    let name: String
}

struct DiskTestContext {
    let rootURL: URL

    init(testName: String = UUID().uuidString) {
        rootURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("AsyncStoragesTests", isDirectory: true)
            .appendingPathComponent(testName, isDirectory: true)
    }

    func fileURL(_ name: String) -> URL {
        rootURL.appendingPathComponent(name)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}

func readme() async throws {
    struct User: Codable {
        var isActive = false
    }
    
    let userStorage = MemoryStorage<String, User>()
    try await userStorage.update(forKey: "123") { user in
        user.isActive = true
    }
let memoryStorage = MemoryStorage<String, Int>()
let defaulting = memoryStorage.defaulting(to: 0)
let protected = memoryStorage.recover { error in
    switch error {
    case is MemoryStorageValueMissingForKey<String>:
        return 15
    default:
        return -1
    }
}
    
    do {
let storage = MemoryStorage<String, [Int]>()
try await storage
    .defaulting(to: [])
    .serial()
    .update(forKey: "first") {
        $0.append(10)
    }
    }
}
