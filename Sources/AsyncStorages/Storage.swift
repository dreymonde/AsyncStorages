//
//  File.swift
//  
//
//  Created by Oleg on 7/11/24.
//

import Foundation

// MARK: - StorageDesign

public protocol StorageDesign {
    var storageName: String { get }
}

extension StorageDesign {
    public var storageName: String {
        return String(describing: Self.self)
    }
}

// MARK: - Storage Protocols

public protocol Storage<Key, Value>: ReadableStorage, WritableStorage { }

public protocol UpdateableStorage<Key, Value>: Storage {
    @discardableResult
    func update(
        forKey key: Key,
        _ modify: @escaping (inout Value) -> ()
    ) async throws -> Value
}

// MARK: - Composed Storage

public struct ComposedStorage<Readable: ReadableStorage, Writable: WritableStorage>: Storage where Readable.Key == Writable.Key, Readable.Value == Writable.Value {
    public let readable: Readable
    public let writable: Writable
    
    public init(readable: Readable, writable: Writable) {
        self.readable = readable
        self.writable = writable
    }
    
    public func retrieve(forKey key: Readable.Key) async throws -> Readable.Value {
        try await readable.retrieve(forKey: key)
    }
    
    public func set(_ value: Readable.Value, forKey key: Readable.Key) async throws {
        try await writable.set(value, forKey: key)
    }
}

// MARK: - Storage Transformations

public extension Storage {
    func transformingStorages<NewReadable: ReadOnlyStorage, NewWritable: WriteOnlyStorage>(
        readable: (ReadOnly<Self>) -> NewReadable,
        writable: (WriteOnly<Self>) -> NewWritable
    ) -> ComposedStorage<NewReadable, NewWritable> where NewReadable.Key == NewWritable.Key, NewReadable.Value == NewWritable.Value {
        return ComposedStorage(readable: readable(readOnly()), writable: writable(writeOnly()))
    }
}

// MARK: Map

public extension Storage {
    func mapValues<OtherValue>(
        to type: OtherValue.Type = OtherValue.self,
        mapTo: @escaping (Value) async throws -> OtherValue,
        mapFrom: @escaping (OtherValue) async throws -> Value
    ) -> ComposedStorage<MappedValuesReadOnlyStorage<ReadOnly<Self>, OtherValue>, MappedValuesWriteOnlyStorage<WriteOnly<Self>, OtherValue>> {
        transformingStorages(
            readable: { $0.mapValues(mapTo) },
            writable: { $0.mapValues(mapFrom) }
        )
    }
    
    func mapKeys<KeyFrom>(
        to type: KeyFrom.Type = KeyFrom.self,
        _ transform: @escaping (KeyFrom) throws -> Key
    ) -> ComposedStorage<MappedKeysReadOnlyStorage<ReadOnly<Self>, KeyFrom>, MappedKeysWriteOnlyStorage<WriteOnly<Self>, KeyFrom>> {
        transformingStorages(
            readable: { $0.mapKeys(transform) },
            writable: { $0.mapKeys(transform) }
        )
    }
    
    func singleKey(_ key: Key) -> ComposedStorage<MappedKeysReadOnlyStorage<ReadOnly<Self>, Void>, MappedKeysWriteOnlyStorage<WriteOnly<Self>, Void>> {
        mapKeys({ key })
    }
}

// MARK: Recover

public extension Storage {
    func recover(with recovery: @escaping (Error) async throws -> Value) -> some Storage<Key, Value> {
        transformingStorages(
            readable: { $0.recover(with: recovery) },
            writable: { $0 }
        )
    }
}

// MARK: - Non-Fallible Storage

public protocol NonFallibleStorage<Key, Value>: NonFallibleReadableStorage, WritableStorage { }

public struct ComposedNonFallibleStorage<Readable: NonFallibleReadableStorage, Writable: WritableStorage>: NonFallibleStorage where Readable.Key == Writable.Key, Readable.Value == Writable.Value {
    public let readable: Readable
    public let writable: Writable
    
    public init(readable: Readable, writable: Writable) {
        self.readable = readable
        self.writable = writable
    }
    
    public func retrieve(forKey key: Readable.Key) async -> Readable.Value {
        await readable.retrieve(forKey: key)
    }
    
    public func set(_ value: Readable.Value, forKey key: Readable.Key) async throws {
        try await writable.set(value, forKey: key)
    }
}

public extension Storage {
    func transformingStorages<NewReadable: NonFallibleReadableStorage, NewWritable: WriteOnlyStorage>(
        readable: (ReadOnly<Self>) -> NewReadable,
        writable: (WriteOnly<Self>) -> NewWritable
    ) -> ComposedNonFallibleStorage<NewReadable, NewWritable> where NewReadable.Key == NewWritable.Key, NewReadable.Value == NewWritable.Value {
        return ComposedNonFallibleStorage(readable: readable(readOnly()), writable: writable(writeOnly()))
    }
}

public extension Storage {
    func recover(with recovery: @escaping (Error) async -> Value) -> some NonFallibleStorage<Key, Value> {
        transformingStorages(
            readable: { $0.recover(with: recovery) },
            writable: { $0 }
        )
    }
    
    func defaulting(to defaultValue: @autoclosure @escaping () -> Value) -> some NonFallibleStorage<Key, Value> {
        recover(with: { _ in defaultValue() })
    }
}
