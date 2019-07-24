//
//  URLSession+NetworkRequestHandler.swift
//  OAuthSwift
//
//  Created by Jarek Pendowski on 24/07/2019.
//  Copyright © 2019 Dongri Jin. All rights reserved.
//

import Foundation

extension URLRequest: NetworkRequest {
    public init(url: URL) {
        self.init(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 60)
    }
}

extension URLResponse: NetworkRequestResponse {
    
}

extension HTTPURLResponse: HTTPRequestResponse {
    
}

extension URLSessionDataTask: NetworkRequestOperation {
    
}

extension URLSession: NetworkRequestHandler {
    
    public func dataOperation(with url: URL, completionHandler: NetworkRequestCallback?) -> NetworkRequestOperation {
        return dataTask(with: url, completionHandler: completionHandler ?? { _,_,_ in })
    }
    
    
    public func dataOperation(with request: NetworkRequest, completionHandler: NetworkRequestCallback?) -> NetworkRequestOperation {
        guard let request = request as? URLRequest else {
            preconditionFailure()
        }
        return dataTask(with: request, completionHandler: completionHandler ?? { _,_,_  in })
    }
    
    public func finishOperationsAndInvalidate() {
        finishTasksAndInvalidate()
    }
    
    
    public func request(url: URL) -> NetworkRequest {
        return URLRequest(url: url)
    }
    
}
