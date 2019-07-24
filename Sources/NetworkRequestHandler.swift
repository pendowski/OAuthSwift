//
//  HTTPRequestHandler.swift
//  OAuthSwift
//
//  Created by Jarek Pendowski on 24/07/2019.
//  Copyright © 2019 Dongri Jin. All rights reserved.
//

import Foundation

public typealias NetworkRequestCallback = (Data?, NetworkRequestResponse?, Error?) -> Void

public protocol NetworkRequest {
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

public protocol NetworkRequestResponse {
    var url: URL? { get }
}

public protocol HTTPRequestResponse: NetworkRequestResponse {
    var statusCode: Int { get }
    var allHeaderFields: [AnyHashable : Any] { get }
}

public protocol NetworkRequestOperation {
    func resume()
    func cancel()
}

public protocol NetworkRequestHandler {
    func dataOperation(with request: NetworkRequest, completionHandler: NetworkRequestCallback?) -> NetworkRequestOperation
    func dataOperation(with url: URL, completionHandler: NetworkRequestCallback?) -> NetworkRequestOperation
    func finishOperationsAndInvalidate()
    
    func request(url: URL) -> NetworkRequest
}

extension NetworkRequestHandler {
    func dataOperation(with request: NetworkRequest) -> NetworkRequestOperation {
        return dataOperation(with: request, completionHandler: nil)
    }
}
