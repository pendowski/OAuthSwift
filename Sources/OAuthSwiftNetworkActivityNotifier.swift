//
//  OAuthSwiftNetworkActivityNotifier.swift
//  OAuthSwift
//
//  Created by Jarek Pendowski on 23/07/2019.
//  Copyright © 2019 Dongri Jin. All rights reserved.
//

import Foundation

public protocol OAuthSwiftNetworkActivityNotifierType {
    var activeNetworkActivities: Int { get }
    
    func networkActivityStarted()
    func networkActivityEnded() throws
}

public class OAuthSwiftDefaultNetworkActivityNotifier: OAuthSwiftNetworkActivityNotifierType {
    private var updateHandler: (Bool) -> Void
    
    public static let defaultUpdateHandler: (Bool) -> Void = { visible in
        #if os(iOS)
            UIApplication.shared.isNetworkActivityIndicatorVisible = visible
        #endif
    }
    
    public enum Error: Swift.Error {
        case unbalancedActivityCall
    }
    
    public var activeNetworkActivities: Int = 0 {
        didSet {
            if activeNetworkActivities != oldValue {
                updateHandler(activeNetworkActivities > 0)
            }
        }
    }
    
    public init(_ updateHandler: @escaping (Bool) -> Void = OAuthSwiftDefaultNetworkActivityNotifier.defaultUpdateHandler) {
        self.updateHandler = updateHandler
    }
    
    public func networkActivityStarted() {
        activeNetworkActivities += 1
    }
    
    public func networkActivityEnded() throws {
        if activeNetworkActivities <= 0 {
            throw Error.unbalancedActivityCall
        }
        activeNetworkActivities -= 1
    }
    
}
