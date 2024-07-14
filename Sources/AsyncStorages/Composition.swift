//
//  File.swift
//  
//
//  Created by Oleg on 7/11/24.
//

import Foundation

extension ReadOnlyStorage {
    public func backed<Readable: ReadableStorage>(by storage: Readable) -> BackedReadOnlyStorage<Self, Readable> where Readable.Key == Key, Readable.Value == Value {
        return BackedReadOnlyStorage(front: self, back: storage)
    }
}

extension WritableStorage {
    public func pushing<Back : WritableStorage>(to storage: Back) -> PushingWriteOnlyStorage<Self, Back> where Back.Key == Key, Back.Value == Value {
        PushingWriteOnlyStorage(front: self, back: storage)
    }
}

extension Storage {
    public func combined<Back: Storage>(with backStorage: Back) -> CombinedStorage<Self, Back> where Back.Key == Key, Back.Value == Value {
        CombinedStorage(front: self, back: backStorage)
    }
    
    public func backed<Back: Storage>(by backStorage: Back) -> BackedStorage<Self, Back> where Back.Key == Key, Back.Value == Value {
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
    
    public var storageName: String {
        "\(front.storageName)<-\(back.storageName)"
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
    
    public var storageName: String {
        "\(front.storageName)->\(back.storageName)"
    }
    
    public func set(_ value: Front.Value, forKey key: Front.Key) async throws {
        try await front.set(value, forKey: key)
        try await back.set(value, forKey: key)
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

    public var storageName: String {
        "\(front.storageName)<->\(backed.back.storageName)"
    }
    
    public func retrieve(forKey key: Front.Key) async throws -> Front.Value {
        try await backed.retrieve(forKey: key)
    }
    
    public func set(_ value: Front.Value, forKey key: Front.Key) async throws {
        try await front.set(value, forKey: key)
        try await backed.back.set(value, forKey: key)
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

    public var storageName: String {
        "\(front.storageName)<-\(back.storageName)"
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
}
