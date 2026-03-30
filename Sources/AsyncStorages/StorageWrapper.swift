//
//  StorageWrapper.swift
//  AsyncStorages
//
//  Created by Oleg on 5/20/25.
//

public typealias StorageWrapper = StorageDesign

extension StorageWrapper {
    /// Not recommended, but using this you can reach to a specific storage in your
    /// storage hierarchy, if it is there
    ///
    /// For example, if you've wrapped `DiskFolderStorage` with modifiers,
    /// but still want to use its `clear()` function, you can use
    /// `_reach(toFirst: DiskFolderStorage.self)?.clear()`. This might
    /// be useful in some situations, but in general it is not recommended.
    ///
    /// - Note: usage of `_reach` functions can be prevented by `obscureWrappedStorages()`,
    /// so the result of `_reach` functions is never guaranteed
    public func _reach<StorageType: StorageDesign>(toFirst type: StorageType.Type) -> StorageType? {
        _reachToFirst(whereNotNil: { $0 as? StorageType })
    }
    
    /// Not recommended, but using this you can reach to a specific storage in your
    /// storage hierarchy, if it is there
    ///
    /// - Note: usage of `_reach` functions can be prevented by `obscureWrappedStorages()`,
    /// so the result of `_reach` functions is never guaranteed
    public func _reachToFirst(where condition: (any StorageDesign) -> Bool) -> (any StorageWrapper)? {
        _reachToFirst(whereNotNil: { if condition($0) { self } else { nil } })
    }
    
    /// Not recommended, but using this you can reach to a specific storage in your
    /// storage hierarchy, if it is there
    ///
    /// - Note: usage of `_reach` functions can be prevented by `obscureWrappedStorages()`,
    /// so the result of `_reach` functions is never guaranteed
    public func _reachToFirst<Other>(whereNotNil condition: (any StorageDesign) -> Other?) -> Other? {
        for immediatelyWrapped in _wrappedStorages {
            if let result = condition(immediatelyWrapped) {
                return result
            }
        }
        for wrappedStorage in _wrappedStorages {
            if let reached = wrappedStorage._reachToFirst(whereNotNil: condition) {
                return reached
            }
        }
        return nil
    }
}

public extension Storage {
    /// Obscures `_wrappedStorages` to prevent reaching to underlying storages
    /// via `_reachToFirst(where:)` or `_reach(to:)`
    func obscureWrappedStorages() -> some Storage<Key, Value> {
        WrappedStoragesObscuringStorage(underlying: self)
    }
}

public extension ReadOnlyStorage {
    /// Obscures `_wrappedStorages` to prevent reaching to underlying storages
    /// via `_reachToFirst(where:)` or `_reach(to:)`
    func obscureWrappedStorages() -> some ReadOnlyStorage<Key, Value> {
        WrappedStoragesObscuringReadOnlyStorage(underlying: self)
    }
}

public extension WriteOnlyStorage {
    /// Obscures `_wrappedStorages` to prevent reaching to underlying storages
    /// via `_reachToFirst(where:)` or `_reach(to:)`
    func obscureWrappedStorages() -> some WriteOnlyStorage<Key, Value> {
        WrappedStoragesObscuringWriteOnlyStorage(underlying: self)
    }
}

extension StorageWrapper {
    /// Returns a formatted string representation of the storage hierarchy. Might be useful for debugging
    ///
    /// - Parameters:
    ///   - indentationString: The string used for each level of indentation (default is "  ")
    /// - Returns: A formatted string showing the entire storage hierarchy
    public func _storageHierarchy(
        indentationString: String = "  "
    ) -> String {
        _storageHierarchy(indentationLevel: 0, indentationString: indentationString)
    }
    
    func _storageHierarchy(
        indentationLevel: Int,
        indentationString: String
    ) -> String {
        let currentIndentation = String(repeating: indentationString, count: indentationLevel)
        
        let defaultStorageName = String(describing: Self.self)
        let finalStorageName = if defaultStorageName == self.storageName {
            defaultStorageName.components(separatedBy: "<")[0]
        } else {
            storageName
        }
        
        // Start with the current storage name
        var result = "\(currentIndentation)- \(finalStorageName) <\(Key.self), \(Value.self)>\n"
        
        // Recursively add wrapped storages with increased indentation
        for wrappedStorage in _wrappedStorages {
            result += wrappedStorage._storageHierarchy(
                indentationLevel: indentationLevel + 1,
                indentationString: indentationString
            )
        }
        
        return result
    }
}

struct WrappedStoragesObscuringStorage<Key, Value>: Storage {
    let underlying: any Storage<Key, Value>
    
    public func retrieve(forKey key: Key) async throws -> Value {
        try await underlying.retrieve(forKey: key)
    }
    
    public func set(_ value: Value, forKey key: Key) async throws {
        try await underlying.set(value, forKey: key)
    }
    
    public var _wrappedStorages: [any StorageDesign] {
        []
    }
}

struct WrappedStoragesObscuringReadOnlyStorage<Key, Value>: ReadOnlyStorage {
    let underlying: any ReadOnlyStorage<Key, Value>
    
    public func retrieve(forKey key: Key) async throws -> Value {
        try await underlying.retrieve(forKey: key)
    }
    
    public var _wrappedStorages: [any StorageDesign] {
        []
    }
}

struct WrappedStoragesObscuringWriteOnlyStorage<Key, Value>: WriteOnlyStorage {
    let underlying: any WriteOnlyStorage<Key, Value>
    
    public func set(_ value: Value, forKey key: Key) async throws {
        try await underlying.set(value, forKey: key)
    }
    
    public var _wrappedStorages: [any StorageDesign] {
        []
    }
}
