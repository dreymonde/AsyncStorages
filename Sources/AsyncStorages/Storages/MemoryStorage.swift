//
//  File.swift
//  
//
//  Created by Oleg on 7/11/24.
//

import Foundation

struct DictionaryValueMissingForKey<Key: Hashable>: Error {
    let key: Key
}

final class MemoryStorage<Key: Hashable, Value>: UpdateableStorage {
    
    private var dictionary: ActorSafe<[Key: Value]>
    
    init(dictionary: [Key : Value] = [:]) {
        self.dictionary = ActorSafe(dictionary)
    }
    
    func retrieve(forKey key: Key) async throws -> Value {
        if let value = await dictionary.get()[key] {
            return value
        } else {
            throw DictionaryValueMissingForKey(key: key)
        }
    }
    
    func set(_ value: Value, forKey key: Key) async throws {
        await dictionary.write(with: { $0[key] = value })
    }
    
    func update(forKey key: Key, _ modify: @escaping (inout Value) -> ()) async throws -> Value {
        try await dictionary.write { dict in
            if var existing = dict[key] {
                modify(&existing)
                dict[key] = existing
                return existing
            } else {
                throw DictionaryValueMissingForKey(key: key)
            }
        }
    }
}
