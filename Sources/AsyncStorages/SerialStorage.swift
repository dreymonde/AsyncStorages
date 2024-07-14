//
//  File.swift
//  
//
//  Created by Oleg on 7/11/24.
//

import Foundation

extension Storage {
    public func serial() -> SerialStorage<Self> {
        return SerialStorage(underlyingStorage: self)
    }
}

extension ReadOnlyStorage {
    public func serial() -> SerialReadOnlyStorage<Self> {
        return SerialReadOnlyStorage(underlyingStorage: self)
    }
}

extension WriteOnlyStorage {
    public func serial() -> SerialWriteOnlyStorage<Self> {
        return SerialWriteOnlyStorage(underlyingStorage: self)
    }
}

public final class SerialStorage<Underlying: Storage>: UpdateableStorage {
    public let underlyingStorage: Underlying
    public let asyncQueue = StoragesAsyncQueue()
    
    public var storageName: String {
        "serial-\(underlyingStorage.storageName)"
    }
    
    public init(underlyingStorage: Underlying) {
        self.underlyingStorage = underlyingStorage
    }
    
    public func retrieve(forKey key: Underlying.Key) async throws -> Underlying.Value {
        try await asyncQueue.await {
            try await self.underlyingStorage.retrieve(forKey: key)
        }
    }
    
    public func set(_ value: Underlying.Value, forKey key: Underlying.Key) async throws {
        try await asyncQueue.await {
            try await self.underlyingStorage.set(value, forKey: key)
        }
    }
    
    @discardableResult
    public func update(
        forKey key: Underlying.Key,
        _ modify: @escaping (inout Underlying.Value) -> ()
    ) async throws -> Underlying.Value {
        try await asyncQueue.await {
            var value = try await self.retrieve(forKey: key)
            modify(&value)
            try await self.set(value, forKey: key)
            return value
        }
    }
}

public final class SerialReadOnlyStorage<Underlying: ReadableStorage>: ReadOnlyStorage {
    public let underlyingStorage: Underlying
    public let asyncQueue = StoragesAsyncQueue()
    
    public var storageName: String {
        "serial-\(underlyingStorage.storageName)"
    }
    
    public init(underlyingStorage: Underlying) {
        self.underlyingStorage = underlyingStorage
    }
    
    public func retrieve(forKey key: Underlying.Key) async throws -> Underlying.Value {
        try await asyncQueue.await {
            try await self.underlyingStorage.retrieve(forKey: key)
        }
    }
}

public final class SerialWriteOnlyStorage<Underlying: WritableStorage>: WriteOnlyStorage {
    public let underlyingStorage: Underlying
    public let asyncQueue = StoragesAsyncQueue()
    
    public var storageName: String {
        "serial-\(underlyingStorage.storageName)"
    }
    
    public init(underlyingStorage: Underlying) {
        self.underlyingStorage = underlyingStorage
    }
    
    public func set(_ value: Underlying.Value, forKey key: Underlying.Key) async throws {
        try await asyncQueue.await {
            try await self.underlyingStorage.set(value, forKey: key)
        }
    }
}
