//
//  OAuthSwiftNetworkActivityNotifierTests.swift
//  OAuthSwiftTests
//
//  Created by Jarek Pendowski on 24/07/2019.
//  Copyright © 2019 Dongri Jin. All rights reserved.
//

import XCTest
@testable import OAuthSwift

class OAuthSwiftNetworkActivityNotifierTests: XCTestCase {
    
    let url = URL(string: "http://github.com/pendowski/OAuthSwift")!

    func testMockNotRunning() {
        let timeout = expectation(description: "Timeout")
        let handler = MockedNetworkHandler()
        
        _ = handler.dataOperation(with: URLRequest(url: url)) { (data, response, error) in
            XCTFail()
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
            timeout.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testMockCanceled() {
        let timeout = expectation(description: "Timeout")
        let handler = MockedNetworkHandler()
        
        let operation = handler.dataOperation(with: URLRequest(url: url)) { (data, response, error) in
            XCTFail()
        }
        operation.resume()
        operation.cancel()
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
            timeout.fulfill()
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testMockSuccess() {
        let completionCalled = expectation(description: "Completion Called")
        let handler = MockedNetworkHandler()
        
        let operation = handler.dataOperation(with: URLRequest(url: url)) { (data, response, error) in
            XCTAssertNil(data)
            XCTAssertNil(response)
            XCTAssertNil(error)
            
            completionCalled.fulfill()
        }
        operation.resume()
        
        handler.fulfill(url: url, withResponse: .init(data: nil, response: nil, error: nil))
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    // MARK: - Tests
    
    func testDefaultNotifierCounting() {
        let notifier = OAuthSwiftDefaultNetworkActivityNotifier()
        
        XCTAssertEqual(notifier.activeNetworkActivities, 0)
        notifier.networkActivityStarted()
        XCTAssertEqual(notifier.activeNetworkActivities, 1)
        notifier.networkActivityStarted()
        notifier.networkActivityStarted()
        XCTAssertEqual(notifier.activeNetworkActivities, 3)
        
        _ = try? notifier.networkActivityEnded()
        XCTAssertEqual(notifier.activeNetworkActivities, 2)
        _ = try? notifier.networkActivityEnded()
        _ = try? notifier.networkActivityEnded()
        XCTAssertEqual(notifier.activeNetworkActivities, 0)
        
        do {
            try notifier.networkActivityEnded()
            
            XCTFail()
        } catch {
            guard let error = error as? OAuthSwiftDefaultNetworkActivityNotifier.Error else {
                return XCTFail()
            }
            XCTAssert(error == OAuthSwiftDefaultNetworkActivityNotifier.Error.unbalancedActivityCall)
        }
    }
    
    func testCustomNotifierUpdates() {
        var calls: [Bool] = []
        let notifier = OAuthSwiftDefaultNetworkActivityNotifier { value in
            calls.append(value)
        }
        
        notifier.networkActivityStarted()
        _ = try? notifier.networkActivityEnded()
        notifier.networkActivityStarted()
        notifier.networkActivityStarted()
        _ = try? notifier.networkActivityEnded()
        _ = try? notifier.networkActivityEnded()
        
        XCTAssertEqual(calls, [true, false, true, true, true, false])
    }
    
    func testRequestUsingNotifierFailure() {
        let notifier = MockedNetworkNotifier()
        let client = OAuthSwiftClient(consumerKey: "", consumerSecret: "", networkActivityNotifier: notifier)
        let sessionFactory = MockedSessionFactory()
        client.sessionFactory = sessionFactory

        let callbackCalled = expectation(description: "Callback called")
     
        XCTAssertEqual(notifier.activeNetworkActivities, 0)
        client.makeRequest(URLRequest(url: url)).start(success: { _ in
            XCTFail()
        }) { _ in
            XCTAssertEqual(notifier.activeNetworkActivities, 1) // because it's called asynchronously
            
            DispatchQueue.main.async {
                XCTAssertEqual(notifier.activeNetworkActivities, 0)
                callbackCalled.fulfill()
            }
        }
        XCTAssertEqual(notifier.activeNetworkActivities, 0) // because it's called asynchronously
        
        let asyncNetworkActivityCalled = expectation(description: "Next main loop")
        
        DispatchQueue.main.async {
            asyncNetworkActivityCalled.fulfill()
        }
        
        wait(for: [asyncNetworkActivityCalled], timeout: 0.1)
        
        XCTAssertEqual(notifier.activeNetworkActivities, 1)
        
        sessionFactory.handler.fulfill(url: url, withResponse: .init(data: nil, response: nil, error: nil))
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testRequestUsingNotifierSuccess() {
        let notifier = MockedNetworkNotifier()
        let client = OAuthSwiftClient(consumerKey: "", consumerSecret: "", networkActivityNotifier: notifier)
        let sessionFactory = MockedSessionFactory()
        let expectedResponse = MockedNetworkHandler.Response(data: Data(bytes: "{}".utf8),
                                                             response: MockedHTTPResponse(statusCode: 200,
                                                                                          allHeaderFields: [ "Content-Type": "application/json"],
                                                                                          url: url),
                                                             error: nil)
        client.sessionFactory = sessionFactory
        
        let callbackCalled = expectation(description: "Callback called")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data(bytes: "{ \"body\": \"true\" )".utf8)
        
        XCTAssertEqual(notifier.activeNetworkActivities, 0)
        client.makeRequest(request).start(success: { response in
            XCTAssertEqual(notifier.activeNetworkActivities, 1) // because it's called asynchronously
            
            XCTAssertEqual(response.data, expectedResponse.data)
            XCTAssertEqual(response.response.allHeaderFields["Content-Type"] as? String, expectedResponse.response?.allHeaderFields["Content-Type"] as? String)
            XCTAssertEqual(response.response.statusCode, expectedResponse.response?.statusCode)
            XCTAssertEqual(response.response.url, expectedResponse.response?.url)
            XCTAssertEqual(response.request?.url, request.url)
            XCTAssertEqual(response.request?.httpMethod, request.httpMethod)
            XCTAssertEqual(response.request?.httpBody, request.httpBody)
            
            DispatchQueue.main.async {
                XCTAssertEqual(notifier.activeNetworkActivities, 0)
                callbackCalled.fulfill()
            }
        }) { _ in
            XCTFail()
        }
        XCTAssertEqual(notifier.activeNetworkActivities, 0) // because it's called asynchronously
        
        let asyncNetworkActivityCalled = expectation(description: "Next main loop")
        
        DispatchQueue.main.async {
            asyncNetworkActivityCalled.fulfill()
        }
        
        wait(for: [asyncNetworkActivityCalled], timeout: 0.1)
        
        XCTAssertEqual(notifier.activeNetworkActivities, 1)
        
        sessionFactory.handler.fulfill(url: url, withResponse: expectedResponse)
        
        waitForExpectations(timeout: 10, handler: nil)
    }

}

fileprivate class MockedSessionFactory: SessionFactory {
    
    let useDataTaskClosure: Bool = true
    let handler = MockedNetworkHandler()
    
    func build() -> NetworkRequestHandler {
        return handler
    }
}

fileprivate class MockedNetworkOperation: NetworkRequestOperation {
    
    let cancelHandler: () -> Void
    let completionHandler: NetworkRequestCallback?
    var isCanceled: Bool = false
    var isResumed: Bool = false
    
    init(cancelHandler: @escaping () -> Void, completionHandler: NetworkRequestCallback?) {
        self.cancelHandler = cancelHandler
        self.completionHandler = completionHandler
    }
    
    func resume() {
        if isCanceled { XCTFail() }
        isResumed = true
    }
    
    func cancel() {
        isCanceled = true
        cancelHandler()
    }
}

fileprivate struct MockedHTTPResponse: HTTPRequestResponse {
    let statusCode: Int
    let allHeaderFields: [AnyHashable : Any]
    let url: URL?
}

fileprivate class MockedNetworkHandler: NetworkRequestHandler {
    
    struct Response {
        let data: Data?
        let response: MockedHTTPResponse?
        let error: Error?
        
        static let `default` = Response(data: nil, response: nil, error: nil)
    }
    
    var invalidated = false
    var operations: [URL: MockedNetworkOperation] = [:]
    
    func dataOperation(with url: URL, completionHandler: NetworkRequestCallback?) -> NetworkRequestOperation {
        if invalidated { XCTFail() }
        return enqueueOperation(url: url, completionHandler)
    }
    
    func dataOperation(with request: NetworkRequest, completionHandler: NetworkRequestCallback?) -> NetworkRequestOperation {
        if invalidated { XCTFail() }
        return enqueueOperation(url: request.url!, completionHandler)
    }
    
    func finishOperationsAndInvalidate() {
        invalidated = true
    }
    
    func request(url: URL) -> NetworkRequest {
        return URLRequest(url: url)
    }
    
    func fulfill(url: URL, withResponse response: Response) {
        guard let operation = operations[url] else {
            return XCTFail()
        }
        if operation.isCanceled { XCTFail() }
        if !operation.isResumed { XCTFail() }
        operation.completionHandler?(response.data, response.response, response.error)
    }
    
    // MARK: - Private
    
    private func enqueueOperation(url: URL, _ completionHandler: NetworkRequestCallback?) -> NetworkRequestOperation {
        assert(operations[url] == nil)
        let operation = MockedNetworkOperation(cancelHandler: { [weak self] in
            self?.operations.removeValue(forKey: url)
        }, completionHandler: completionHandler)
        operations[url] = operation
        
        return operation
    }
    
}

fileprivate class MockedNetworkNotifier: OAuthSwiftNetworkActivityNotifierType {
    enum Error: Swift.Error {
        case unbalancedCall
    }
    
    var activeNetworkActivities: Int = 0
    
    func networkActivityStarted() {
        activeNetworkActivities += 1
    }
    
    func networkActivityEnded() throws {
        activeNetworkActivities -= 1
    }
}
