# AsyncStorages

**AsyncStorages** is a generic abstraction layer over lightweight data storage and persistence. It provides a `Storage<Key, Value>` type, instances of which can be easily transformed and composed with each other. It gives you an ability to create highly sophisticated, effective and reliable caching/persistence and even networking solutions.

**AsyncStorages** is a Swift Concurrency-era successor of **[Shallows](https://github.com/dreymonde/Shallows)**, which in turn is deeply inspired by [Carlos][carlos-github-url] and [this amazing talk][composable-caches-in-swift-url] by [Brandon Kase][brandon-kase-twitter-url].

**AsyncStorages** is a really small, component-based project, so if you need an even more controllable solution – build one yourself! The source code is there to help.

## Usage

```swift
import AsyncStorages

struct City: Codable {
    let name: String
    let foundationYear: Int
}

let diskStorage = DiskStorage
    .folder("cities", in: .cachesDirectory)
    .usingStringKeys()
    .mapJSONObject(City.self)

let cachedStorage = MemoryStorage<String, City>()
    .combined(with: diskStorage)

let kharkiv = City(name: "Kharkiv", foundationYear: 1654)
try await cachedStorage.set(kharkiv, forKey: "kharkiv")

let city = try await cachedStorage.retrieve(forKey: "kharkiv")
print(city)
```

## Guide

The core types in **AsyncStorages** are:

- `ReadOnlyStorage<Key, Value>`
- `WriteOnlyStorage<Key, Value>`
- `Storage<Key, Value>`

`Storage` is just a type that can both retrieve and set values:

```swift
let storage = MemoryStorage<String, Int>()

try await storage.set(10, forKey: "some-key")
let value = try await storage.retrieve(forKey: "some-key")
print(value)
```

### Transforms

Keys and values can be mapped without changing the underlying storage:

```swift
let rawImages = DiskStorage
    .folder("images", in: .cachesDirectory) // Storage<Filename, Data>

let images = rawImages
    .mapValues(to: UIImage.self,
               mapTo: { data in try UIImage(data: data).unwrap() },
               mapFrom: { image in try UIImagePNGRepresentation(image).unwrap() }) // Storage<Filename, UIImage>
```

You can also remap keys:

```swift
enum ImageKey: String {
    case kitten
    case puppy
}

let keyedImages = images
    .usingStringKeys()
    .mapKeys(to: ImageKeys.self, \.rawValue) // Storage<ImageKey, UIImage>
```

The most useful transforms on storages are:

- `.mapValues(to:mapTo:mapFrom:)`
- `.mapKeys(to:_:)`
- `.singleKey(_:)`
- `.transformingStorages(readable:writable:)`

Read-only and write-only storages also have their own `.mapValues`, `.mapKeys`, and `.singleKey` variants.

For storages with `Value == Data`, several convenience transforms are available:

- `.mapString(withEncoding:)`
- `.mapJSON()`
- `.mapJSONDictionary()`
- `.mapJSONObject(_:)`
- `.mapPlist(format:readOptions:writeOptions:)`
- `.mapPlistDictionary(format:readOptions:writeOptions:)`
- `.mapPlistObject(_:)`

For storages with `Key == Filename`, you can call `.usingStringKeys()` to get a string-keyed view.

### Composition

Another core concept of **AsyncStorages** is composition. Hitting a disk every time you request an image can be slow and inefficient. Instead, you can compose `MemoryStorage` and `DiskStorage`:

```swift
let memory = MemoryStorage<String, City>()
let disk = DiskStorage
    .folder("cities", in: .cachesDirectory)
    .usingStringKeys()
    .mapJSONObject(City.self)

let storage = memory.combined(with: disk)
```

`combined(with:)` does three things:

1. Reads from the front storage first.
2. Falls back to the back storage if the front misses, then pushes the retrieved value into the front storage.
3. Writes to both storages.

Other composition APIs:

- `.backed(by:)` will work the same as `combined(with:)`, but it will not push the value to the back storage. Also available for `ReadOnlyStorage`
- `.pushing(to:)` will not retrieve the value from the back storage, but will push to it on `set`. Also available for `WriteOnlyStorage`

### Read-only and write-only storages

If you don't want to expose writing to your storage, you can make it a read-only storage:

```swift
let readOnly = storage.readOnly() // ReadOnlyStorage<Key, Value>
```

Read-only storages can also be mapped and composed:

```swift
let immutableFileStorage = DiskStorage.folder("immutable", in: .applicationSupportDirectory)
    .mapString(withEncoding: .utf8)
    .readOnly()
let storage = MemoryStorage<Filename, String>()
    .backed(by: immutableFileStorage)
    .readOnly() // ReadOnlyStorage<Filename, String>
```

Write-only storages are available in a similar way

```swift
let writeOnly = storage.writeOnly() // WriteOnlyStorage<Key, Value>
```

### Single element storage

You can have a storage with keys `Void`. That means that you can store only one element there. **Shallows** provides a convenience `.singleKey` method to create it:

```swift
let settingsStorage = DiskStorage.folder("settings", in: .applicationSupportDirectory)
    .mapJSONDictionary()
    .singleKey("settings") // Storage<Void, [String: Any]>
let settings = try await settingsStorage.retrieve()
```

### Updateable storages & serialized access

All storages are concurrent by default, which means they are not protected from data races. This means that doing this:

```swift
var currentUser = try await userStorage.retrieve(forKey: "123")
currentUser.isActive = true
try await userStorage.set(currentUser)
```

Is not a good idea: there is no guarantee that this user value was not modified elsewhere before your `set` operation.

To protect your storages from race conditions, you must make them _serial_, which means that every read/write operation will be executed in FIFO order (first in, first out):

```swift
let serialUserStorage = userStorage.serial() // SerialStorage
```

`SerialStorage` conforms to `UpdateableStorage`, which means that now you can perform safe update operations that are protected from race conditions:

```swift
try await serialUserStorage.update(forKey: "123") { user in
    user.isActive = true
}
```

`DiskStorage`, `DiskFolderStorage` & `MemoryStorage` all also conform to `UpdateableStorage`

### Recovering from errors

You can protect your storage instance from failures using `defaulting(to:)` or `recover` methods:

```swift
let memoryStorage = MemoryStorage<String, Int>()

let defaulting = memoryStorage.defaulting(to: 0)
let protected = memoryStorage.recover { error in
    switch error {
    case is MemoryStorageValueMissingForKey<String>:
        return 15
    default:
        return -1
    }
}
```

There are two recovery families:

- `recover(with:)` returning a fallible storage
- `recover(with:)` returning a non-fallible storage
- `defaulting(to:)` for a simple default value

These work on both `Storage` and `ReadOnlyStorage`.

Error recovery is _especially_ useful when using `update` method:

```swift
let storage = MemoryStorage<String, [Int]>()
try await storage
    .defaulting(to: [])
    .serial()
    .update(forKey: "first") {
        $0.append(10)
    }
```


### Disk storage

Typical usage starts with `DiskFolderStorage`:

```swift
let texts = DiskStorage
    .folder("texts", in: .applicationSupportDirectory)
    .usingStringKeys()
    .mapString() // some Storage<String, String>

try await texts.set("Hello", forKey: "greeting")
let value = try await texts.retrieve(forKey: "greeting")
```

`DiskStorage.shared` is the default serialized disk storage. If you need an isolated instance, use:

```swift
let disk = DiskStorage.detached()
```

`RawDiskStorage` exists for lower-level use cases, but it does not serialize access, so use it carefully.

### HTTP networking as storage (URLSessionStorage)

On Apple platforms, **AsyncStorages** includes `URLSessionStorage`, a read-only storage that turns requests into responses:

```swift
let network = URLSessionStorage.shared
let response = try await network.retrieve(forKey: URL(string: "https://example.com")!)
print(response.httpUrlResponse.statusCode)
print(response.data)
```

Convenience adapters are provided:

- `.mapURLKeys()` to turn `Request` keys into plain `URL`
- `.mapURLRequestKeys()` to turn `Request` keys into `URLRequest`
- `.mapStringKeys()` on `ReadOnlyStorage<URL, Value>` to accept string URLs
- `.droppingResponse()` to keep only `Data`

For example:

```swift
let bytes = URLSessionStorage.shared
    .mapURLKeys()
    .mapStringKeys()
    .droppingResponse()

let data = try await bytes.retrieve(forKey: "https://example.com")
```

If you need to route traffic through a proxy, use `HTTPProxy`:

```swift
let proxy = HTTPProxy(
    username: "user",
    password: "pass",
    host: "127.0.0.1",
    port: 8080
)

let network = URLSessionStorage(
    urlSessionConfiguration: .ephemeral,
    proxy: proxy
)
```

### Zipping storages

You can zip storages together and work with tuples:

```swift
let strings = MemoryStorage<String, String>()
let numbers = MemoryStorage<String, Int>()

let zipped = zip(strings, numbers) // Storage<String, (String, Int)>

try await zipped.set(("hello", 3), forKey: "item")
let value = try await zipped.retrieve(forKey: "item")
print(value.0, value.1)
```

Read-only and write-only zip variants are available too:

- `zip(_: _:)` for `ReadOnlyStorage`
- `zip(_: _:)` for `WriteOnlyStorage`
- `zip(_: _:)` for `Storage`

### Debugging storage hierarchies

Every storage has a `storageName` and exposes its wrapped storages for debugging.

Useful debugging tools:

- `._storageHierarchy()`
- `._reach(toFirst:)`
- `._reachToFirst(where:)`
- `._reachToFirst(whereNotNil:)`
- `.obscureWrappedStorages()`

Example:

```swift
let storage = MemoryStorage<String, Data>()
    .combined(with: DiskStorage.folder("debug", in: .cachesDirectory).usingStringKeys())

print(storage._storageHierarchy())
```

If you want to hide implementation details and prevent reaching into wrapped storages, call `.obscureWrappedStorages()`.

The internal logging used by some compositions can be turned on with:

```swift
ShallowsLog.isEnabled = true
```

### Making your own storage

To add your own storage type, conform to one of the storage protocols:

- `ReadableStorage`
- `WritableStorage`
- `Storage`
- `UpdateableStorage`

For a full storage, you usually need to implement:

```swift
struct MyStorage: Storage {
    typealias Key = String
    typealias Value = Int

    func retrieve(forKey key: String) async throws -> Int {
        // ...
    }

    func set(_ value: Int, forKey key: String) async throws {
        // ...
    }

    var _wrappedStorages: [any StorageDesign] {
        []
    }
}
```

If you need low-level building blocks for your own implementation, `ActorSafe` and `StoragesAsyncQueue` are available publicly.

## Installation

**Swift Package Manager**

```swift
.package(url: "https://github.com/dreymonde/AsyncStorages.git", from: "0.1.0")
```

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "AsyncStorages", package: "AsyncStorages")
    ]
)
```

[carlos-github-url]: https://github.com/WeltN24/Carlos
[composable-caches-in-swift-url]: https://www.youtube.com/watch?v=8uqXuEZLyUU
[brandon-kase-twitter-url]: https://twitter.com/bkase_
