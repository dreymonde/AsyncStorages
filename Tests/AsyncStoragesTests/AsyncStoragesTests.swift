import Testing
@testable import AsyncStorages

@Test func example() throws {
}

@Test func reachToFindsWrappedStorages() throws {
    let diskStorage = DiskStorage.folder("_test", in: .applicationSupportDirectory)
        .usingStringKeys()
        .mapJSON()
    let memoryStorage = MemoryStorage<String, Any>()
    let combinedStorage = memoryStorage.combined(with: diskStorage)

    print(combinedStorage._storageHierarchy())
    #expect(combinedStorage._reach(toFirst: DiskFolderStorage.self) != nil)
    #expect(combinedStorage._reach(toFirst: DiskStorage.self) != nil)
    #expect(combinedStorage._reach(toFirst: RawDiskStorage.self) != nil)
}

@Test func obscureHidesWrappedStorages() throws {
    let diskStorage = DiskStorage.folder("_test", in: .applicationSupportDirectory)
        .usingStringKeys()
        .mapJSON()
    let memoryStorage = MemoryStorage<String, Any>()
    let combinedStorage = memoryStorage.combined(with: diskStorage)
        .obscureWrappedStorages()

    print(combinedStorage._storageHierarchy())
    #expect(combinedStorage._reach(toFirst: DiskFolderStorage.self) == nil)
    #expect(combinedStorage._reach(toFirst: DiskStorage.self) == nil)
    #expect(combinedStorage._reach(toFirst: RawDiskStorage.self) == nil)
}
