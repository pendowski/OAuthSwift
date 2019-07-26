//
//  URLSession+OAuthSwiftNetworkRequestHandler.swift
//  OAuthSwift
//
//  Created by Jarek Pendowski on 24/07/2019.
//  Copyright © 2019 Dongri Jin. All rights reserved.
//

import Foundation

extension URLRequest: OAuthSwiftNetworkRequest {
    public init(url: URL) {
        self.init(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60)
    }
}

extension URLResponse: OAuthSwiftNetworkResponse {
    
}

extension HTTPURLResponse: OAuthSwiftHTTPResponse {
    
}

extension URLSessionDataTask: OAuthSwiftNetworkRequestOperation {
    
}

extension URLSession: OAuthSwiftNetworkRequestHandler {
    
    public func dataOperation(with url: URL, completionHandler: OAuthSwiftNetworkRequestCallback?) -> OAuthSwiftNetworkRequestOperation {
        return dataTask(with: url, completionHandler: completionHandler ?? { _,_,_ in })
    }
    
    
    public func dataOperation(with request: OAuthSwiftNetworkRequest, completionHandler: OAuthSwiftNetworkRequestCallback?) -> OAuthSwiftNetworkRequestOperation {
        guard let request = request as? URLRequest else {
            preconditionFailure()
        }
        return dataTask(with: request, completionHandler: completionHandler ?? { _,_,_  in })
    }
    
    public func finishOperationsAndInvalidate() {
        finishTasksAndInvalidate()
    }
    
    
    public func request(url: URL) -> OAuthSwiftNetworkRequest {
        return URLRequest(url: url)
    }
    
}
