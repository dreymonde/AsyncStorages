//
//  File.swift
//  
//
//  Created by Oleg on 7/11/24.
//

import Foundation

extension DiskStorage {
    /// Creates a disk folder storage pointing to a specified folder
    ///
    /// - Note: `DiskFolderStorage` uses `Filename` as keys. If you need to use `String`
    /// as a key instead, call `usingStringKeys()` to map to `Storage<String, Data>`
    ///
    /// - Parameters:
    ///   - folderName: This folder will be created inside `directory`. Make sure it is a valid name
    ///   - directory: See `FileManager.SearchPathDirectory` for reference
    ///   - domainMask: `.userDomainMask` by default
    ///   - filenameEncoder: `Filename.Encoder` instance used to encode filenames
    ///   into a disk-safe string. `.base64URL` encoder is used by default
    public func folder(
        _ folderName: String,
        in directory: FileManager.SearchPathDirectory,
        domainMask: FileManager.SearchPathDomainMask = .userDomainMask,
        filenameEncoder: Filename.Encoder = .base64URL
    ) -> DiskFolderStorage {
        let directoryURL = DiskFolderStorage.url(forFolder: folderName, in: directory, domainMask: domainMask)
        return DiskFolderStorage(folderURL: directoryURL, diskStorage: self, filenameEncoder: filenameEncoder)
    }
    
    /// Creates a disk folder storage pointing to a specified folder
    ///
    /// - Note: `DiskFolderStorage` uses `Filename` as keys. If you need to use `String`
    /// as a key instead, call `usingStringKeys()` to map to `Storage<String, Data>`
    ///
    /// - Parameters:
    ///   - folderName: This folder will be created inside `directory`. Make sure it is a valid name
    ///   - directory: See `FileManager.SearchPathDirectory` for reference
    ///   - domainMask: `.userDomainMask` by default
    ///   - filenameEncoder: `Filename.Encoder` instance used to encode filenames
    ///   into a disk-safe string. `.base64URL` encoder is used by default
    public static func folder(
        _ folderName: String,
        in directory: FileManager.SearchPathDirectory,
        domainMask: FileManager.SearchPathDomainMask = .userDomainMask,
        filenameEncoder: Filename.Encoder = .base64URL
    ) -> DiskFolderStorage {
        DiskStorage.shared.folder(folderName, in: directory, domainMask: domainMask, filenameEncoder: filenameEncoder)
    }
}

public final class DiskFolderStorage: UpdateableStorage {
    
    public typealias Key = Filename
    public typealias Value = Data
    
    public let storageName: String
    public let folderURL: URL
    
    public let diskStorage: any UpdateableStorage<URL, Data>
    
    public let filenameEncoder: Filename.Encoder
    
    public var clearsOnDeinit = false
    
    public init(folderURL: URL,
                diskStorage: any UpdateableStorage<URL, Data>,
                filenameEncoder: Filename.Encoder) {
        self.diskStorage = diskStorage
        self.folderURL = folderURL
        self.filenameEncoder = filenameEncoder
        self.storageName = "disk-folder-\(folderURL.lastPathComponent)"
    }
    
    deinit {
        if clearsOnDeinit {
            clear()
        }
    }
    
    public var _wrappedStorages: [any StorageDesign] {
        [diskStorage]
    }
    
    public func clear() {
        do {
            try FileManager.default.removeItem(at: folderURL)
        } catch { }
    }
    
    public func fileURL(forFilename filename: Filename) -> URL {
        let finalForm = filenameEncoder.encodedString(representing: filename)
        return folderURL.appendingPathComponent(finalForm)
    }
    
    public func retrieve(forKey filename: Filename) async throws -> Data {
        let fileURL = self.fileURL(forFilename: filename)
        return try await diskStorage.retrieve(forKey: fileURL)
    }
    
    public func set(_ data: Data, forKey filename: Filename) async throws {
        let fileURL = self.fileURL(forFilename: filename)
        try await diskStorage.set(data, forKey: fileURL)
    }
    
    public func update(forKey filename: Filename, _ modify: @escaping (inout Data) -> ()) async throws -> Data {
        let fileURL = self.fileURL(forFilename: filename)
        return try await diskStorage.update(forKey: fileURL, modify)
    }
}

extension URL {
    
    fileprivate init(directory: FileManager.SearchPathDirectory, domainMask: FileManager.SearchPathDomainMask = .userDomainMask) {
        let urls = FileManager.default.urls(for: directory, in: domainMask)
        self = urls[0]
    }
    
}

extension DiskFolderStorage {
    
    public static func url(forFolder folderName: String, in directory: FileManager.SearchPathDirectory, domainMask: FileManager.SearchPathDomainMask = .userDomainMask) -> URL {
        let folderURL = URL(directory: directory, domainMask: domainMask).appendingPathComponent(folderName, isDirectory: true)
        return folderURL
    }
}
