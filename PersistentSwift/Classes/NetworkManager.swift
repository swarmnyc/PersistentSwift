//
//  NetworkManager.swift
//  Pods
//
//  Created by Alex Hartwell on 3/4/17.
//
//

import Foundation
import PromiseKit
import Moya


public struct JSONAPIServiceSettings {
    public var baseUrl: String = ""
    public var spoofJSON: Bool = false
    public var testingJSON: TestData.Type = NoTestData.self
    
    public init() {
        
    }
}

//Generic Network Manager
open class JSONAPIService<T: PSJSONApiModel> {
    
    var plugins: [PluginType] = []
    
    var settings: JSONAPIServiceSettings
    //the actual object used to make the requests
    lazy var provider: MoyaProvider<JSONAPIRequest<T>> = self.getProvider();
    
    /// get a MoyaProvider to make API calls
    func getProvider() -> MoyaProvider<JSONAPIRequest<T>> {
        let provider = MoyaProvider<JSONAPIRequest<T>>(stubClosure: {
            _ in
            if self.settings.spoofJSON {
                return .immediate;
            } else {
                return .never
            }
        }, plugins: self.plugins
        )
        return provider;
    }

    public init(settings: JSONAPIServiceSettings) {
        self.settings = settings
    }
    
    
    open func makeRequest(request: JSONAPIRequest<T>) -> Promise<[T]> {
        var request = request.addSettings(self.settings)
        switch request.type {
        case .getObject:
            return self.makeRequest(request).then { obj -> [T] in
                return [obj]
            }
        case .deleteObject:
            return self.makeRequestNoObjectReturn(request).then(execute: { () -> [T] in
                let array: [T] = []
                return array
            })
        default:
            return self.makeRequestArray(request)
        }
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
                        let object = try moyaResponse.map(to: T.self);
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
        Background.runInMainThread {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true;
        }
        let promise = Promise<[T]>.pending();
        Background.runInBackground {
            self.provider.request(type, completion: {
                result in
                switch result {
                case let .success(moyaResponse):
                    Background.runInBackground {
                        do {
                            try moyaResponse.filterSuccessfulStatusAndRedirectCodes();
                            let objects = try moyaResponse.map(to: [T.self]) as! [T];
                            Background.runInMainThread {
                                UIApplication.shared.isNetworkActivityIndicatorVisible = false;
                                promise.fulfill(objects);
                            }
                        }
                        catch {
                            print(error);
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
        }
        
        return promise.promise;
    }
    
}
