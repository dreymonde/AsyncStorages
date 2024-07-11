//
//  File.swift
//  
//
//  Created by Oleg on 7/11/24.
//

import Foundation

public final class DiskStorage: Storage, UpdateableStorage {
    
    public static let shared = DiskStorage(creatingDirectories: true)
    
    public typealias Key = URL
    public typealias Value = Data
    
    public var storageName: String {
        return "disk"
    }
    
    public let rawStorage: SerialStorage<RawDiskStorage>
    
    public init(creatingDirectories: Bool = true) {
        self.rawStorage = RawDiskStorage(creatingDirectories: creatingDirectories)
            .serial()
    }
    
    public func retrieve(forKey key: URL) async throws -> Data {
        try await rawStorage.retrieve(forKey: key)
    }
    
    public func set(_ value: Data, forKey key: URL) async throws {
        try await rawStorage.set(value, forKey: key)
    }
    
    public func update(forKey key: URL, _ modify: @escaping (inout Data) -> ()) async throws -> Data {
        try await rawStorage.update(forKey: key, modify)
    }
}
