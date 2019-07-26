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
    let shortMoment: TimeInterval = 0.01

    func testMockNotRunning() {
        let timeout = expectation(description: "Timeout")
        let handler = MockedNetworkHandler()
        
        _ = handler.dataOperation(with: URLRequest(url: url)) { (data, response, error) in
            XCTFail()
        }
        
        timeout.fulfill(after: shortMoment)
        
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
        
        timeout.fulfill(after: shortMoment)
        
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
        
        XCTAssertEqual(notifier.activeNetworkActivitiesCount, 0)
        notifier.networkActivityStarted()
        XCTAssertEqual(notifier.activeNetworkActivitiesCount, 1)
        notifier.networkActivityStarted()
        notifier.networkActivityStarted()
        XCTAssertEqual(notifier.activeNetworkActivitiesCount, 3)
        
        _ = try? notifier.networkActivityEnded()
        XCTAssertEqual(notifier.activeNetworkActivitiesCount, 2)
        _ = try? notifier.networkActivityEnded()
        _ = try? notifier.networkActivityEnded()
        XCTAssertEqual(notifier.activeNetworkActivitiesCount, 0)
        
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
     
        XCTAssertEqual(notifier.activeNetworkActivitiesCount, 0)
        client.makeRequest(URLRequest(url: url)).start(success: { _ in
            XCTFail()
        }) { _ in
            XCTAssertEqual(notifier.activeNetworkActivitiesCount, 1) // because it's called asynchronously
            
            DispatchQueue.main.async {
                XCTAssertEqual(notifier.activeNetworkActivitiesCount, 0)
                callbackCalled.fulfill()
            }
        }
        XCTAssertEqual(notifier.activeNetworkActivitiesCount, 0) // because it's called asynchronously
        
        let asyncNetworkActivityCalled = expectation(description: "Next main loop")
        
        asyncNetworkActivityCalled.fulfillInNextLoop()
        
        wait(for: [asyncNetworkActivityCalled], timeout: 0.1)
        
        XCTAssertEqual(notifier.activeNetworkActivitiesCount, 1)
        
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
        
        XCTAssertEqual(notifier.activeNetworkActivitiesCount, 0)
        client.makeRequest(request).start(success: { response in
            XCTAssertEqual(notifier.activeNetworkActivitiesCount, 1) // because it's called asynchronously
            
            XCTAssertEqual(response.data, expectedResponse.data)
            XCTAssertEqual(response.response.allHeaderFields["Content-Type"] as? String, expectedResponse.response?.allHeaderFields["Content-Type"] as? String)
            XCTAssertEqual(response.response.statusCode, expectedResponse.response?.statusCode)
            XCTAssertEqual(response.response.url, expectedResponse.response?.url)
            XCTAssertEqual(response.request?.url, request.url)
            XCTAssertEqual(response.request?.httpMethod, request.httpMethod)
            XCTAssertEqual(response.request?.httpBody, request.httpBody)
            
            DispatchQueue.main.async {
                XCTAssertEqual(notifier.activeNetworkActivitiesCount, 0)
                callbackCalled.fulfill()
            }
        }) { _ in
            XCTFail()
        }
        XCTAssertEqual(notifier.activeNetworkActivitiesCount, 0) // because it's called asynchronously
        
        let asyncNetworkActivityCalled = expectation(description: "Next main loop")
        
        asyncNetworkActivityCalled.fulfillInNextLoop()
        
        wait(for: [asyncNetworkActivityCalled], timeout: 0.1)
        
        XCTAssertEqual(notifier.activeNetworkActivitiesCount, 1)
        
        sessionFactory.handler.fulfill(url: url, withResponse: expectedResponse)
        
        waitForExpectations(timeout: 10, handler: nil)
    }

}

fileprivate class MockedSessionFactory: SessionFactory {
    
    let useDataTaskClosure: Bool = true
    let handler = MockedNetworkHandler()
    
    func build() -> OAuthSwiftNetworkRequestHandler {
        return handler
    }
}

fileprivate class MockedNetworkOperation: OAuthSwiftNetworkRequestOperation {
    
    let cancelHandler: () -> Void
    let completionHandler: OAuthSwiftNetworkRequestCallback?
    var isCanceled: Bool = false
    var isResumed: Bool = false
    
    init(cancelHandler: @escaping () -> Void, completionHandler: OAuthSwiftNetworkRequestCallback?) {
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

fileprivate extension XCTestExpectation {
    func fulfill(after time: TimeInterval, on dispatchQueue: DispatchQueue = DispatchQueue.main) {
        dispatchQueue.asyncAfter(deadline: DispatchTime.now() + time) {
            self.fulfill()
        }
    }
    
    func fulfillInNextLoop(on dispatchQueue: DispatchQueue = DispatchQueue.main) {
        dispatchQueue.async {
            self.fulfill()
        }
    }
}

fileprivate struct MockedHTTPResponse: OAuthSwiftHTTPResponse {
    let statusCode: Int
    let allHeaderFields: [AnyHashable : Any]
    let url: URL?
}

fileprivate class MockedNetworkHandler: OAuthSwiftNetworkRequestHandler {
    
    struct Response {
        let data: Data?
        let response: MockedHTTPResponse?
        let error: Error?
        
        static let `default` = Response(data: nil, response: nil, error: nil)
    }
    
    var invalidated = false
    var operations: [URL: MockedNetworkOperation] = [:]
    
    func dataOperation(with url: URL, completionHandler: OAuthSwiftNetworkRequestCallback?) -> OAuthSwiftNetworkRequestOperation {
        if invalidated { XCTFail() }
        return enqueueOperation(url: url, completionHandler)
    }
    
    func dataOperation(with request: OAuthSwiftNetworkRequest, completionHandler: OAuthSwiftNetworkRequestCallback?) -> OAuthSwiftNetworkRequestOperation {
        if invalidated { XCTFail() }
        return enqueueOperation(url: request.url!, completionHandler)
    }
    
    func finishOperationsAndInvalidate() {
        invalidated = true
    }
    
    func request(url: URL) -> OAuthSwiftNetworkRequest {
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
    
    private func enqueueOperation(url: URL, _ completionHandler: OAuthSwiftNetworkRequestCallback?) -> OAuthSwiftNetworkRequestOperation {
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
    
    var activeNetworkActivitiesCount: Int = 0
    
    func networkActivityStarted() {
        activeNetworkActivitiesCount += 1
    }
    
    func networkActivityEnded() throws {
        activeNetworkActivitiesCount -= 1
    }
}
