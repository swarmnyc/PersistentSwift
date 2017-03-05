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
    
    
    open func saveNewObject(obj: T) -> Promise<T> {
        let request = APIMap.createObject(obj: obj);
        return service.makeRequest(request);
    }
    
    open func updateObject(obj: T) -> Promise<T> {
        let request = APIMap.updateObject(obj: obj);
        return service.makeRequest(request);
    }
    
    open func deleteObject(obj: T) -> Promise<Void> {
        let request = APIMap.deleteObject(obj: obj);
        return service.makeRequestNoObjectReturn(request);
    }
    
    open func getObject(obj: T) -> Promise<T> {
        let request = APIMap.getObject(obj: obj);
        return service.makeRequest(request);
    }
    
    
    open func getListOfObjects() -> Promise<[T]> {
        let request = APIMap.getList;
        return service.makeRequestArray(request);
    }
    
    open func getListOfObjects(params: [String: Any]) -> Promise<[T]> {
        let request = APIMap.getListWith(params: params);
        return service.makeRequestArray(request);
    }
    
    
    open func getPaginatedList(page: Int, limit: Int, params: [String: Any]) -> Promise<[T]> {
        let request = APIMap.getListPaginated(page: page, limit: limit, params: params);
        return service.makeRequestArray(request);
    }
    
    
}
