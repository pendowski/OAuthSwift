//
//  OAuthSwiftResponse.swift
//  OAuthSwift
//
//  Created by phimage on 04/11/16.
//  Copyright © 2016 Dongri Jin. All rights reserved.
//

import Foundation

/// Response object
@objc
public class OAuthSwiftResponse: NSObject { // not a struct for objc
    /// The data returned by the server.
    public var data: Data
    /// The server's response to the URL request.
    public var response: HTTPRequestResponse
    /// The URL request sent to the server.
    public var request: NetworkRequest?

    public init(data: Data, response: HTTPRequestResponse, request: NetworkRequest?) {
        self.data = data
        self.response = response
        self.request = request
    }

}

/// Extends this object to convert data into your business objects
extension OAuthSwiftResponse {

    public func dataString(encoding: String.Encoding = OAuthSwiftDataEncoding) -> String? {
        return String(data: self.data, encoding: encoding)
    }

    /// `data` converted to string using data encoding
    public var string: String? {
        return dataString()
    }

    /// Convert to json object using JSONSerialization
    public func jsonObject(options opt: JSONSerialization.ReadingOptions = []) throws -> Any {
        return try JSONSerialization.jsonObject(with: self.data, options: opt)
    }

    /// Convert to object using PropertyListSerialization
    public func propertyList(options opt: PropertyListSerialization.ReadOptions = [], format: UnsafeMutablePointer<PropertyListSerialization.PropertyListFormat>? = nil) throws -> Any {
        return try PropertyListSerialization.propertyList(from: self.data, options: opt, format: format)
    }
}
