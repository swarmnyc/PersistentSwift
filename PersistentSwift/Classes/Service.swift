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



open class TimeoutPlugin<T:PSJSONApiModel>: PluginType {
    
    var timeoutGetter: ((JSONAPITargetMethod<T>) -> Double)?
    
    public init(timeoutGetter: ((JSONAPITargetMethod<T>) -> Double)?) {
        self.timeoutGetter = timeoutGetter
    }
    
    /// Called to modify a request before sending
    public func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
        var req = request;
        if let timeout = self.timeoutGetter?(target as! JSONAPITargetMethod<T>) {
            req.timeoutInterval = timeout;
        }
        return req;
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

open class JSONAPIRequest<T: PSJSONApiModel> {
    var type: JSONAPITargetMethod<T>
    var settings: JSONAPIServiceSettings?
    var object: PSJSONApiModel
    var incudes: [String] = []
    
    open static func createSaveRequest(obj: T) -> JSONAPIRequest<T> {
        return JSONAPIRequest<T>(obj: obj).addType(JSONAPITargetMethod<T>.updateObject)
    }
    
    open static func getObject(id: String) -> JSONAPIRequest<T> {
        return JSONAPIRequest<T>(id: id).addType(JSONAPITargetMethod<T>.getObject)
    }
    
    open static func getObjects() -> JSONAPIRequest<T> {
        return JSONAPIRequest<T>(id: "").addType(JSONAPITargetMethod<T>.get)
    }
    
    internal init(id: String) {
        self.object = T()
        self.object.id = id
        self.type = .get
    }
    
    internal init(obj: PSJSONApiModel) {
        self.object = obj
        self.type = .get
    }
    
    func addType(_ type: JSONAPITargetMethod<T>) -> JSONAPIRequest<T> {
        self.type = type
        return self
    }
    
    func addSettings(_ settings: JSONAPIServiceSettings) -> JSONAPIRequest<T> {
        self.settings = settings
        return self
    }
    
    public func addIncludeType(_ type: PSJSONApiModel.Type) -> JSONAPIRequest<T> {
        return self
    }
    
    
    public func sortBy<V>(_ sort: inout V, ascending: Bool) -> JSONAPIRequest<T> {
        return self
    }
    
    public func whereAttribute<V>(_ value: inout V, equals: V) -> JSONAPIRequest<T> {
        return self
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
            return "/\(T.modelName)";
        case .createObject:
            return "/\(T.modelName)";
        case .updateObject:
            return "/\(T.modelName)/\(self.object.id)";
        case .deleteObject:
            return "/\(T.modelName)/\(self.object.id)";
        case .getObject:
            return "/\(T.modelName)/\(self.object.id)";
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
        switch self.type {
        case .get:
            return nil;
        case .createObject:
            return self.object.getCreateParameters(fromModelName: T.modelName);
        case .updateObject:
            return self.object.getCreateParameters(fromModelName: T.modelName);
        case .deleteObject:
            return nil;
        case .getObject:
            return nil;
        }
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


public enum JSONAPITargetMethod<T: PSJSONApiModel> {
    case get
    case createObject
    case updateObject
    case deleteObject
    case getObject
}


