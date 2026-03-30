import Foundation
import Testing
@testable import AsyncStorages

@Test func storageDesignProvidesDefaultName() async throws {
    let storage = DefaultNamedStorage()

    #expect(storage.storageName.contains("DefaultNamedStorage"))
}

@Test func readOnlyPublicAPIsWork() async throws {
    let base = RecorderStorage(["1": 10], name: "base")
    let readOnly = ReadOnly(underlying: base)
    let mappedValues = MappedValuesReadOnlyStorage(underlying: readOnly) { value in
        "value-\(value)"
    }
    let mappedKeys = MappedKeysReadOnlyStorage(underlying: readOnly) { (key: Int) in
        String(key)
    }
    let recovered = RecoverableReadOnlyStorage(underlying: FailingReadOnlyStorage<Int, Int>()) { _ in
        42
    }
    let nonFallible = RecoverableNonFallibleReadOnlyStorage(underlying: FailingReadOnlyStorage<Int, Int>()) { _ in
        99
    }

    #expect(try await readOnly.retrieve(forKey: "1") == 10)
    #expect(try await mappedValues.retrieve(forKey: "1") == "value-10")
    #expect(try await mappedKeys.retrieve(forKey: 1) == 10)
    #expect(try await recovered.retrieve(forKey: 0) == 42)
    #expect(await nonFallible.retrieve(forKey: 0) == 99)

    let extensionMappedValues = readOnly.mapValues { $0 * 2 }
    let extensionMappedKeys = readOnly.mapKeys { (key: Int) in String(key) }
    let singleKey = readOnly.singleKey("1")
    let recoveredByExtension = readOnly.recover { _ in 7 }
    let defaulted = readOnly.defaulting(to: 8)

    #expect(try await extensionMappedValues.retrieve(forKey: "1") == 20)
    #expect(try await extensionMappedKeys.retrieve(forKey: 1) == 10)
    #expect(try await singleKey.retrieve() == 10)
    #expect(await recoveredByExtension.retrieve(forKey: "missing") == 7)
    #expect(await defaulted.retrieve(forKey: "missing") == 8)
}

@Test func writeOnlyPublicAPIsWork() async throws {
    let base = RecorderStorage<String, Int>(name: "base")
    let writeOnly = WriteOnly(underlying: base)
    let mappedValues = MappedValuesWriteOnlyStorage(underlying: writeOnly) { (value: String) in
        Int(value) ?? 0
    }
    let mappedKeys = MappedKeysWriteOnlyStorage(underlying: writeOnly) { (key: Int) in
        String(key)
    }

    try await writeOnly.set(1, forKey: "a")
    try await mappedValues.set("2", forKey: "b")
    try await mappedKeys.set(3, forKey: 3)

    let extensionMappedValues = writeOnly.mapValues { (value: String) in
        Int(value) ?? 0
    }
    let extensionMappedKeys = writeOnly.mapKeys { (key: Int) in String(key) }
    let singleKey = writeOnly.singleKey("fixed")

    try await extensionMappedValues.set("4", forKey: "d")
    try await extensionMappedKeys.set(5, forKey: 5)
    try await singleKey.set(6)

    #expect(try await base.retrieve(forKey: "a") == 1)
    #expect(try await base.retrieve(forKey: "b") == 2)
    #expect(try await base.retrieve(forKey: "3") == 3)
    #expect(try await base.retrieve(forKey: "d") == 4)
    #expect(try await base.retrieve(forKey: "5") == 5)
    #expect(try await base.retrieve(forKey: "fixed") == 6)
}

@Test func storagePublicAPIsWork() async throws {
    let readable = RecorderStorage(["a": 1], name: "readable")
    let writable = RecorderStorage<String, Int>(name: "writable")
    let composed = ComposedStorage(readable: readable, writable: writable)

    #expect(try await composed.retrieve(forKey: "a") == 1)
    try await composed.set(2, forKey: "b")
    #expect(try await writable.retrieve(forKey: "b") == 2)
    #expect(composed._wrappedStorages.count == 2)

    let transformed = readable.transformingStorages(
        readable: { $0.mapValues { "value-\($0)" } },
        writable: { $0.mapValues { Int($0) ?? 0 } }
    )
    try await transformed.set("3", forKey: "c")

    let mappedValues = readable.mapValues(
        to: String.self,
        mapTo: { "value-\($0)" },
        mapFrom: { Int($0.replacingOccurrences(of: "value-", with: "")) ?? 0 }
    )
    let mappedKeys = readable.mapKeys(to: Int.self) { _ in "a" }
    let singleKey = readable.singleKey("a")
    let recovered = readable.recover { _ in 77 }
    let defaulted = readable.defaulting(to: 88)

    try await mappedValues.set("value-4", forKey: "d")

    #expect(try await transformed.retrieve(forKey: "a") == "value-1")
    #expect(try await mappedValues.retrieve(forKey: "d") == "value-4")
    #expect(try await mappedKeys.retrieve(forKey: 1) == 1)
    #expect(try await singleKey.retrieve() == 1)
    #expect(await recovered.retrieve(forKey: "missing") == 77)
    #expect(await defaulted.retrieve(forKey: "missing") == 88)

    let throwingRecovered = readable.recover { _ throws in
        66
    }
    #expect(try await throwingRecovered.retrieve(forKey: "missing") == 66)
}

@Test func nonFallibleComposedStorageInitWorks() async throws {
    let readable = FailingReadOnlyStorage<String, Int>()
        .recover { _ in 12 }
    let writable = RecorderStorage<String, Int>(name: "writable")
    let storage = ComposedNonFallibleStorage(readable: readable, writable: writable)

    #expect(await storage.retrieve(forKey: "missing") == 12)

    try await storage.set(13, forKey: "value")
    #expect(try await writable.retrieve(forKey: "value") == 13)
}

@Test func compositionPublicAPIsWork() async throws {
    let front = RecorderStorage(["front": 1], name: "front")
    let back = RecorderStorage(["back": 2], name: "back")

    let backedReadOnly = BackedReadOnlyStorage(front: front.readOnly(), back: back.readOnly())
    let pushing = PushingWriteOnlyStorage(front: front.writeOnly(), back: back.writeOnly())
    let combined = CombinedStorage(front: front, back: back)
    let backed = BackedStorage(front: front, back: back)

    #expect(try await backedReadOnly.retrieve(forKey: "front") == 1)
    #expect(try await backedReadOnly.retrieve(forKey: "back") == 2)

    try await pushing.set(10, forKey: "pushed")
    #expect(try await front.retrieve(forKey: "pushed") == 10)
    #expect(try await back.retrieve(forKey: "pushed") == 10)

    try await combined.set(20, forKey: "combined")
    #expect(try await combined.retrieve(forKey: "combined") == 20)
    #expect(try await back.retrieve(forKey: "combined") == 20)

    #expect(try await backed.retrieve(forKey: "back") == 2)
    #expect(try await front.retrieve(forKey: "back") == 2)

    let extensionBacked = front.readOnly().backed(by: back.readOnly())
    let extensionPushing = front.writeOnly().pushing(to: back.writeOnly())
    let extensionCombined = front.combined(with: back)
    let extensionBackedStorage = front.backed(by: back)

    #expect(try await extensionBacked.retrieve(forKey: "front") == 1)
    try await extensionPushing.set(30, forKey: "extension")
    #expect(try await extensionCombined.retrieve(forKey: "extension") == 30)
    #expect(try await extensionBackedStorage.retrieve(forKey: "back") == 2)
}

@Test func serialStoragePublicAPIsWork() async throws {
    let base = RecorderStorage(["value": 1], name: "base")
    let serialStorage = SerialStorage(underlyingStorage: base)
    let serialReadOnly = SerialReadOnlyStorage(underlyingStorage: base.readOnly())
    let serialWriteOnly = SerialWriteOnlyStorage(underlyingStorage: base.writeOnly())

    #expect(try await serialStorage.retrieve(forKey: "value") == 1)
    try await serialStorage.set(2, forKey: "value")
    #expect(try await serialReadOnly.retrieve(forKey: "value") == 2)
    try await serialWriteOnly.set(3, forKey: "value")
    #expect(try await serialStorage.update(forKey: "value") { $0 += 1 } == 4)
    #expect(try await base.retrieve(forKey: "value") == 4)

    let storageViaExtension = base.serial()
    let readOnlyViaExtension = base.readOnly().serial()
    let writeOnlyViaExtension = base.writeOnly().serial()

    try await storageViaExtension.set(5, forKey: "value")
    #expect(try await readOnlyViaExtension.retrieve(forKey: "value") == 5)
    try await writeOnlyViaExtension.set(6, forKey: "value")
    #expect(try await base.retrieve(forKey: "value") == 6)
}

@Test func zipPublicAPIsWork() async throws {
    let lhs = RecorderStorage(["key": 1], name: "lhs")
    let rhs = RecorderStorage(["key": "one"], name: "rhs")

    let readOnlyZip = Zip2ReadOnlyStorage(storage1: lhs.readOnly(), storage2: rhs.readOnly())
    let writeOnlyZip = Zip2WriteOnlyStorage(storage1: lhs.writeOnly(), storage2: rhs.writeOnly())
    let storageZip = zip(lhs, rhs)

    #expect(try await readOnlyZip.retrieve(forKey: "key").0 == 1)
    #expect(try await readOnlyZip.retrieve(forKey: "key").1 == "one")

    try await writeOnlyZip.set((2, "two"), forKey: "key")
    #expect(try await lhs.retrieve(forKey: "key") == 2)
    #expect(try await rhs.retrieve(forKey: "key") == "two")

    #expect(try await storageZip.retrieve(forKey: "key") == (2, "two"))
    try await storageZip.set((3, "three"), forKey: "next")
    #expect(try await lhs.retrieve(forKey: "next") == 3)
    #expect(try await rhs.retrieve(forKey: "next") == "three")

    let readOnlyZipViaExtension = zip(lhs.readOnly(), rhs.readOnly())
    let writeOnlyZipViaExtension = zip(lhs.writeOnly(), rhs.writeOnly())

    #expect(try await readOnlyZipViaExtension.retrieve(forKey: "key") == (2, "two"))
    try await writeOnlyZipViaExtension.set((4, "four"), forKey: "zip")
    #expect(try await lhs.retrieve(forKey: "zip") == 4)
    #expect(try await rhs.retrieve(forKey: "zip") == "four")
}

@Test func storageWrapperPublicAPIsWork() async throws {
    let base = RecorderStorage<String, Int>(name: "base")
    let wrapped = base
        .mapValues(to: String.self, mapTo: { "\($0)" }, mapFrom: { Int($0) ?? 0 })
        .serial()

    let hierarchy = wrapped._storageHierarchy(indentationString: "--")

    #expect(hierarchy.contains("SerialStorage"))
    #expect(hierarchy.contains("base"))
    #expect(wrapped._reach(toFirst: RecorderStorage<String, Int>.self) != nil)
    #expect(wrapped._reachToFirst(whereNotNil: { $0.storageName == "base" ? $0.storageName : nil }) == "base")
    #expect(wrapped._reachToFirst(where: { $0.storageName == "base" }) != nil)
    #expect(wrapped.obscureWrappedStorages()._reach(toFirst: RecorderStorage<String, Int>.self) == nil)
}

@Test func storagesAsyncQueueRunsInFifoOrder() async throws {
    let queue = StoragesAsyncQueue()
    let recorder = OrderedRecorder<Int>()

    async let first: Int = queue.await {
        await recorder.append(1)
        try? await Task.sleep(for: .milliseconds(50))
        return 1
    }
    async let second: Int = queue.await {
        await recorder.append(2)
        return 2
    }

    #expect(await first == 1)
    #expect(await second == 2)
    #expect(await recorder.snapshot() == [1, 2])

    let asynchronousRecorder = OrderedRecorder<Int>()
    queue.async {
        await asynchronousRecorder.append(3)
    }
    _ = await queue.await {
        await asynchronousRecorder.append(4)
        return 4
    }
    #expect(await asynchronousRecorder.snapshot() == [3, 4])
}

@Test func shallowLogCanBeToggled() async throws {
    let original = ShallowsLog.isEnabled
    defer { ShallowsLog.isEnabled = original }

    ShallowsLog.isEnabled = true
    #expect(ShallowsLog.isEnabled)

    ShallowsLog.isEnabled = false
    #expect(!ShallowsLog.isEnabled)
}
