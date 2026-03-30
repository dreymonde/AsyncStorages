import Foundation
import Testing
@testable import AsyncStorages

@Test func rawDiskStoragePublicAPIsWork() async throws {
    let context = DiskTestContext()
    defer { context.cleanup() }

    let storage = RawDiskStorage()
    let fileURL = context.fileURL("nested/value.txt")
    let data = Data("hello".utf8)

    try await storage.set(data, forKey: fileURL)

    #expect(try await storage.retrieve(forKey: fileURL) == data)
    #expect(RawDiskStorage.directoryURL(of: fileURL) == fileURL.deletingLastPathComponent())
    #expect(storage._wrappedStorages.isEmpty)
}

@Test func rawDiskStorageWithoutDirectoryCreationFails() async throws {
    let context = DiskTestContext()
    defer { context.cleanup() }

    let storage = RawDiskStorage(creatingDirectories: false)
    let fileURL = context.fileURL("nested/value.txt")

    do {
        try await storage.set(Data("hello".utf8), forKey: fileURL)
        Issue.record("Expected `RawDiskStorage` to fail when directory creation is disabled.")
    } catch let error as RawDiskStorage.Error {
        if case .cantCreateFile = error {
            #expect(Bool(true))
        } else {
            Issue.record("Expected `.cantCreateFile`, got \(error).")
        }
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

@Test func diskStoragePublicAPIsWork() async throws {
    let context = DiskTestContext()
    defer { context.cleanup() }

    let storage = DiskStorage.detached()
    let fileURL = context.fileURL("file.bin")

    try await storage.set(Data([1, 2]), forKey: fileURL)
    let updated = try await storage.update(forKey: fileURL) { data in
        data.append(3)
    }

    #expect(updated == Data([1, 2, 3]))
    #expect(try await storage.retrieve(forKey: fileURL) == Data([1, 2, 3]))
    #expect(storage.storageName == "disk")
    #expect(storage._wrappedStorages.count == 1)
    #expect(DiskStorage.shared !== storage)
}

@Test func diskFolderStoragePublicAPIsWork() async throws {
    let context = DiskTestContext()
    defer { context.cleanup() }

    let folderURL = context.fileURL("folder")
    let diskStorage = DiskStorage.detached()
    let storage = DiskFolderStorage(
        folderURL: folderURL,
        diskStorage: diskStorage,
        filenameEncoder: .noEncoding
    )

    let fileURL = storage.fileURL(forFilename: "greeting")
    try await storage.set(Data("hello".utf8), forKey: "greeting")
    let updated = try await storage.update(forKey: "greeting") { data in
        data.append(Data(" world".utf8))
    }

    #expect(storage.storageName == "disk-folder-folder")
    #expect(fileURL == folderURL.appendingPathComponent("greeting"))
    #expect(try await storage.retrieve(forKey: "greeting") == Data("hello world".utf8))
    #expect(updated == Data("hello world".utf8))
    #expect(storage._wrappedStorages.count == 1)

    storage.clear()
    #expect(!FileManager.default.fileExists(atPath: folderURL.path))
}

@Test func diskFolderConvenienceFactoriesWork() async throws {
    let uniqueName = "AsyncStoragesTests-\(UUID().uuidString)"
    let detached = DiskStorage.detached()
    let folderFromInstance = detached.folder(uniqueName, in: .cachesDirectory, filenameEncoder: .noEncoding)
    let folderFromShared = DiskStorage.folder("\(uniqueName)-shared", in: .cachesDirectory, filenameEncoder: .noEncoding)
    defer {
        folderFromInstance.clear()
        folderFromShared.clear()
    }

    try await folderFromInstance.set(Data("instance".utf8), forKey: "value")
    try await folderFromShared.set(Data("shared".utf8), forKey: "value")

    #expect(folderFromInstance.folderURL.lastPathComponent == uniqueName)
    #expect(folderFromShared.folderURL.lastPathComponent == "\(uniqueName)-shared")
    #expect(try await folderFromInstance.retrieve(forKey: "value") == Data("instance".utf8))
    #expect(try await folderFromShared.retrieve(forKey: "value") == Data("shared".utf8))
    #expect(DiskFolderStorage.url(forFolder: uniqueName, in: .cachesDirectory).lastPathComponent == uniqueName)
}

@Test func filenamePublicAPIsWork() async throws {
    let filename = Filename(rawValue: "a+b/c")
    let literal: Filename = "literal"
    let custom = Filename.Encoder.custom { value in
        value.rawValue.uppercased()
    }

    #expect(filename.rawValue == "a+b/c")
    #expect(literal.rawValue == "literal")
    #expect(filename.base64Encoded() == Data("a+b/c".utf8).base64EncodedString())
    #expect(filename.base64URLEncoded() == "YStiL2M=")
    #expect(Filename.Encoder.noEncoding.encodedString(representing: filename) == "a+b/c")
    #expect(Filename.Encoder.base64URL.encodedString(representing: filename) == "YStiL2M=")
    #expect(custom.encodedString(representing: filename) == "A+B/C")
}

@Test func dataMappingPublicAPIsWork() async throws {
    let dataStorage = RecorderStorage<String, Data>(name: "data")
    let stringStorage = dataStorage.mapString()
    let jsonStorage = dataStorage.mapJSONDictionary()
    let objectStorage = dataStorage.mapJSONObject(UserProfile.self)
    let plistStorage = dataStorage.mapPlistDictionary()

    try await stringStorage.set("hello", forKey: "string")
    try await jsonStorage.set(["count": 2], forKey: "json")
    try await objectStorage.set(UserProfile(id: 7, name: "Taylor"), forKey: "object")
    try await plistStorage.set(["enabled": true], forKey: "plist")

    #expect(try await stringStorage.retrieve(forKey: "string") == "hello")

    let json = try await jsonStorage.retrieve(forKey: "json")
    #expect((json["count"] as? NSNumber)?.intValue == 2)

    #expect(try await objectStorage.retrieve(forKey: "object") == UserProfile(id: 7, name: "Taylor"))

    let plist = try await plistStorage.retrieve(forKey: "plist")
    #expect((plist["enabled"] as? NSNumber)?.boolValue == true)

    let readOnlyString = dataStorage.readOnly().mapString()
    let writeOnlyString = dataStorage.writeOnly().mapString()

    try await writeOnlyString.set("world", forKey: "read-write")
    #expect(try await readOnlyString.retrieve(forKey: "read-write") == "world")
}

@Test func filenameKeyMappingPublicAPIsWork() async throws {
    let storage = RecorderStorage<Filename, Data>(name: "filename-storage")
    let stringKeyStorage = storage.usingStringKeys().mapString()

    try await stringKeyStorage.set("hello", forKey: "greeting")

    #expect(try await stringKeyStorage.retrieve(forKey: "greeting") == "hello")
    #expect(try await storage.retrieve(forKey: Filename(rawValue: "greeting")) == Data("hello".utf8))

    let readOnly = storage.readOnly().usingStringKeys()
    let writeOnly = storage.writeOnly().usingStringKeys()
    try await writeOnly.set(Data("secondary".utf8), forKey: "second")
    #expect(try await readOnly.retrieve(forKey: "second") == Data("secondary".utf8))
}

@Test func decodingErrorAndStringPrintedPublicAPIsWork() async throws {
    let storage = RecorderStorage(["invalid": Data("not-json".utf8)], name: "invalid-json")
    let jsonStorage = storage.readOnly().mapJSON()
    let wrapper = StringPrinted(wrappedValue: Data("hello".utf8))
    let unwrapError = UnwrapError()

    #expect(wrapper.description == "hello")
    #expect(String(describing: type(of: unwrapError)) == "UnwrapError")

    do {
        _ = try await jsonStorage.retrieve(forKey: "invalid")
        Issue.record("Expected invalid JSON decoding to fail.")
    } catch let error as DecodingError<JSONSerialization> {
        #expect(error.originalData == Data("not-json".utf8))
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}
