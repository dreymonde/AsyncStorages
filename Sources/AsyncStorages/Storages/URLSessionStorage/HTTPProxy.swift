//
//  HTTPProxy.swift
//  AsyncStorages
//
//  Created by Oleg on 3/30/26.
//

#if canImport(Darwin)
import Foundation

extension URLSessionStorage {
    public init(urlSessionConfiguration: URLSessionConfiguration, proxy: HTTPProxy) {
        urlSessionConfiguration.setHTTPProxy(proxy)
        self.init(urlSessionConfiguration: urlSessionConfiguration)
    }
}

public struct HTTPProxy: Hashable, Codable {
    public var username: String
    public var password: String
    public var location: Location
    public var enableHTTPS: Bool
    
    public struct Location: Hashable, Codable {
        public var host: String
        public var port: Int
        
        public init(host: String, port: Int) {
            self.host = host
            self.port = port
        }
    }
    
    public init(
        username: String,
        password: String,
        location: Location,
        enableHTTPS: Bool = true
    ) {
        self.username = username
        self.password = password
        self.location = location
        self.enableHTTPS = enableHTTPS
    }
    
    public init(
        username: String,
        password: String,
        host: String,
        port: Int,
        enableHTTPS: Bool = true
    ) {
        self.username = username
        self.password = password
        self.location = Location(host: host, port: port)
        self.enableHTTPS = enableHTTPS
    }
}

extension URLSessionConfiguration {
    public func setHTTPProxy(_ httpProxy: HTTPProxy) {
        connectionProxyDictionary = [
            kCFNetworkProxiesHTTPEnable: true,
            "HTTPProxy": httpProxy.location.host,
            "HTTPSProxy": httpProxy.location.host,
            "HTTPSPort": httpProxy.location.port,
            "HTTPPort": httpProxy.location.port,
            "HTTPSEnable": httpProxy.enableHTTPS,
            kCFProxyTypeKey: httpProxy.enableHTTPS ? kCFProxyTypeHTTPS : kCFProxyTypeHTTP,
            kCFProxyUsernameKey: httpProxy.username,
            kCFProxyPasswordKey: httpProxy.password,
        ]
        
        httpAdditionalHeaders = ["Proxy-Authorization": "Basic " + "\(httpProxy.username):\(httpProxy.password)".data(using: .utf8)!.base64EncodedString()]
    }
}
#endif
