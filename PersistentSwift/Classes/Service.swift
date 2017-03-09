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



public struct TimeoutPlugin<T:PSJSONApiModel, S: JSONAPIServiceSettings>: PluginType {
    
    var timeoutGetter: ((JSONAPITargetType<T,S>) -> Double)?
    
    init(timeoutGetter: ((JSONAPITargetType<T,S>) -> Double)?) {
        self.timeoutGetter = timeoutGetter
    }
    
    /// Called to modify a request before sending
    public func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
        var req = request;
        if let timeout = self.timeoutGetter?(target as! JSONAPITargetType<T,S>) {
            req.timeoutInterval = timeout;
        }
        return req;
    }
    
    
}



public protocol JSONAPIServiceSettings {
    static var baseUrl: String { get }
    static var plugins: [PluginType] { get }
}



struct TestSettings: JSONAPIServiceSettings {
    
    public static var subbedJSONRequests: TestData.Type {
        return NoTestData.self
    }

    static var baseUrl: String {
        return "";
    }
    
    static var stubJSONInRequest: Bool {
        return false;
    }
    
    static var stubbedJSONRequests: TestData.Type {
        return NoTestData.self
    }
    
    static var verboseLogging: Bool {
        return false
    }
    
    static var testData: TestData.Type = NoTestData.self
    
    static var plugins: [PluginType] {
            return []
//        return [AuthPlugin(tokenClosure: self.getAuthToken),
//        TimeoutPlugin(timeoutGetter: self.getTimeout),
//        NetworkLoggerPlugin(verbose: self.verboseLogging)]
        
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

open class Query {
    public init() {
        
    }
}


public enum JSONAPITargetType<T: PSJSONApiModel, S: JSONAPIServiceSettings> {
    case get(query: Query)
    case createObject(obj: T)
    case updateObject(obj: T)
    case deleteObject(obj: T)
    case getObject(id: String)
}


extension JSONAPITargetType: TargetType {
    
    typealias Model = T;
    
    
    /// The target's base `URL`.
    public var baseURL: URL {
        return URL(string: S.baseUrl)!;
    }
    
    /// The path to be appended to `baseURL` to form the full `URL`.
    public var path: String {
        switch self {
        case .get:
            return "/\(T.modelName)";
        case .createObject(let obj):
            return "/\(T.modelName)";
        case .updateObject(let obj):
            return "/\(T.modelName)/\(obj.id)";
        case .deleteObject(let obj):
            return "/\(T.modelName)/\(obj.id)";
        case .getObject(let id):
            return "/\(T.modelName)/\(id)";
        }
    }
    
    /// The HTTP method used in the request.
    public var method: Moya.Method {
        switch self {
        case .get:
            return .get;
        case .createObject(_):
            return .post;
        case .updateObject(obj: _):
            return .patch;
        case .deleteObject(_):
            return .delete
        case .getObject(_):
            return .get
        }
    }
    
    /// The parameters to be incoded in the request.
    public var parameters: [String: Any]? {
        switch self {
        case .get:
            return nil;
        case .createObject(let obj):
            return obj.getCreateParameters(fromModelName: T.modelName);
        case .updateObject(let obj):
            return obj.getCreateParameters(fromModelName: T.modelName);
        case .deleteObject(_):
            return nil;
        case .getObject( _):
            return nil;
        }
    }
    
    /// The method used for parameter encoding.
    public var parameterEncoding: ParameterEncoding {
        switch self {
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
        switch self {
        case .get:
            return T.testData.getListTestData;
        case .createObject(_):
            return T.testData.getCreateTestData;
        case .updateObject(_):
            return T.testData.getCreateTestData;
        case .deleteObject(_):
            return T.testData.deleteTestData;
        case .getObject(_):
            return T.testData.getTestData;
        }
    }
    
    /// The type of HTTP task to be performed.
    public var task: Task {
        return Task.request
    }
    
    
}

