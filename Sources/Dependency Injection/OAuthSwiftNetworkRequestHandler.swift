//
//  OAuthSwiftNetworkRequestHandler.swift
//  OAuthSwift
//
//  Created by Jarek Pendowski on 24/07/2019.
//  Copyright © 2019 Dongri Jin. All rights reserved.
//

import Foundation

public typealias OAuthSwiftNetworkRequestCallback = (Data?, OAuthSwiftNetworkRequestResponse?, Error?) -> Void

public protocol OAuthSwiftNetworkRequest {
    var url: URL? { get set }
    var httpMethod: String? { get set }
    var allHTTPHeaderFields: [String : String]? { get set }
    var httpBody: Data? { get set }
    var httpShouldHandleCookies: Bool { get }
    var timeoutInterval: TimeInterval { get }
    
    init(url: URL)
    
    func value(forHTTPHeaderField field: String) -> String?
    mutating func setValue(_ value: String?, forHTTPHeaderField field: String)
    mutating func addValue(_ value: String, forHTTPHeaderField field: String)
}

public protocol OAuthSwiftNetworkRequestResponse {
    var url: URL? { get }
}

public protocol OAuthSwiftHTTPRequestResponse: OAuthSwiftNetworkRequestResponse {
    var statusCode: Int { get }
    var allHeaderFields: [AnyHashable : Any] { get }
}

public protocol OAuthSwiftNetworkRequestOperation {
    func resume()
    func cancel()
}

public protocol OAuthSwiftNetworkRequestHandler {
    func dataOperation(with request: OAuthSwiftNetworkRequest, completionHandler: OAuthSwiftNetworkRequestCallback?) -> OAuthSwiftNetworkRequestOperation
    func dataOperation(with url: URL, completionHandler: OAuthSwiftNetworkRequestCallback?) -> OAuthSwiftNetworkRequestOperation
    func finishOperationsAndInvalidate()
    
    func request(url: URL) -> OAuthSwiftNetworkRequest
}

extension OAuthSwiftNetworkRequestHandler {
    func dataOperation(with request: OAuthSwiftNetworkRequest) -> OAuthSwiftNetworkRequestOperation {
        return dataOperation(with: request, completionHandler: nil)
    }
}
