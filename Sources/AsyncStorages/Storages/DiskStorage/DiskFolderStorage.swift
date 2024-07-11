//
//  File.swift
//  
//
//  Created by Oleg on 7/11/24.
//

import Foundation

extension DiskStorage {
    public func folder(
        _ folderName: String,
        in directory: FileManager.SearchPathDirectory,
        domainMask: FileManager.SearchPathDomainMask = .userDomainMask,
        filenameEncoder: Filename.Encoder
    ) -> DiskFolderStorage {
        let directoryURL = DiskFolderStorage.url(forFolder: folderName, in: directory, domainMask: domainMask)
        return DiskFolderStorage(folderURL: directoryURL, diskStorage: self, filenameEncoder: filenameEncoder)
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
        self.storageName = "disk-\(folderURL.lastPathComponent)"
    }
    
    deinit {
        if clearsOnDeinit {
            clear()
        }
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
