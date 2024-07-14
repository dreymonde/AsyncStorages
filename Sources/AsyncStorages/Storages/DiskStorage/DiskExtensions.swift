//
//  File.swift
//  
//
//  Created by Oleg on 7/11/24.
//

import Foundation

extension Storage where Value == Data {
    
    public func mapJSON(
        readingOptions: JSONSerialization.ReadingOptions = [],
        writingOptions: JSONSerialization.WritingOptions = []
    ) -> some Storage<Key, Any> {
        transformingStorages(
            readable: { $0.mapJSON(options: readingOptions) },
            writable: { $0.mapJSON(options: writingOptions) }
        )
    }
    
    public func mapJSONDictionary(
        readingOptions: JSONSerialization.ReadingOptions = [],
        writingOptions: JSONSerialization.WritingOptions = []
    ) -> some Storage<Key, [String : Any]> {
        transformingStorages(
            readable: { $0.mapJSONDictionary(options: readingOptions) },
            writable: { $0.mapJSONDictionary(options: writingOptions) }
        )
    }
    
    public func mapJSONObject<JSONObject: Codable>(
        _ objectType: JSONObject.Type,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) -> some Storage<Key, JSONObject> {
        transformingStorages(
            readable: { $0.mapJSONObject(objectType, decoder: decoder) },
            writable: { $0.mapJSONObject(objectType, encoder: encoder) }
        )
    }
    
    public func mapPlist(
        format: PropertyListSerialization.PropertyListFormat = .xml,
        readOptions: PropertyListSerialization.ReadOptions = [],
        writeOptions: PropertyListSerialization.WriteOptions = 0
    ) -> some Storage<Key, Any> {
        transformingStorages(
            readable: { $0.mapPlist(format: format, options: readOptions) },
            writable: { $0.mapPlist(format: format, options: writeOptions) }
        )
    }
    
    public func mapPlistDictionary(
        format: PropertyListSerialization.PropertyListFormat = .xml,
        readOptions: PropertyListSerialization.ReadOptions = [],
        writeOptions: PropertyListSerialization.WriteOptions = 0
    ) -> some Storage<Key, [String : Any]> {
        transformingStorages(
            readable: { $0.mapPlistDictionary(format: format, options: readOptions) },
            writable: { $0.mapPlistDictionary(format: format, options: writeOptions) }
        )
    }
    
    public func mapPlistObject<PlistObject: Codable>(
        _ objectType: PlistObject.Type,
        decoder: PropertyListDecoder = PropertyListDecoder(),
        encoder: PropertyListEncoder = PropertyListEncoder()
    ) -> some Storage<Key, PlistObject> {
        transformingStorages(
            readable: { $0.mapPlistObject(objectType, decoder: decoder) },
            writable: { $0.mapPlistObject(objectType, encoder: encoder) }
        )
    }
    
    public func mapString(withEncoding encoding: String.Encoding = .utf8) -> some Storage<Key, String> {
        transformingStorages(
            readable: { $0.mapString(withEncoding: encoding) },
            writable: { $0.mapString(withEncoding: encoding) }
        )
    }
    
}

extension ReadOnlyStorage where Value == Data {
    
    public func mapJSON(options: JSONSerialization.ReadingOptions = []) -> some ReadOnlyStorage<Key, Any> {
        return mapValues({ data in
            do {
                return try JSONSerialization.jsonObject(with: data, options: options)
            } catch {
                throw DecodingError<JSONSerialization>(originalData: data, rawError: error)
            }
        })
    }
    
    public func mapJSONDictionary(options: JSONSerialization.ReadingOptions = []) -> some ReadOnlyStorage<Key, [String : Any]> {
        mapJSON(options: options).mapValues(throwing({ $0 as? [String : Any] }))
    }
    
    public func mapJSONObject<JSONObject: Decodable>(
        _ objectType: JSONObject.Type,
        decoder: JSONDecoder = JSONDecoder()
    ) -> some ReadOnlyStorage<Key, JSONObject> {
        return mapValues({ data in
            do {
                return try decoder.decode(objectType, from: data)
            } catch {
                throw DecodingError<JSONDecoder>(originalData: data, rawError: error)
            }
        })
    }
    
    public func mapPlist(
        format: PropertyListSerialization.PropertyListFormat = .xml,
        options: PropertyListSerialization.ReadOptions = []
    ) -> some ReadOnlyStorage<Key, Any> {
        return mapValues({ data in
            do {
                var formatRef = format
                return try PropertyListSerialization.propertyList(from: data, options: options, format: &formatRef)
            } catch {
                throw DecodingError<PropertyListSerialization>(originalData: data, rawError: error)
            }
        })
    }
    
    public func mapPlistDictionary(
        format: PropertyListSerialization.PropertyListFormat = .xml,
        options: PropertyListSerialization.ReadOptions = []
    ) -> some ReadOnlyStorage<Key, [String : Any]> {
        mapPlist(format: format, options: options).mapValues(throwing({ $0 as? [String : Any] }))
    }
    
    public func mapPlistObject<PlistObject: Decodable>(
        _ objectType: PlistObject.Type,
        decoder: PropertyListDecoder = PropertyListDecoder()
    ) -> some ReadOnlyStorage<Key, PlistObject> {
        return mapValues({ data in
            do {
                return try decoder.decode(objectType, from: data)
            } catch {
                throw DecodingError<PropertyListDecoder>(originalData: data, rawError: error)
            }
        })
    }
    
    public func mapString(withEncoding encoding: String.Encoding = .utf8) -> some ReadOnlyStorage<Key, String> {
        mapValues(throwing({ String(data: $0, encoding: encoding) }))
    }
    
}

extension WriteOnlyStorage where Value == Data {
    
    public func mapJSON(options: JSONSerialization.WritingOptions = []) -> some WriteOnlyStorage<Key, Any> {
        mapValues({ try JSONSerialization.data(withJSONObject: $0, options: options) })
    }
    
    public func mapJSONDictionary(options: JSONSerialization.WritingOptions = []) -> some WriteOnlyStorage<Key, [String : Any]> {
        mapJSON(options: options).mapValues({ $0 as Any })
    }
    
    public func mapJSONObject<JSONObject: Encodable>(
        _ objectType: JSONObject.Type,
        encoder: JSONEncoder = JSONEncoder()
    ) -> some WriteOnlyStorage<Key, JSONObject> {
        mapValues({ try encoder.encode($0) })
    }
    
    public func mapPlist(
        format: PropertyListSerialization.PropertyListFormat = .xml,
        options: PropertyListSerialization.WriteOptions = 0
    ) -> some WriteOnlyStorage<Key, Any> {
        mapValues({ try PropertyListSerialization.data(fromPropertyList: $0, format: format, options: options) })
    }
    
    public func mapPlistDictionary(
        format: PropertyListSerialization.PropertyListFormat = .xml,
        options: PropertyListSerialization.WriteOptions = 0
    ) -> some WriteOnlyStorage<Key, [String : Any]> {
        mapPlist(format: format, options: options).mapValues({ $0 as Any })
    }
    
    public func mapPlistObject<PlistObject: Encodable>(
        _ objectType: PlistObject.Type,
        encoder: PropertyListEncoder = PropertyListEncoder()
    ) -> some WriteOnlyStorage<Key, PlistObject> {
        mapValues({ try encoder.encode($0) })
    }
    
    public func mapString(withEncoding encoding: String.Encoding = .utf8) -> some WriteOnlyStorage<Key, String> {
        mapValues(throwing({ $0.data(using: encoding) }))
    }
    
}

extension Storage where Key == Filename {
    public func usingStringKeys() -> some Storage<String, Value> {
        mapKeys({ Filename(rawValue: $0) })
    }
}

extension ReadOnlyStorage where Key == Filename {
    public func usingStringKeys() -> some ReadOnlyStorage<String, Value> {
        mapKeys({ Filename(rawValue: $0) })
    }
}

extension WriteOnlyStorage where Key == Filename {
    public func usingStringKeys() -> some WriteOnlyStorage<String, Value> {
        mapKeys({ Filename(rawValue: $0) })
    }
}

public struct DecodingError<T>: Error {
    @StringPrinted public var originalData: Data
    public var rawError: Error
}

@propertyWrapper
public struct StringPrinted: CustomStringConvertible {
    public var wrappedValue: Data
    
    public init(wrappedValue: Data) {
        self.wrappedValue = wrappedValue
    }
    
    public var description: String {
        if let string = String.init(data: wrappedValue, encoding: .utf8) {
            return string
        } else {
            return "__raw-unmappable-data__"
        }
    }
}

internal func throwing<In, Out>(_ block: @escaping (In) -> Out?) -> (In) throws -> Out {
    return { input in
        try block(input).unwrap()
    }
}

public struct UnwrapError : Error {
    public init() { }
}

extension Optional {
    func unwrap() throws -> Wrapped {
        return try unwrap(orThrow: UnwrapError())
    }
    
    func unwrap(orThrow thr: @autoclosure () -> Error) throws -> Wrapped {
        if let wrapped = self {
            return wrapped
        } else {
            throw thr()
        }
    }
}
