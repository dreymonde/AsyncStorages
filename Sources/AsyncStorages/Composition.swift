//
//  File.swift
//  
//
//  Created by Oleg on 7/11/24.
//

import Foundation

extension ReadOnlyStorage {
    /// Creates a read-only storage that falls back to another storage when this one fails to retrieve a value.
    ///
    /// The original error from `self` is preserved if the fallback storage also fails.
    ///
    /// - Parameter storage: The fallback storage to query after this storage misses.
    /// - Returns: A storage that reads from `self` first and then from `storage`.
    public func backed<Readable: ReadableStorage>(by storage: Readable) -> BackedReadOnlyStorage<Self, Readable> where Readable.Key == Key, Readable.Value == Value {
        return BackedReadOnlyStorage(front: self, back: storage)
    }
}

extension WritableStorage {
    /// Creates a write-only storage that forwards every write to both storages.
    ///
    /// Writes are performed on `self` first, then on `storage`.
    ///
    /// - Parameter storage: The secondary storage that also receives each write.
    /// - Returns: A storage that duplicates writes to both destinations.
    public func pushing<Back : WritableStorage>(to storage: Back) -> PushingWriteOnlyStorage<Self, Back> where Back.Key == Key, Back.Value == Value {
        PushingWriteOnlyStorage(front: self, back: storage)
    }
}

extension Storage {
    /// Creates a storage that reads through a backing storage and writes to both storages.
    ///
    /// Reads prefer `self` and fall back to `backStorage`. Writes are sent to both storages.
    ///
    /// - Parameter backStorage: The secondary storage used for read fallback and mirrored writes.
    /// - Returns: A combined storage built from the two storages.
    public func combined<Back: Storage>(with backStorage: Back) -> CombinedStorage<Self, Back> where Back.Key == Key, Back.Value == Value {
        CombinedStorage(front: self, back: backStorage)
    }
    
    /// Creates a storage that falls back to another storage for reads while keeping writes local.
    ///
    /// When a value is found in the backing storage, this storage attempts to cache it into `self`
    /// before returning it.
    ///
    /// - Parameter backStorage: The storage to query after `self` fails to retrieve a value.
    /// - Returns: A storage that reads from `self` first and writes only to `self`.
    public func backed<Back: ReadableStorage>(by backStorage: Back) -> BackedStorage<Self, Back> where Back.Key == Key, Back.Value == Value {
        BackedStorage(front: self, back: backStorage)
    }
}

public struct BackedReadOnlyStorage<Front: ReadOnlyStorage, Back: ReadableStorage>: ReadOnlyStorage where Front.Key == Back.Key, Front.Value == Back.Value {
    
    public typealias Key = Front.Key
    public typealias Value = Front.Value
    
    public let front: Front
    public let back: Back
    
    public init(front: Front, back: Back) {
        self.front = front
        self.back = back
    }
    
    public func retrieve(forKey key: Key) async throws -> Value {
        do {
            return try await front.retrieve(forKey: key)
        } catch let firstError {
            shallows_print("Storage (\(front.storageName)) miss for key: \(key). Attempting to retrieve from \(back.storageName)")
            do {
                return try await back.retrieve(forKey: key)
            } catch {
                throw firstError
            }
        }
    }
    
    public var _wrappedStorages: [any StorageDesign] {
        [front, back]
    }
}

public struct PushingWriteOnlyStorage<Front: WritableStorage, Back: WritableStorage>: WriteOnlyStorage where Front.Key == Back.Key, Front.Value == Back.Value {
    
    public typealias Key = Front.Key
    public typealias Value = Front.Value
    
    public let front: Front
    public let back: Back
    
    public init(front: Front, back: Back) {
        self.front = front
        self.back = back
    }
    
    public func set(_ value: Front.Value, forKey key: Front.Key) async throws {
        try await front.set(value, forKey: key)
        try await back.set(value, forKey: key)
    }
    
    public var _wrappedStorages: [any StorageDesign] {
        [front, back]
    }
}

public struct CombinedStorage<Front: Storage, Back: Storage>: Storage where Front.Key == Back.Key, Front.Value == Back.Value {
    public typealias Key = Front.Key
    public typealias Value = Front.Value
    
    public let front: Front
    public let backed: BackedStorage<Front, Back>
    
    public init(front: Front, back: Back) {
        self.front = front
        self.backed = front.backed(by: back)
    }
    
    public func retrieve(forKey key: Front.Key) async throws -> Front.Value {
        try await backed.retrieve(forKey: key)
    }
    
    public func set(_ value: Front.Value, forKey key: Front.Key) async throws {
        try await front.set(value, forKey: key)
        try await backed.back.set(value, forKey: key)
    }
    
    public var _wrappedStorages: [any StorageDesign] {
        [front, backed.back]
    }
}

public struct BackedStorage<Front: Storage, Back: ReadableStorage>: Storage where Front.Key == Back.Key, Front.Value == Back.Value {
    public typealias Key = Front.Key
    public typealias Value = Front.Value
    
    public let front: Front
    public let back: Back
    
    public init(front: Front, back: Back) {
        self.front = front
        self.back = back
    }
    
    public func retrieve(forKey key: Front.Key) async throws -> Front.Value {
        do {
            return try await front.retrieve(forKey: key)
        } catch let firstError {
            shallows_print("Storage (\(front.storageName)) miss for key: \(key). Attempting to retrieve from \(back.storageName)")
            do {
                let backed = try await back.retrieve(forKey: key)
                do {
                    try await self.set(backed, forKey: key)
                } catch {
                    shallows_print("Storage (\(front.storageName) failed to set backed value from \(back.storageName). returning value anyway")
                }
                return backed
            } catch {
                throw firstError
            }
        }
    }
    
    public func set(_ value: Front.Value, forKey key: Front.Key) async throws {
        try await front.set(value, forKey: key)
    }
    
    public var _wrappedStorages: [any StorageDesign] {
        [front, back]
    }
}
