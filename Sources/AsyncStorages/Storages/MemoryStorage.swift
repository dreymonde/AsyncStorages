//
//  File.swift
//  
//
//  Created by Oleg on 7/11/24.
//

import Foundation

public struct MemoryStorageValueMissingForKey<Key: Hashable>: Error {
    public let key: Key
    
    public init(key: Key) {
        self.key = key
    }
}

public final class MemoryStorage<Key: Hashable, Value>: UpdateableStorage {
    
    private var dictionary: ActorSafe<[Key: Value]>
    
    public init(dictionary: [Key : Value] = [:]) {
        self.dictionary = ActorSafe(dictionary)
    }
    
    public func retrieve(forKey key: Key) async throws -> Value {
        if let value = await dictionary.get()[key] {
            return value
        } else {
            throw MemoryStorageValueMissingForKey(key: key)
        }
    }
    
    public func set(_ value: Value, forKey key: Key) async throws {
        await dictionary.write(with: { $0[key] = value })
    }
    
    @discardableResult
    public func update(forKey key: Key, _ modify: @escaping (inout Value) -> ()) async throws -> Value {
        try await dictionary.write { dict in
            if var existing = dict[key] {
                modify(&existing)
                dict[key] = existing
                return existing
            } else {
                throw MemoryStorageValueMissingForKey(key: key)
            }
        }
    }
    
    public var _wrappedStorages: [any StorageDesign] {
        []
    }
}
