//
//  File.swift
//  
//
//  Created by Oleg on 7/11/24.
//

import Foundation

public func zip<S1: ReadOnlyStorage, S2: ReadOnlyStorage>(
    _ lhs: S1,
    _ rhs: S2
) -> Zip2ReadOnlyStorage<S1, S2> where S1.Key == S2.Key {
    Zip2ReadOnlyStorage(storage1: lhs, storage2: rhs)
}

public func zip<S1: WriteOnlyStorage, S2: WriteOnlyStorage>(
    _ lhs: S1,
    _ rhs: S2
) -> Zip2WriteOnlyStorage<S1, S2> where S1.Key == S2.Key {
    Zip2WriteOnlyStorage(storage1: lhs, storage2: rhs)
}

public func zip<S1: Storage, S2: Storage>(
    _ lhs: S1,
    _ rhs: S2
) -> ComposedStorage<Zip2ReadOnlyStorage<ReadOnly<S1>, ReadOnly<S2>>, Zip2WriteOnlyStorage<WriteOnly<S1>, WriteOnly<S2>>> where S1.Key == S2.Key {
    lhs.transformingStorages(
        readable: { zip($0, rhs.readOnly()) },
        writable: { zip($0, rhs.writeOnly()) }
    )
}

public struct Zip2ReadOnlyStorage<S1: ReadOnlyStorage, S2: ReadOnlyStorage>: ReadOnlyStorage where S1.Key == S2.Key {
    
    public typealias Key = S1.Key
    public typealias Value = (S1.Value, S2.Value)
    
    public let storage1: S1
    public let storage2: S2
    
    public init(storage1: S1, storage2: S2) {
        self.storage1 = storage1
        self.storage2 = storage2
    }
    
    public func retrieve(forKey key: S1.Key) async throws -> (S1.Value, S2.Value) {
        async let value1 = await storage1.retrieve(forKey: key)
        async let value2 = await storage2.retrieve(forKey: key)
        return await (try value1, try value2)
    }
}

public struct Zip2WriteOnlyStorage<S1: WriteOnlyStorage, S2: WriteOnlyStorage>: WriteOnlyStorage where S1.Key == S2.Key {
    
    public typealias Key = S1.Key
    public typealias Value = (S1.Value, S2.Value)
    
    public let storage1: S1
    public let storage2: S2
    
    public init(storage1: S1, storage2: S2) {
        self.storage1 = storage1
        self.storage2 = storage2
    }
    
    public func set(_ value: (S1.Value, S2.Value), forKey key: S1.Key) async throws {
        async let setResult1: () = storage1.set(value.0, forKey: key)
        async let setResult2: () = storage2.set(value.1, forKey: key)
        _ = try await (setResult1, setResult2)
    }
}
