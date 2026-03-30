//
//  File.swift
//  
//
//  Created by Oleg on 7/11/24.
//

import Foundation

public final class DiskStorage: Storage, UpdateableStorage {
    
    /// Shared disk storage serializes disk access, meaning two disk operations will
    /// never run at the same time. This prevents race conditions
    public static let shared = DiskStorage(creatingDirectories: true)
    
    public typealias Key = URL
    public typealias Value = Data
    
    public var storageName: String {
        return "disk"
    }
    
    public let rawStorage: SerialStorage<RawDiskStorage>
    
    init(creatingDirectories: Bool = true) {
        self.rawStorage = RawDiskStorage(creatingDirectories: creatingDirectories)
            .serial()
    }
    
    public var _wrappedStorages: [any StorageDesign] {
        [rawStorage]
    }
    
    /// Creates a disk storage separate from `.shared`. Operations between this storage, `.shared` storage,
    /// and other detached disk storages can run in parallel, which can cause race conditions and unexpected failures.
    /// Use at your own risk
    ///
    /// - Parameters:
    ///   - creatingDirectories: if `true`, non-existing directories in provided `URLs` will get automatically
    ///     created. If `false`, such operations will fail instead
    ///
    /// - Warning: Operations between this storage, `.shared` storage, and other detached disk storages
    /// can run in parallel, which can cause race conditions and unexpected failures. Use at your own risk
    public static func detached(creatingDirectories: Bool = true) -> DiskStorage {
        DiskStorage(creatingDirectories: creatingDirectories)
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
