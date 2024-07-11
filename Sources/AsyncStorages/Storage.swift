//
//  File.swift
//  
//
//  Created by Oleg on 7/11/24.
//

import Foundation

public protocol StorageDesign {
    var storageName: String { get }
}

extension StorageDesign {
    public var storageName: String {
        return String(describing: Self.self)
    }
}

public protocol Storage<Key, Value>: ReadableStorage, WriteableStorage { }

public protocol UpdateableStorage<Key, Value>: Storage {
    @discardableResult
    func update(
        forKey key: Key,
        _ modify: @escaping (inout Value) -> ()
    ) async throws -> Value
}

public struct ComposedStorage<Readable: ReadableStorage, Writeable: WriteableStorage>: Storage where Readable.Key == Writeable.Key, Readable.Value == Writeable.Value {
    public let readable: Readable
    public let writeable: Writeable
    
    public init(readable: Readable, writeable: Writeable) {
        self.readable = readable
        self.writeable = writeable
    }
    
    public func retrieve(forKey key: Readable.Key) async throws -> Readable.Value {
        try await readable.retrieve(forKey: key)
    }
    
    public func set(_ value: Readable.Value, forKey key: Readable.Key) async throws {
        try await writeable.set(value, forKey: key)
    }
}

public extension Storage {
    func transformingStorages<NewReadable: ReadOnlyStorage, NewWriteable: WriteOnlyStorage>(
        readable: (ReadOnly<Self>) -> NewReadable,
        writeable: (WriteOnly<Self>) -> NewWriteable
    ) -> ComposedStorage<NewReadable, NewWriteable> where NewReadable.Key == NewWriteable.Key, NewReadable.Value == NewWriteable.Value {
        return ComposedStorage(readable: readable(readOnly()), writeable: writeable(writeOnly()))
    }
}

public extension Storage {
    func mapValues<OtherValue>(
        to type: OtherValue.Type = OtherValue.self,
        mapTo: @escaping (Value) async throws -> OtherValue,
        mapFrom: @escaping (OtherValue) async throws -> Value
    ) -> ComposedStorage<MappedValuesReadOnlyStorage<ReadOnly<Self>, OtherValue>, MappedValuesWriteOnlyStorage<WriteOnly<Self>, OtherValue>> {
        transformingStorages(
            readable: { $0.mapValues(mapTo) },
            writeable: { $0.mapValues(mapFrom) }
        )
    }
    
    func mapKeys<KeyFrom>(
        to type: KeyFrom.Type = KeyFrom.self,
        _ transform: @escaping (KeyFrom) throws -> Key
    ) -> ComposedStorage<MappedKeysReadOnlyStorage<ReadOnly<Self>, KeyFrom>, MappedKeysWriteOnlyStorage<WriteOnly<Self>, KeyFrom>> {
        transformingStorages(
            readable: { $0.mapKeys(transform) },
            writeable: { $0.mapKeys(transform) }
        )
    }
    
    func singleKey(_ key: Key) -> ComposedStorage<MappedKeysReadOnlyStorage<ReadOnly<Self>, Void>, MappedKeysWriteOnlyStorage<WriteOnly<Self>, Void>> {
        mapKeys({ key })
    }
}

public extension Storage {
    func recover(with recovery: @escaping (Error) async throws -> Value) -> some Storage<Key, Value> {
        transformingStorages(
            readable: { $0.recover(with: recovery) },
            writeable: { $0 }
        )
    }
}

public protocol NonFallibleStorage<Key, Value>: NonFallibleReadableStorage, WriteableStorage { }

public struct ComposedNonFallibleStorage<Readable: NonFallibleReadableStorage, Writeable: WriteableStorage>: NonFallibleStorage where Readable.Key == Writeable.Key, Readable.Value == Writeable.Value {
    public let readable: Readable
    public let writeable: Writeable
    
    public init(readable: Readable, writeable: Writeable) {
        self.readable = readable
        self.writeable = writeable
    }
    
    public func retrieve(forKey key: Readable.Key) async -> Readable.Value {
        await readable.retrieve(forKey: key)
    }
    
    public func set(_ value: Readable.Value, forKey key: Readable.Key) async throws {
        try await writeable.set(value, forKey: key)
    }
}

public extension Storage {
    func transformingStorages<NewReadable: NonFallibleReadableStorage, NewWriteable: WriteOnlyStorage>(
        readable: (ReadOnly<Self>) -> NewReadable,
        writeable: (WriteOnly<Self>) -> NewWriteable
    ) -> ComposedNonFallibleStorage<NewReadable, NewWriteable> where NewReadable.Key == NewWriteable.Key, NewReadable.Value == NewWriteable.Value {
        return ComposedNonFallibleStorage(readable: readable(readOnly()), writeable: writeable(writeOnly()))
    }
}

public extension Storage {
    func recover(with recovery: @escaping (Error) async -> Value) -> some NonFallibleStorage<Key, Value> {
        transformingStorages(
            readable: { $0.recover(with: recovery) },
            writeable: { $0 }
        )
    }
    
    func defaulting(to defaultValue: @autoclosure @escaping () -> Value) -> some NonFallibleStorage<Key, Value> {
        recover(with: { _ in defaultValue() })
    }
}
