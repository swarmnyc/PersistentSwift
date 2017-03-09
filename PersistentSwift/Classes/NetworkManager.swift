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



//Generic Network Manager
open class JSONAPIService<T: PSJSONApiModel, S: JSONAPIServiceSettings> {
    
    
    
    
    public typealias APIMap = JSONAPITargetType<T, S>;
    
    
    //the actual object used to make the requests
    lazy var provider: MoyaProvider<JSONAPITargetType<T, S>> = self.getProvider();
    
    /// get a MoyaProvider to make API calls
    func getProvider() -> MoyaProvider<JSONAPITargetType<T, S>> {
        let provider = MoyaProvider<JSONAPITargetType<T, S>>(stubClosure: {
            _ in
            if T.shouldStubJson {
                return .immediate;
            } else {
                return .never
            }
        }, plugins: S.plugins
        )
        return provider;
    }
    
    
    public init() {
    }
    
    /// Save a new object to the API (a post request)
    ///
    /// - Parameter obj: the object to send up
    /// - Returns: A promise with the saved object
    open func saveNewObject(obj: T) -> Promise<T> {
        let request = APIMap.createObject(obj: obj);
        return self.makeRequest(request);
    }
    
    /// Update an object that already exists on the server (a patch request)
    ///
    /// - Parameter obj: the object to update
    /// - Returns: A promise with the updated object
    open func updateObject(obj: T) -> Promise<T> {
        let request = APIMap.updateObject(obj: obj);
        return self.makeRequest(request);
    }
    
    /// Delete an object on the server (a delete request)
    ///
    /// - Parameter obj: the object to delete
    /// - Returns: A Void promise after the delete finishes
    open func deleteObject(obj: T) -> Promise<Void> {
        let request = APIMap.deleteObject(obj: obj);
        return self.makeRequestNoObjectReturn(request);
    }
    
    /// Get a specific object from the server
    ///
    /// - Parameter obj: The object to get (can be populated with only the id)
    /// - Returns: A promise with the object
    open func getObject(id: String) -> Promise<T> {
        let request = APIMap.getObject(id: id);
        return self.makeRequest(request);
    }
    
    
    /// Get all objects from the server (a plain old get request with no params)
    ///
    /// - Returns: A promise with an array of objects
    open func getListOfObjects(query: Query) -> Promise<[T]> {
        let request = APIMap.get(query: query);
        return self.makeRequestArray(request);
    }
    
  
    
    
    
    //a wrapper for a request which returns a single object, type is the type of request, defined in the API map
    internal func makeRequest(_ type: JSONAPITargetType<T, S>) -> Promise<T> {
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
    
    internal func makeRequestNoObjectReturn(_ type: JSONAPITargetType<T, S>) -> Promise<Void> {
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
    internal func makeRequestArray(_ type: JSONAPITargetType<T, S>) -> Promise<[T]> {
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
