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
import Alamofire


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

open class JSONAPIRequestSingle<T: PSJSONApiModel>: JSONAPIRequest<T> {
}

open class JSONAPIRequestEmptyResponse<T: PSJSONApiModel>: JSONAPIRequest<T> {
}

open class JSONAPIRequest<T: PSJSONApiModel> {
    var type: JSONAPITargetMethod
    var settings: JSONAPIServiceSettings?
    var object: PSJSONApiModel
    var includes: [String] = []
    
    var page: Int?
    var perPage: Int?
    
    lazy var mirror: Mirror = Mirror(reflecting: self.object)
    
    public typealias ReturnType = [T]
    
    open static func createSaveRequest(obj: T) -> JSONAPIRequest<T> {
        return JSONAPIRequest<T>(obj: obj).addType(JSONAPITargetMethod.updateObject)
    }
    
    open static func getObject(id: String) -> JSONAPIRequestSingle<T> {
        return JSONAPIRequestSingle<T>(id: id).addType(JSONAPITargetMethod.getObject)
    }
    
    open static func getObjects() -> JSONAPIRequest<T> {
        return JSONAPIRequest<T>(id: "").addType(JSONAPITargetMethod.get)
    }
    
    open static func deleteObject(obj: T) -> JSONAPIRequestEmptyResponse<T> {
        return JSONAPIRequestEmptyResponse<T>(obj: obj).addType(JSONAPITargetMethod.deleteObject)
    }
    
    init(id: String) {
        self.object = T()
        self.object.id = id
        self.type = .get
    }
    
    init(obj: PSJSONApiModel) {
        self.object = obj
        self.type = .get
    }
    
    
    func addType(_ type: JSONAPITargetMethod) -> Self {
        self.type = type
        return self
    }
    
    func addSettings(_ settings: JSONAPIServiceSettings) -> Self {
        self.settings = settings
        return self
    }
    
    public func addPagination(page: Int, perPage: Int) -> Self {
        self.page = page
        self.perPage = perPage
        return self
    }
    
    public func addIncludeType(_ type: PSJSONApiModel.Type) -> Self {
        for relationship in self.object.relationships {
            if relationship.getPropertyType().modelName == type.modelName {
                self.includes.append(relationship.jsonKey)
            }
        }
        return self
    }
    
    public func addIncludeTypes(_ types: [PSJSONApiModel.Type]) -> Self {
        for type in types {
            self.addIncludeType(type)
        }
        return self
    }
    
    
    public func sortBy<V>(_ sort: inout V, ascending: Bool) -> Self {
//        let attributes = self.object.relationships + self.object.attributes
//        for attribute in attributes {
//            if attribute.
//        }
        return self
    }
    
    public func equals(_ callback: (T) -> ()) {
        
    }
    
    public func whereAttribute<V>(keyPath: String, equals: V) -> Self {
       
        
        return self
    }
    
    
    
    
    internal func createParameters() -> [String: Any] {
        var params: [String: Any] = [:]
        
        self.addPaginationParamsIfNeeded(currentParams: &params)
        self.addParametersFromObjectIfNeeded(currentParams: &params)
        return params
    }
    
    internal func addPaginationParamsIfNeeded(currentParams params: inout [String: Any]) {
        if let page = self.page {
            params["page"] = page
        }
        if let perPage = self.perPage {
            params["per_page"] = perPage
        }
    }
    
    internal func addParametersFromObjectIfNeeded(currentParams params: inout [String: Any]) {
        switch self.type {
        case .createObject, .updateObject:
            if let p = self.object.getCreateParameters(fromModelName: T.modelName) {
                params = p
            }
        default:
            return
        }

    }
    
}


extension JSONAPIRequest: TargetType {
    /// The target's base `URL`.
    public var baseURL: URL {
        if let settings = self.settings {
            return URL(string: settings.baseUrl)!;
        }
        assertionFailure("The Query request settings were never set")
        return URL(string: "something has gone wrong")!
    }
    
    /// The path to be appended to `baseURL` to form the full `URL`.
    public var path: String {
        switch self.type {
        case .get:
            return "/\(T.modelName)"
        case .createObject:
            return "/\(T.modelName)"
        case .updateObject:
            return "/\(T.modelName)/\(self.object.id)"
        case .deleteObject:
            return "/\(T.modelName)/\(self.object.id)"
        case .getObject:
            return "/\(T.modelName)/\(self.object.id)"
        }
    }
    
    /// The HTTP method used in the request.
    public var method: Moya.Method {
        switch self.type {
        case .get:
            return .get;
        case .createObject:
            return .post;
        case .updateObject:
            return .patch;
        case .deleteObject:
            return .delete
        case .getObject:
            return .get
        }
    }
    
    /// The parameters to be incoded in the request.
    public var parameters: [String: Any]? {
        return self.createParameters()
    }
    
    /// The method used for parameter encoding.
    public var parameterEncoding: ParameterEncoding {
        switch self.type {
        case .get:
            return URLEncoding.default;
        case .createObject(_):
            return JSONEncoding.default;
        case .updateObject(_):
            return JSONEncoding.default;
        case .deleteObject(_):
            return URLEncoding.default;
        case .getObject(_):
            return JSONEncoding.default;
        }
    }
    
    /// Provides stub data for use in testing.
    public var sampleData: Data {
        guard let settings = self.settings else {
            return Data()
        }
        switch self.type {
        case .get:
            return settings.testingJSON.getListTestData;
        case .createObject(_):
            return settings.testingJSON.getCreateTestData;
        case .updateObject(_):
            return settings.testingJSON.getCreateTestData;
        case .deleteObject(_):
            return settings.testingJSON.deleteTestData;
        case .getObject(_):
            return settings.testingJSON.getTestData;
        }
    }
    
    /// The type of HTTP task to be performed.
    public var task: Task {
        return Task.request
    }

}


public enum JSONAPITargetMethod {
    case get
    case createObject
    case updateObject
    case deleteObject
    case getObject
}


