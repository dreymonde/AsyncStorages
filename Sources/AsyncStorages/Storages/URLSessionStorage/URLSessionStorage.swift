//
//  URLSessionStorage.swift
//  AsyncStorages
//
//  Created by Oleg on 3/30/26.
//

#if canImport(Darwin)
import Foundation

public struct URLSessionStorage: ReadOnlyStorage {
    public enum Request {
        case url(URL)
        case urlRequest(URLRequest)
    }
    public struct Response {
        public var httpUrlResponse: HTTPURLResponse
        public var data: Data
        
        public init(httpUrlResponse: HTTPURLResponse, data: Data) {
            self.httpUrlResponse = httpUrlResponse
            self.data = data
        }
    }
    public typealias Key = Request
    public typealias Value = Response
    
    public let urlSession: URLSession
    
    public init(urlSession: URLSession) {
        self.urlSession = urlSession
    }
    public init(urlSessionConfiguration: URLSessionConfiguration) {
        self.urlSession = URLSession(configuration: urlSessionConfiguration)
    }
    public static var shared: URLSessionStorage {
        URLSessionStorage(urlSession: .shared)
    }
    
    public enum Error: Swift.Error {
        case responseIsNotHTTP(URLResponse?)
    }
    
    public func retrieve(forKey key: Key) async throws -> Response {
        switch key {
        case .url(let url):
            let (data, response) = try await urlSession.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw Error.responseIsNotHTTP(response)
            }
            return Response(httpUrlResponse: httpResponse, data: data)
        case .urlRequest(let urlRequest):
            let (data, response) = try await urlSession.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw Error.responseIsNotHTTP(response)
            }
            return Response(httpUrlResponse: httpResponse, data: data)
        }
    }
    
    public var _wrappedStorages: [any StorageDesign] {
        []
    }
}

extension ReadOnlyStorage where Key == URLSessionStorage.Request {
    public func mapURLKeys() -> MappedKeysReadOnlyStorage<Self, URL> {
        mapKeys({ .url($0) })
    }
    
    public func mapURLRequestKeys() -> MappedKeysReadOnlyStorage<Self, URLRequest> {
        mapKeys({ .urlRequest($0) })
    }
    
    public func retrieve(forKey url: URL) async throws -> Value {
        try await retrieve(forKey: .url(url))
    }
    
    public func retrieve(forKey urlRequest: URLRequest) async throws -> Value {
        try await retrieve(forKey: .urlRequest(urlRequest))
    }
}

extension ReadOnlyStorage where Key == URL {
    public func mapStringKeys() -> MappedKeysReadOnlyStorage<Self, String> {
        return mapKeys({ try URL(string: $0).unwrap() })
    }
}

extension ReadOnlyStorage where Value == URLSessionStorage.Response {
    public func droppingResponse() -> MappedValuesReadOnlyStorage<Self, Data> {
        return mapValues({ $0.data })
    }
}
#endif
