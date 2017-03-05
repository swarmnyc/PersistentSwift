//
//  NetworkManager.swift
//  Pods
//
//  Created by Alex Hartwell on 3/4/17.
//
//

import Foundation
import PromiseKit

//Generic Network Manager
open class PSNetworkManager<T: PSJSONApiModel, TestingData: TestData, S: PSServiceSettings> {
    
    public typealias APIMap = PSServiceMap<T, TestingData, S>;
    
    lazy var service: PSService<T, TestingData, S> = {
        return PSService<T, TestingData, S>()
    }()
    
    public init() {
        
    }
    
    
    /// Save a new object to the API (a post request)
    ///
    /// - Parameter obj: the object to send up
    /// - Returns: A promise with the saved object
    open func saveNewObject(obj: T) -> Promise<T> {
        let request = APIMap.createObject(obj: obj);
        return service.makeRequest(request);
    }
    
    /// Update an object that already exists on the server (a patch request)
    ///
    /// - Parameter obj: the object to update
    /// - Returns: A promise with the updated object
    open func updateObject(obj: T) -> Promise<T> {
        let request = APIMap.updateObject(obj: obj);
        return service.makeRequest(request);
    }
    
    /// Delete an object on the server (a delete request)
    ///
    /// - Parameter obj: the object to delete
    /// - Returns: A Void promise after the delete finishes
    open func deleteObject(obj: T) -> Promise<Void> {
        let request = APIMap.deleteObject(obj: obj);
        return service.makeRequestNoObjectReturn(request);
    }
    
    /// Get a specific object from the server
    ///
    /// - Parameter obj: The object to get (can be populated with only the id)
    /// - Returns: A promise with the object
    open func getObject(obj: T) -> Promise<T> {
        let request = APIMap.getObject(obj: obj);
        return service.makeRequest(request);
    }
    
    
    /// Get all objects from the server (a plain old get request with no params)
    ///
    /// - Returns: A promise with an array of objects
    open func getListOfObjects() -> Promise<[T]> {
        let request = APIMap.getList;
        return service.makeRequestArray(request);
    }
    
    /// Get a list of objects with query parameters
    ///
    /// - Parameter params: The query parameters
    /// - Returns: A promise with an array of objects
    open func getListOfObjects(params: [String: Any]) -> Promise<[T]> {
        let request = APIMap.getListWith(params: params);
        return service.makeRequestArray(request);
    }
    
    
    /// A paginated get request
    ///
    /// - Parameters:
    ///   - page: the page you want
    ///   - limit: the number of objects per page
    ///   - params: query params to append to the request
    /// - Returns: A promise with an array of objects
    open func getPaginatedList(page: Int, limit: Int, params: [String: Any]) -> Promise<[T]> {
        let request = APIMap.getListPaginated(page: page, limit: limit, params: params);
        return service.makeRequestArray(request);
    }
    
    
}
