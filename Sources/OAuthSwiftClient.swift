//
//  OAuthSwiftClient.swift
//  OAuthSwift
//
//  Created by Dongri Jin on 6/21/14.
//  Copyright (c) 2014 Dongri Jin. All rights reserved.
//

import Foundation

public var OAuthSwiftDataEncoding: String.Encoding = .utf8

@objc public protocol OAuthSwiftRequestHandle {
    func cancel()
}

open class OAuthSwiftClient: NSObject {

    fileprivate(set) open var credential: OAuthSwiftCredential
    open var paramsLocation: OAuthSwiftHTTPRequest.ParamsLocation = .authorizationHeader
    /// Contains default URL session configuration
    open var sessionFactory: SessionFactory

    static let separator: String = "\r\n"
    static var separatorData: Data = {
        return OAuthSwiftClient.separator.data(using: OAuthSwiftDataEncoding)!
    }()
    
    let networkActivityNotifier: OAuthSwiftNetworkActivityNotifierType?

    // MARK: init
    public init(credential: OAuthSwiftCredential, networkActivityNotifier: OAuthSwiftNetworkActivityNotifierType?, sessionFactory: SessionFactory) {
        self.credential = credential
        self.networkActivityNotifier = networkActivityNotifier
        self.sessionFactory = sessionFactory
    }

    public convenience init(consumerKey: String, consumerSecret: String, version: OAuthSwiftCredential.Version = .oauth1, networkActivityNotifier: OAuthSwiftNetworkActivityNotifierType?, sessionFactory: SessionFactory = URLSessionFactory.default) {
        let credential = OAuthSwiftCredential(consumerKey: consumerKey, consumerSecret: consumerSecret)
        credential.version = version
        self.init(credential: credential, networkActivityNotifier: networkActivityNotifier, sessionFactory: sessionFactory)
    }

    public convenience init(consumerKey: String, consumerSecret: String, oauthToken: String, oauthTokenSecret: String, version: OAuthSwiftCredential.Version, networkActivityNotifier: OAuthSwiftNetworkActivityNotifierType?, sessionFactory: SessionFactory = URLSessionFactory.default) {
        self.init(consumerKey: consumerKey, consumerSecret: consumerSecret, version: version, networkActivityNotifier: networkActivityNotifier, sessionFactory: sessionFactory)
        self.credential.oauthToken = oauthToken
        self.credential.oauthTokenSecret = oauthTokenSecret
    }

    // MARK: client methods
    @discardableResult
    open func get(_ url: URLConvertible, parameters: OAuthSwift.Parameters = [:], headers: OAuthSwift.Headers? = nil, success: OAuthSwiftHTTPRequest.SuccessHandler?, failure: OAuthSwiftHTTPRequest.FailureHandler?) -> OAuthSwiftRequestHandle? {
        return self.request(url, method: .GET, parameters: parameters, headers: headers, success: success, failure: failure)
    }

    @discardableResult
    open func post(_ url: URLConvertible, parameters: OAuthSwift.Parameters = [:], headers: OAuthSwift.Headers? = nil, body: Data? = nil, success: OAuthSwiftHTTPRequest.SuccessHandler?, failure: OAuthSwiftHTTPRequest.FailureHandler?) -> OAuthSwiftRequestHandle? {
        return self.request(url, method: .POST, parameters: parameters, headers: headers, body: body, success: success, failure: failure)
    }

    @discardableResult
    open func put(_ url: URLConvertible, parameters: OAuthSwift.Parameters = [:], headers: OAuthSwift.Headers? = nil, body: Data? = nil, success: OAuthSwiftHTTPRequest.SuccessHandler?, failure: OAuthSwiftHTTPRequest.FailureHandler?) -> OAuthSwiftRequestHandle? {
        return self.request(url, method: .PUT, parameters: parameters, headers: headers, body: body, success: success, failure: failure)
    }

    @discardableResult
    open func delete(_ url: URLConvertible, parameters: OAuthSwift.Parameters = [:], headers: OAuthSwift.Headers? = nil, success: OAuthSwiftHTTPRequest.SuccessHandler?, failure: OAuthSwiftHTTPRequest.FailureHandler?) -> OAuthSwiftRequestHandle? {
        return self.request(url, method: .DELETE, parameters: parameters, headers: headers, success: success, failure: failure)
    }

    @discardableResult
    open func patch(_ url: URLConvertible, parameters: OAuthSwift.Parameters = [:], headers: OAuthSwift.Headers? = nil, success: OAuthSwiftHTTPRequest.SuccessHandler?, failure: OAuthSwiftHTTPRequest.FailureHandler?) -> OAuthSwiftRequestHandle? {
        return self.request(url, method: .PATCH, parameters: parameters, headers: headers, success: success, failure: failure)
    }

    @discardableResult
    open func request(_ url: URLConvertible, method: OAuthSwiftHTTPRequest.Method, parameters: OAuthSwift.Parameters = [:], headers: OAuthSwift.Headers? = nil, body: Data? = nil, checkTokenExpiration: Bool = true, success: OAuthSwiftHTTPRequest.SuccessHandler?, failure: OAuthSwiftHTTPRequest.FailureHandler?) -> OAuthSwiftRequestHandle? {

        if checkTokenExpiration && self.credential.isTokenExpired() {
            failure?(OAuthSwiftError.tokenExpired(error: nil))
            return nil
        }

        guard url.url != nil else {
            failure?(OAuthSwiftError.encodingError(urlString: url.string))
            return nil
        }

        if let request = makeRequest(url, method: method, parameters: parameters, headers: headers, body: body) {
            request.start(success: success, failure: failure)
            return request
        }
        return nil
    }

    open func makeRequest(_ request: URLRequest) -> OAuthSwiftHTTPRequest {
        let request = OAuthSwiftHTTPRequest(request: request, paramsLocation: self.paramsLocation, sessionFactory: self.sessionFactory, networkActivityNotifier: self.networkActivityNotifier)
        request.config.updateRequest(credential: self.credential)
        return request
    }

    open func makeRequest(_ url: URLConvertible, method: OAuthSwiftHTTPRequest.Method, parameters: OAuthSwift.Parameters = [:], headers: OAuthSwift.Headers? = nil, body: Data? = nil) -> OAuthSwiftHTTPRequest? {
        guard let url = url.url else {
            return nil // XXX failure not thrown here
        }

        let request = OAuthSwiftHTTPRequest(url: url, method: method, parameters: parameters, paramsLocation: self.paramsLocation, httpBody: body, headers: headers ?? [:], sessionFactory: self.sessionFactory, networkActivityNotifier: self.networkActivityNotifier)
        request.config.updateRequest(credential: self.credential)
        return request
    }

    @discardableResult
    public func postImage(_ url: URLConvertible, parameters: OAuthSwift.Parameters, image: Data, success: OAuthSwiftHTTPRequest.SuccessHandler?, failure: OAuthSwiftHTTPRequest.FailureHandler?) -> OAuthSwiftRequestHandle? {
        return self.multiPartRequest(url: url, method: .POST, parameters: parameters, image: image, success: success, failure: failure)
    }

    open func makeMultiPartRequest(_ url: URLConvertible, method: OAuthSwiftHTTPRequest.Method, parameters: OAuthSwift.Parameters = [:], multiparts: [OAuthSwiftMultipartData] = [], headers: OAuthSwift.Headers? = nil) -> OAuthSwiftHTTPRequest? {
        let boundary = "AS-boundary-\(arc4random())-\(arc4random())"
        let type = "multipart/form-data; boundary=\(boundary)"
        let body = self.multiDataFromObject(parameters, multiparts: multiparts, boundary: boundary)

        var finalHeaders = [kHTTPHeaderContentType: type]
        finalHeaders += headers ?? [:]

        return makeRequest(url, method: method, parameters: parameters, headers: finalHeaders, body: body)
    }

    func multiPartRequest(url: URLConvertible, method: OAuthSwiftHTTPRequest.Method, parameters: OAuthSwift.Parameters, image: Data, success: OAuthSwiftHTTPRequest.SuccessHandler?, failure: OAuthSwiftHTTPRequest.FailureHandler?) -> OAuthSwiftRequestHandle? {
        let multiparts = [ OAuthSwiftMultipartData(name: "media", data: image, fileName: "file", mimeType: "image/jpeg") ]
        guard let request = makeMultiPartRequest(url, method: method, parameters: parameters, multiparts: multiparts) else {
            return nil
        }
        request.start(success: success, failure: failure)
        return request
    }

    open func multiPartBody(from inputParameters: OAuthSwift.Parameters, boundary: String) -> Data {
        var parameters = OAuthSwift.Parameters()
        var multiparts = [OAuthSwiftMultipartData]()

        for (key, value) in inputParameters {
            if  let data = value as? Data, key == "media" {
                let sectionType = "image/jpeg"
                let sectionFilename = "file"
                multiparts.append(OAuthSwiftMultipartData(name: key, data: data, fileName: sectionFilename, mimeType: sectionType))
            } else {
                parameters[key] = value
            }
        }

        return multiDataFromObject(parameters, multiparts: multiparts, boundary: boundary)
    }

    @discardableResult
    open func postMultiPartRequest(_ url: URLConvertible, method: OAuthSwiftHTTPRequest.Method, parameters: OAuthSwift.Parameters, headers: OAuthSwift.Headers? = nil, multiparts: [OAuthSwiftMultipartData] = [], checkTokenExpiration: Bool = true, success: OAuthSwiftHTTPRequest.SuccessHandler?, failure: OAuthSwiftHTTPRequest.FailureHandler?) -> OAuthSwiftRequestHandle? {

        if checkTokenExpiration && self.credential.isTokenExpired() {
            failure?(OAuthSwiftError.tokenExpired(error: nil))
            return nil
        }

        if let request = makeMultiPartRequest(url, method: method, parameters: parameters, multiparts: multiparts, headers: headers) {
            request.start(success: success, failure: failure)
            return request
        }
        return nil
    }

    func multiDataFromObject(_ object: OAuthSwift.Parameters, multiparts: [OAuthSwiftMultipartData], boundary: String) -> Data {
        var data = Data()

        let prefixString = "--\(boundary)\r\n"
        let prefixData = prefixString.data(using: OAuthSwiftDataEncoding)!

        for (key, value) in object {
            guard let valueData = "\(value)".data(using: OAuthSwiftDataEncoding) else {
                continue
            }
            data.append(prefixData)
            let multipartData = OAuthSwiftMultipartData(name: key, data: valueData, fileName: nil, mimeType: nil)
            data.append(multipartData, encoding: OAuthSwiftDataEncoding, separatorData: OAuthSwiftClient.separatorData)
        }

        for multipart in multiparts {
            data.append(prefixData)
            data.append(multipart, encoding: OAuthSwiftDataEncoding, separatorData: OAuthSwiftClient.separatorData)
        }

        let endingString = "--\(boundary)--\r\n"
        let endingData = endingString.data(using: OAuthSwiftDataEncoding)!
        data.append(endingData)

        return data
    }

}
