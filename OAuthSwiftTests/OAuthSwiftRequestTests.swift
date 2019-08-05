//
//  OAuthSwiftRequestTests.swift
//  OAuthSwift
//
//  Created by phimage on 17/11/15.
//  Copyright © 2015 Dongri Jin. All rights reserved.
//

import XCTest
@testable import OAuthSwift
import Swifter

class OAuth1SwiftRequestTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testFailure() {
        let oAuthSwiftHTTPRequest = OAuthSwiftHTTPRequest(url: URL(string: "http://127.0.0.1:\(8765)")!, networkActivityNotifier: nil)
        
        let failureExpectation = expectation(description: "Expected `failure` to be called")
        let failureHandler: OAuthSwiftHTTPRequest.FailureHandler = { _ in
            failureExpectation.fulfill()
        }
        let successHandler: OAuthSwiftHTTPRequest.SuccessHandler = { _ in
            XCTFail("The success handler should not be called. This can happen if you have a\nlocal server running on :\(8765)")
        }
        
        oAuthSwiftHTTPRequest.start(success: successHandler, failure: failureHandler)
        waitForExpectations(timeout: DefaultTimeout, handler: nil)
    }

    func testSuccess() {
        let server  = HttpServer()
        server["/"] = { request in
            return HttpResponse.ok(HttpResponseBody.text("Success!" as String) )
        }
        let port: in_port_t = 8765
        do {
            try server.start(port)
        } catch let e {
            XCTFail("\(e)")
        }
        defer {
            server.stop()
        }
        
        let oAuthSwiftHTTPRequest = OAuthSwiftHTTPRequest(url: URL(string: "http://127.0.0.1:\(port)")!, networkActivityNotifier: nil)
        let successExpectation = expectation(description: "Expected `success` to be called")
        
        let failureHandler: OAuthSwiftHTTPRequest.FailureHandler  = { error in
            XCTFail("The failure handler should not be called.\(error)")
        }
        
          let successHandler: OAuthSwiftHTTPRequest.SuccessHandler = { response in
            if response.string == "Success!" {
                successExpectation.fulfill()
            }
        }
        
        oAuthSwiftHTTPRequest.start(success: successHandler, failure: failureHandler)
        waitForExpectations(timeout: DefaultTimeout, handler: nil)
    }
    
    func testSuccessCustomRequestType() {
        let server  = HttpServer()
        server["/"] = { request in
            return HttpResponse.badRequest(HttpResponseBody.text("invalid_token" as String))
        }
        let port: in_port_t = 8765
        do {
            try server.start(port)
        } catch let e {
            XCTFail("\(e)")
        }
        defer {
            server.stop()
        }
        
        class MockHTTPRequestSubclass: OAuthSwiftHTTPRequest {
            override class func completionHandler(networkActivityNotifier: OAuthSwiftNetworkActivityNotifierType?, successHandler: SuccessHandler?, failureHandler: FailureHandler?, request: OAuthSwiftNetworkRequest, data: Data?, resp: OAuthSwiftNetworkResponse?, error: Error?) {
                let customAuthPolicyError = NSError(domain: "Tests", code: 400, userInfo: ["a": "b"])
                failureHandler?(.tokenExpired(error: customAuthPolicyError))
            }
        }
        
        let client = OAuthSwiftClient(consumerKey: "", consumerSecret: "", networkActivityNotifier: nil)
        client.sessionFactory.requestType = MockHTTPRequestSubclass.self
        
        let request = client.makeRequest("http://127.0.0.1:\(port)", method: .GET)
        
        guard let customRequest = request as? MockHTTPRequestSubclass else {
            return XCTFail()
        }
        
        let completionExpectation = expectation(description: "Expected callback to be called")
        
        customRequest.start(success: nil, failure: { error in
            guard case let .tokenExpired(underlyingError) = error,
                let unwrappedError = underlyingError,
                case let underlyingNSError = unwrappedError as NSError else {
                return XCTFail()
            }
            XCTAssertEqual(underlyingNSError.domain, "Tests")
            XCTAssertEqual(underlyingNSError.code, 400)
            XCTAssertEqual(underlyingNSError.userInfo.count, 1)
            XCTAssertEqual(underlyingNSError.userInfo["a"] as? String, "b")
            completionExpectation.fulfill()
        })
        waitForExpectations(timeout: DefaultTimeout, handler: nil)
    }

	func testCancel() {
		let origExecContext = OAuthSwiftHTTPRequest.executionContext
		OAuthSwiftHTTPRequest.executionContext = { $0() }
		defer  {
			OAuthSwiftHTTPRequest.executionContext = origExecContext
		}

		let server  = HttpServer()
		server["/"] = { request in
			sleep(2)
			return HttpResponse.ok(HttpResponseBody.text("Success!" as String) )
        }
        let port: in_port_t = 8769
		try? server.start(port)
		defer {
			server.stop()
		}

		let oAuthSwiftHTTPRequest = OAuthSwiftHTTPRequest(url: URL(string: "http://127.0.0.1:\(port)")!, networkActivityNotifier: nil)

		let failureExpectation = expectation(description: "Expected `failure` to be called because of canceling the request")
        
        let failureHandler: OAuthSwiftHTTPRequest.FailureHandler = { error in
            switch error {
            case .cancelled:
                failureExpectation.fulfill()
            case .requestError(let error, _):
                XCTAssertEqual(error._code, NSURLErrorCancelled) // old ways
            default:
                XCTFail("Wrong error type: \(error)")
            }
		}
		let successHandler: OAuthSwiftHTTPRequest.SuccessHandler  = { _ in
			XCTFail("The success handler should not be called. This can happen if you have a\nlocal server running on :\(port)")
		}

		oAuthSwiftHTTPRequest.start(success: successHandler, failure: failureHandler)
		oAuthSwiftHTTPRequest.cancel()
		waitForExpectations(timeout: DefaultTimeout, handler: nil)
	}

	func testCreationFromNSURLRequest() {
		let urlWithoutQueryString = URL(string: "www.example.com")!
		let queryParams = ["a":"123", "b": "", "complex param":"ha öäü ?$"]
		let headers = ["SomeHeader":"With a value"]
		let method = OAuthSwiftHTTPRequest.Method.PUT
		let bodyText = "Test Body"
		let timeout: TimeInterval = 78

		var urlComps = URLComponents(url: urlWithoutQueryString, resolvingAgainstBaseURL: false)
		urlComps?.queryItems = queryParams.keys.map { URLQueryItem(name: $0, value: queryParams[$0]) }
		let urlWithQueryString = urlComps!.url!
		var request = URLRequest(url: urlWithQueryString)
		request.allHTTPHeaderFields = headers
		request.httpMethod = method.rawValue
		request.httpBody = bodyText.data(using: OAuthSwiftDataEncoding)
		request.timeoutInterval = timeout
		request.httpShouldHandleCookies = true

		let oauthRequest = OAuthSwiftHTTPRequest(request: request, networkActivityNotifier: nil)

		XCTAssertEqualURL(oauthRequest.config.urlRequest.url!, urlWithQueryString)
		XCTAssertEqualDictionaries(oauthRequest.config.parameters as! [String:String], [:])
		XCTAssertEqualDictionaries(oauthRequest.config.urlRequest.allHTTPHeaderFields!, headers)
		XCTAssertEqual(oauthRequest.config.httpMethod, method)
		XCTAssertEqual(String(data: oauthRequest.config.urlRequest.httpBody!, encoding:OAuthSwiftDataEncoding)!, bodyText)
		XCTAssertEqual(oauthRequest.config.urlRequest.timeoutInterval, timeout)
		XCTAssertTrue(oauthRequest.config.urlRequest.httpShouldHandleCookies)
	}
}
