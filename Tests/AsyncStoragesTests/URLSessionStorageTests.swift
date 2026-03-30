#if canImport(Darwin)
import Foundation
import Testing
@testable import AsyncStorages

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (URLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: TestError.missing)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeMockedConfiguration() -> URLSessionConfiguration {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    return configuration
}

@Test func urlSessionStoragePublicAPIsWork() async throws {
    let url = URL(string: "https://example.com/path")!
    let request = URLRequest(url: url)
    let httpResponse = HTTPURLResponse(
        url: url,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
    )!
    let payload = Data(#"{"ok":true}"#.utf8)

    let responseValue = URLSessionStorage.Response(httpUrlResponse: httpResponse, data: payload)
    #expect(responseValue.httpUrlResponse.statusCode == 200)
    #expect(responseValue.data == payload)

    switch URLSessionStorage.Request.url(url) {
    case .url(let extractedURL):
        #expect(extractedURL == url)
    case .urlRequest:
        Issue.record("Expected `.url` request case.")
    }

    switch URLSessionStorage.Request.urlRequest(request) {
    case .url:
        Issue.record("Expected `.urlRequest` request case.")
    case .urlRequest(let extractedRequest):
        #expect(extractedRequest.url == url)
    }

    let configuration = makeMockedConfiguration()
    let configurationStorage = URLSessionStorage(urlSessionConfiguration: configuration)
    let sessionStorage = URLSessionStorage(urlSession: URLSession(configuration: makeMockedConfiguration()))

    MockURLProtocol.requestHandler = { currentRequest in
        #expect(currentRequest.url == url)
        #expect(currentRequest.httpMethod == "GET")
        return (httpResponse, payload)
    }
    let urlResponse = try await configurationStorage.retrieve(forKey: .url(url))
    #expect(urlResponse.httpUrlResponse.statusCode == 200)
    #expect(urlResponse.data == payload)

    MockURLProtocol.requestHandler = { currentRequest in
        #expect(currentRequest.url == url)
        #expect(currentRequest.httpMethod == "POST")
        #expect(currentRequest.value(forHTTPHeaderField: "X-Test") == "1")
        return (httpResponse, payload)
    }
    var postRequest = URLRequest(url: url)
    postRequest.httpMethod = "POST"
    postRequest.setValue("1", forHTTPHeaderField: "X-Test")
    let requestResponse = try await sessionStorage.retrieve(forKey: .urlRequest(postRequest))
    #expect(requestResponse.httpUrlResponse.statusCode == 200)
    #expect(requestResponse.data == payload)

    let mappedURLStorage = configurationStorage.mapURLKeys()
    let mappedRequestStorage = configurationStorage.mapURLRequestKeys()
    let droppedResponseStorage = configurationStorage.droppingResponse()
    let stringKeyStorage = configurationStorage
        .mapURLKeys()
        .mapStringKeys()
        .droppingResponse()

    MockURLProtocol.requestHandler = { currentRequest in
        #expect(currentRequest.url == url)
        return (httpResponse, payload)
    }
    #expect(try await mappedURLStorage.retrieve(forKey: url).data == payload)

    MockURLProtocol.requestHandler = { currentRequest in
        #expect(currentRequest.url == url)
        return (httpResponse, payload)
    }
    #expect(try await mappedRequestStorage.retrieve(forKey: request).data == payload)

    MockURLProtocol.requestHandler = { currentRequest in
        #expect(currentRequest.url == url)
        return (httpResponse, payload)
    }
    #expect(try await configurationStorage.retrieve(forKey: url).data == payload)

    MockURLProtocol.requestHandler = { currentRequest in
        #expect(currentRequest.url == url)
        return (httpResponse, payload)
    }
    #expect(try await configurationStorage.retrieve(forKey: request).data == payload)

    MockURLProtocol.requestHandler = { currentRequest in
        #expect(currentRequest.url == url)
        return (httpResponse, payload)
    }
    #expect(try await droppedResponseStorage.retrieve(forKey: .url(url)) == payload)

    MockURLProtocol.requestHandler = { currentRequest in
        #expect(currentRequest.url == url)
        return (httpResponse, payload)
    }
    #expect(try await stringKeyStorage.retrieve(forKey: url.absoluteString) == payload)

    let nonHTTPResponse = URLResponse(
        url: url,
        mimeType: "text/plain",
        expectedContentLength: payload.count,
        textEncodingName: nil
    )
    MockURLProtocol.requestHandler = { currentRequest in
        #expect(currentRequest.url == url)
        return (nonHTTPResponse, payload)
    }

    do {
        _ = try await configurationStorage.retrieve(forKey: .url(url))
        Issue.record("Expected non-HTTP response retrieval to fail.")
    } catch let error as URLSessionStorage.Error {
        switch error {
        case .responseIsNotHTTP(let response):
            #expect(response?.url == url)
        }
    } catch {
        Issue.record("Unexpected error: \(error)")
    }

    #expect(configurationStorage._wrappedStorages.isEmpty)
    #expect(URLSessionStorage.shared.urlSession === URLSession.shared)

    MockURLProtocol.requestHandler = nil
}
#endif
