//
//  Service.swift
//  Pods
//
//  Created by Alex Hartwell on 2/9/17.
//
//

import Foundation
import Moya
import PromiseKit


public enum SpoofReturn {
    case none
    case json
    case objects
}
public struct JSONAPIServiceSettings {
    public var baseUrl: String = ""
    public var spoofReturn: SpoofReturn = .none
    public var testingJSON: TestData.Type = NoTestData.self
    public var timeoutClosure: ((JSONAPITargetMethod) -> Double)?
    public var headersClosure: ((JSONAPITargetMethod) -> [String: String])?
    public var moyaProviderPlugins: [PluginType] = []
    
    public init() {
        
    }
}

//Generic Network Manager
open class JSONAPIService<T: PSJSONApiModel>: PluginType {
    
    
    var settings: JSONAPIServiceSettings
    //the actual object used to make the requests
    lazy var provider: MoyaProvider<JSONAPIRequest<T>> = self.getProvider();
    
    /// get a MoyaProvider to make API calls
    public func getProvider<T: TargetType>() -> MoyaProvider<T> {
        let provider = MoyaProvider<T>(stubClosure: {
            _ in
            if self.settings.spoofReturn == .json {
                return .immediate;
            } else {
                return .never
            }
        }, plugins: [self] + self.settings.moyaProviderPlugins
        )
        return provider;
    }

    
    open var getObjectSpoof: T = T()
    open var createObjectSpoof: T = T()
    open var updateObjectSpoof: T = T()
    open var getRequestSpoof: [T] = []
    
    
    public init(settings: JSONAPIServiceSettings) {
        self.settings = settings
    }
    
    
    open func makeRequest(request: JSONAPIRequestSingle<T>) -> Promise<T> {
        var request = request.addSettings(self.settings)
        if self.settings.spoofReturn == .objects {
            return self.makeSingleRequestSpoof(target: request.type)
        }
        return self.makeRequest(request)
    }
    
    open func makeRequest(request: JSONAPIRequestEmptyResponse<T>) -> Promise<Void> {
        var request = request.addSettings(self.settings)
        if self.settings.spoofReturn == .objects {
            return Promise<Void>(value: ())
        }
        return self.makeRequestNoObjectReturn(request)
    }
    
    open func makeRequest(request: JSONAPIRequest<T>) -> Promise<[T]> {
        var request = request.addSettings(self.settings)
        if self.settings.spoofReturn == .objects {
            return self.makeArrayRequestSpoof(tagert: request.type)
        }
        return self.makeRequestArray(request)
    }
    
    
    internal func makeSingleRequestSpoof(target: JSONAPITargetMethod) -> Promise<T> {
        switch target {
        case .getObject:
            return Promise<T>(value: self.getObjectSpoof)
        case .createObject:
            return Promise<T>(value: self.createObjectSpoof)
        case .updateObject:
            return Promise<T>(value: self.updateObjectSpoof)
        default:
            return Promise<T>(value: self.getObjectSpoof)
        }
    }
    
    internal func makeArrayRequestSpoof(tagert: JSONAPITargetMethod) -> Promise<[T]> {
        return Promise<[T]>(value: self.getRequestSpoof)
    }
    
    open func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
        guard let target = target as? JSONAPIRequest<T> else {
            return request
        }
        var request = request
        
        self.addTimeoutToRequest(&request, target: target)
        self.addHeadersToRequest(&request, target: target)
        
        return request
    }
    
    internal func addTimeoutToRequest(_ request: inout URLRequest, target: JSONAPIRequest<T>) {
        if let timeout = self.settings.timeoutClosure?(target.type) {
            request.timeoutInterval = timeout
        } else {
            request.timeoutInterval = 20
        }
    }
    
    internal func addHeadersToRequest(_ request: inout URLRequest, target: JSONAPIRequest<T>) {
        if let headers = self.settings.headersClosure?(target.type) {
            for header in headers {
                request.addValue(header.value, forHTTPHeaderField: header.key)
            }
        }
    }
    
    /// Called immediately before a request is sent over the network (or stubbed).
    open func willSend(_ request: RequestType, target: TargetType) {
        
    }
    
    /// Called after a response has been received, but before the MoyaProvider has invoked its completion handler.
    open func didReceive(_ result: Result<Moya.Response>, target: TargetType) {
        
    }
    
    /// Called to modify a result before completion
    open func process(_ result: Result<Moya.Response>, target: TargetType) -> Result<Moya.Response> {
        return result
    }

    
    //a wrapper for a request which returns a single object, type is the type of request, defined in the API map
    internal func makeRequest(_ type: JSONAPIRequest<T>) -> Promise<T> {
        Background.runInMainThread {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true;
        }
        let promise = Promise<T>.pending();
        self.provider.request(type, completion: {
            result in
            switch result {
            case let .success(moyaResponse):
                Background.runInBackground {
                    
                    do {
                        try moyaResponse.filterSuccessfulStatusAndRedirectCodes();
                        let object: T = try moyaResponse.map(to: T.self);
                        Background.runInMainThread {
                            UIApplication.shared.isNetworkActivityIndicatorVisible = false;
                            promise.fulfill(object);
                        }
                    }
                    catch {
                        print(error);
                        print(type);
                        Background.runInMainThread {
                            UIApplication.shared.isNetworkActivityIndicatorVisible = false;
                            promise.reject(error);
                        }
                    }
                }
                break;
            case let .failure(error):
                Background.runInMainThread {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false;
                    promise.reject(error);
                }
                break;
            }
        });
        return promise.promise;
    }
    
    internal func makeRequestNoObjectReturn(_ type: JSONAPIRequest<T>) -> Promise<Void> {
        Background.runInMainThread {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true;
        }
        let promise = Promise<Void>.pending();
        Background.runInBackground {
            self.provider.request(type, completion: {
                result in
                
                switch result {
                case let .success(moyaResponse):
                    do {
                        try moyaResponse.filterSuccessfulStatusAndRedirectCodes();
                        Background.runInMainThread {
                            UIApplication.shared.isNetworkActivityIndicatorVisible = false;
                            promise.fulfill();
                        }
                        
                    }
                    catch {
                        print(error);
                        Background.runInMainThread {
                            UIApplication.shared.isNetworkActivityIndicatorVisible = false;
                            promise.reject(error);
                        }
                    }
                    break;
                case let .failure(error):
                    Background.runInMainThread {
                        UIApplication.shared.isNetworkActivityIndicatorVisible = false;
                        promise.reject(error);
                    }
                    break;
                }
            });
        }
        
        return promise.promise;
    }
    
    
    //a wrapper for a request which returns an array of objects
    internal func makeRequestArray(_ type: JSONAPIRequest<T>) -> Promise<[T]> {
        let promise = Promise<[T]>.pending();
        self.provider.request(type, completion: {
            result in
            switch result {
            case let .success(moyaResponse):
                do {
                    _ = try moyaResponse.filterSuccessfulStatusAndRedirectCodes();
                    let objects: [T] = try moyaResponse.map(to: [T.self]);
                    promise.fulfill(objects);
                }
                catch {
                    print(error);
                    promise.reject(error);
                }
                break;
            case let .failure(error):
                promise.reject(error);
                break;
            }
        });
        
        return promise.promise;
    }
    
}



public class JSONAPIServiceModelStore {
    internal var objStore: [String: [String: PSJSONApiModel]] = [:]
    
    func addObj<T: PSJSONApiModel>(_ obj: T) {
        if self.objStore[T.modelName] == nil {
            self.objStore[T.modelName] = [:]
        }
        self.objStore[T.modelName]?[obj.id] = obj
    }
    
    func getObj<T: PSJSONApiModel>(byId id: String) -> T? {
        return self.objStore[T.modelName]?[id] as? T
    }
    
}

public enum JSONAPITargetMethod {
    case get
    case createObject
    case updateObject
    case deleteObject
    case getObject
}


