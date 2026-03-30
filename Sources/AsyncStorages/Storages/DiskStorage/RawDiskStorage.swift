//
//  File.swift
//  
//
//  Created by Oleg on 7/11/24.
//

import Foundation

/// Using `RawDiskStorage` is not recommended. For most scenarios, use `DiskStorage`
///
/// - Warning: `RawDiskStorage` provides no serialization of operations,
/// so race conditions are a serious risk. `DiskStorage` wraps `RawDiskStorage`
/// to `.serial()` to prevent this. Using `RawDiskStorage` is not recommended
/// unless you now exactly what you're doing
public final class RawDiskStorage: Storage {
    
    public typealias Key = URL
    public typealias Value = Data
    
    public var storageName: String {
        return "raw-disk"
    }
    
    private let fileManager = FileManager.default
    
    internal let creatingDirectories: Bool
    
    /// Using `RawDiskStorage` is not recommended. For most scenarios, use `DiskStorage`
    ///
    /// - Warning: `RawDiskStorage` provides no serialization of operations,
    /// so race conditions are a serious risk. `DiskStorage` wraps `RawDiskStorage`
    /// to `.serial()` to prevent this. Using `RawDiskStorage` is not recommended
    /// unless you now exactly what you're doing
    public init(creatingDirectories: Bool = true) {
        self.creatingDirectories = creatingDirectories
    }
    
    public func retrieve(forKey key: URL) async throws -> Data {
        let data = try Data.init(contentsOf: key)
        return data
    }
    
    public enum Error : Swift.Error {
        case cantCreateFile
        case cantCreateDirectory(Swift.Error)
    }
    
    public func set(_ value: Data, forKey key: URL) async throws {
        try self.createDirectoryURLIfNotExisting(for: key)
        let path = key.path
        if self.fileManager.createFile(atPath: path,
                                       contents: value,
                                       attributes: nil) {
            return
        } else {
            throw Error.cantCreateFile
        }
    }
    
    public static func directoryURL(of fileURL: URL) -> URL {
        return fileURL.deletingLastPathComponent()
    }
    
    fileprivate func createDirectoryURLIfNotExisting(for fileURL: URL) throws {
        guard creatingDirectories else {
            return
        }
        let directoryURL = RawDiskStorage.directoryURL(of: fileURL)
        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL,
                                                withIntermediateDirectories: true,
                                                attributes: nil)
            } catch {
                throw Error.cantCreateDirectory(error)
            }
        }
    }
    
    public var _wrappedStorages: [any StorageDesign] {
        []
    }
}
