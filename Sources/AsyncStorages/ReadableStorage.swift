//
//  File.swift
//  
//
//  Created by Oleg on 7/11/24.
//

import Foundation

public protocol ReadableStorage<Key, Value>: StorageDesign {
    associatedtype Key
    associatedtype Value
    
    func retrieve(forKey key: Key) async throws -> Value
}

extension ReadableStorage where Key == Void {
    public func retrieve() async throws -> Value {
        try await retrieve(forKey: ())
    }
}

public protocol ReadOnlyStorage<Key, Value>: ReadableStorage { }

public struct ReadOnly<Underlying: ReadableStorage>: ReadOnlyStorage {
    public let underlying: Underlying
    
    public init(underlying: Underlying) {
        self.underlying = underlying
    }
    
    public func retrieve(forKey key: Underlying.Key) async throws -> Underlying.Value {
        try await underlying.retrieve(forKey: key)
    }
}

public extension ReadableStorage {
    func readOnly() -> ReadOnly<Self> {
        return ReadOnly(underlying: self)
    }
}

public struct MappedValuesReadOnlyStorage<Underlying: ReadableStorage, ValueTo>: ReadOnlyStorage {
    public let underlying: Underlying
    public let transform: (Underlying.Value) async throws -> ValueTo
    
    public init(underlying: Underlying, transform: @escaping (Underlying.Value) async throws -> ValueTo) {
        self.underlying = underlying
        self.transform = transform
    }
    
    public func retrieve(forKey key: Underlying.Key) async throws -> ValueTo {
        return try await transform(try await underlying.retrieve(forKey: key))
    }
}

extension ReadOnlyStorage {
    public func mapValues<ValueTo>(
        to type: ValueTo.Type = ValueTo.self,
        _ transform: @escaping (Value) async throws -> ValueTo
    ) -> MappedValuesReadOnlyStorage<Self, ValueTo> {
        return MappedValuesReadOnlyStorage(underlying: self, transform: transform)
    }
}

public struct MappedKeysReadOnlyStorage<Underlying: ReadableStorage, KeyFrom>: ReadOnlyStorage {
    public let underlying: Underlying
    public let transform: (KeyFrom) async throws -> Underlying.Key
    
    public init(underlying: Underlying, transform: @escaping (KeyFrom) async throws -> Underlying.Key) {
        self.underlying = underlying
        self.transform = transform
    }
    
    public func retrieve(forKey key: KeyFrom) async throws -> Underlying.Value {
        let originalKey = try await transform(key)
        return try await underlying.retrieve(forKey: originalKey)
    }
}

extension ReadOnlyStorage {
    public func mapKeys<KeyFrom>(
        to type: KeyFrom.Type = KeyFrom.self,
        _ transform: @escaping (KeyFrom) throws -> Key
    ) -> MappedKeysReadOnlyStorage<Self, KeyFrom> {
        return MappedKeysReadOnlyStorage(underlying: self, transform: transform)
    }
    
    public func singleKey(_ key: Key) -> MappedKeysReadOnlyStorage<Self, Void> {
        mapKeys({ key })
    }
}

public protocol NonFallibleReadableStorage<Key, Value>: StorageDesign {
    associatedtype Key
    associatedtype Value
    
    func retrieve(forKey key: Key) async -> Value
}

extension NonFallibleReadableStorage where Key == Void {
    public func retrieve() async -> Value {
        await retrieve(forKey: ())
    }
}

public struct RecoverableReadOnlyStorage<Underlying: ReadableStorage>: ReadOnlyStorage {
    public let underlying: Underlying
    public let recover: (Error) async throws -> Underlying.Value
    
    public init(underlying: Underlying, recover: @escaping (Error) async throws -> Underlying.Value) {
        self.underlying = underlying
        self.recover = recover
    }
    
    public func retrieve(forKey key: Underlying.Key) async throws -> Underlying.Value {
        do {
            return try await underlying.retrieve(forKey: key)
        } catch {
            return try await recover(error)
        }
    }
}

extension ReadOnlyStorage {
    public func recover(with recovery: @escaping (Error) async throws -> Value) -> RecoverableReadOnlyStorage<Self> {
        RecoverableReadOnlyStorage(underlying: self, recover: recovery)
    }
}

public struct RecoverableNonFallibleReadOnlyStorage<Underlying: ReadableStorage>: NonFallibleReadableStorage {
    public let underlying: Underlying
    public let recover: (Error) async -> Underlying.Value
    
    public init(underlying: Underlying, recover: @escaping (Error) async -> Underlying.Value) {
        self.underlying = underlying
        self.recover = recover
    }
    
    public func retrieve(forKey key: Underlying.Key) async -> Underlying.Value {
        do {
            return try await underlying.retrieve(forKey: key)
        } catch {
            return await recover(error)
        }
    }
}

extension ReadOnlyStorage {
    public func recover(with recovery: @escaping (Error) async -> Value) -> RecoverableNonFallibleReadOnlyStorage<Self> {
        RecoverableNonFallibleReadOnlyStorage(underlying: self, recover: recovery)
    }
    
    public func defaulting(to defaultValue: @autoclosure @escaping () -> Value) -> RecoverableNonFallibleReadOnlyStorage<Self> {
        recover(with: { _ in defaultValue() })
    }
}
