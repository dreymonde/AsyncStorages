import Foundation

public protocol WritableStorage<Key, Value>: StorageDesign {
    associatedtype Key
    associatedtype Value
    
    func set(_ value: Value, forKey key: Key) async throws
}

extension WritableStorage where Key == Void {
    public func set(_ value: Value) async throws {
        try await set(value, forKey: ())
    }
}

public protocol WriteOnlyStorage<Key, Value>: WritableStorage { }

public struct WriteOnly<Underlying: WritableStorage>: WriteOnlyStorage {
    public let underlying: Underlying
    
    public init(underlying: Underlying) {
        self.underlying = underlying
    }
    
    public func set(_ value: Underlying.Value, forKey key: Underlying.Key) async throws {
        try await underlying.set(value, forKey: key)
    }
}

public extension WritableStorage {
    func writeOnly() -> WriteOnly<Self> {
        return WriteOnly(underlying: self)
    }
}

public struct MappedValuesWriteOnlyStorage<Underlying: WritableStorage, ValueFrom>: WriteOnlyStorage {
    public let underlying: Underlying
    public let transform: (ValueFrom) async throws -> Underlying.Value
    
    public init(underlying: Underlying, transform: @escaping (ValueFrom) async throws -> Underlying.Value) {
        self.underlying = underlying
        self.transform = transform
    }
    
    public func set(_ value: ValueFrom, forKey key: Underlying.Key) async throws {
        let transformedValue = try await transform(value)
        try await underlying.set(transformedValue, forKey: key)
    }
}

extension WriteOnlyStorage {
    public func mapValues<ValueFrom>(
        from type: ValueFrom.Type = ValueFrom.self,
        _ transform: @escaping (ValueFrom) async throws -> Value
    ) -> MappedValuesWriteOnlyStorage<Self, ValueFrom> {
        return MappedValuesWriteOnlyStorage(underlying: self, transform: transform)
    }
}

public struct MappedKeysWriteOnlyStorage<Underlying: WritableStorage, KeyFrom>: WriteOnlyStorage {
    public let underlying: Underlying
    public let transform: (KeyFrom) async throws -> Underlying.Key
    
    public init(underlying: Underlying, transform: @escaping (KeyFrom) async throws -> Underlying.Key) {
        self.underlying = underlying
        self.transform = transform
    }
    
    public func set(_ value: Underlying.Value, forKey key: KeyFrom) async throws {
        let originalKey = try await transform(key)
        try await underlying.set(value, forKey: originalKey)
    }
}

extension WriteOnlyStorage {
    public func mapKeys<KeyFrom>(
        from type: KeyFrom.Type = KeyFrom.self,
        _ transform: @escaping (KeyFrom) async throws -> Key
    ) -> MappedKeysWriteOnlyStorage<Self, KeyFrom> {
        return MappedKeysWriteOnlyStorage(underlying: self, transform: transform)
    }
    
    public func singleKey(_ key: Key) -> MappedKeysWriteOnlyStorage<Self, Void> {
        mapKeys({ key })
    }
}
