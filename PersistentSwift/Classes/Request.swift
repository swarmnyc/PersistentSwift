//
//  Query.swift
//  Pods
//
//  Created by Alex Hartwell on 3/19/17.
//
//

import Foundation
import Moya
import Alamofire


open class JSONAPIRequest<T: PSJSONApiModel> {
    var type: JSONAPITargetMethod
    var settings: JSONAPIServiceSettings?
    public var object: T
    var includes: [String] = []
    
    var page: Int?
    var perPage: Int?
    
    var filters: [JSONAPIParamValue] = []
    var queries: [String: Any] = [:]
    
    lazy var mirror: Mirror = Mirror(reflecting: self.object)
    
    public typealias ReturnType = [T]
    
    open static func saveObject(obj: T) -> JSONAPIRequestSingle<T> {
        return JSONAPIRequestSingle<T>(obj: obj).addType(JSONAPITargetMethod.createObject)
    }
    
    open static func updateObject(obj: T) -> JSONAPIRequestSingle<T> {
        return JSONAPIRequestSingle<T>(obj: obj).addType(JSONAPITargetMethod.updateObject)
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
    
    init(obj: T) {
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
            _ = self.addIncludeType(type)
        }
        return self
    }
    
    
    public func sortBy(jsonKey: String, ascending: Bool) -> Self {
        self.setUpSort(jsonKey: jsonKey, ascending: ascending)
        return self
    }
    
    internal func setUpSort(jsonKey: String, ascending: Bool) {
        var filterstring = jsonKey
        if ascending == false {
            filterstring = "-\(filterstring)"
        }
        
        if self.queries["sort"] == nil {
            self.queries["sort"] = [filterstring]
        } else {
            var array = self.queries["sort"] as! [String]
            array.append(filterstring)
            self.queries["sort"] = array
        }
    }
    
    
    public func addCustomQueryParameter(toKey key: String, withValue value: [String: Any]) -> Self {
        if self.queries[key] == nil {
            self.queries[key] = [String: Any]()
        }
        if var dict = self.queries[key] as? [String: Any] {
            dict.merge(with: value)
            self.queries[key] = dict
        }
        return self
    }
    
    public func addFilter(_ filter: JSONAPIParamValue) -> Self {
        self.filters.append(filter)
        return self
    }
    
    public func whereAttribute<V>(jsonKey: String, equals: V) -> Self {
        for attribute in self.object.attributes {
            if attribute.jsonKey == jsonKey {
                guard let superAttribute = attribute as? PSAttribute<V> else {
                    break
                }
                superAttribute.value.pointee = equals
                if let query = superAttribute.serializeToJSON() {
                    let filter = JSONAPIEqualsFilter(jsonKey: jsonKey, value: query)
                    self.filters.append(filter)
                }
                
            }
        }
        
        return self
    }
    
    public func whereRelationship(jsonKey: String, idEquals id: String) -> Self {
        for relationships in self.object.relationships {
            if relationships.jsonKey == jsonKey {
                let filter = JSONAPIEqualsFilter(jsonKey: jsonKey, value: id)
                self.filters.append(filter)
            }
        }
        return self
    }
    
    public func whereRelationship<V: PSJSONApiModel>(jsonKey: String, equals obj: V) -> Self {
        self.whereRelationship(jsonKey: jsonKey, idEquals: obj.id)
        return self
    }
    
    
    public func createParameters() -> [String: Any] {
        var params: [String: Any] = [:]
        
        self.addPaginationParamsIfNeeded(currentParams: &params)
        self.addParametersFromObjectIfNeeded(currentParams: &params)
        self.addCustomQueries(currentParams: &params)
        self.addfilters(currentParams: &params)
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
    
    internal func addfilters(currentParams params: inout [String: Any]) {
        for filter in self.filters {
            if let property = self.getProperty(forJsonKey: filter.jsonKey) {
                filter.addToQuery(withProperty: property, params: &params)
            }
        }
    }
    
    internal func addCustomQueries(currentParams params: inout [String: Any]) {
        params.merge(with: self.queries)
    }
    
    
    fileprivate func getProperty(forJsonKey jsonKey: String) -> PSJSONAPIProperty? {
        for attribute in self.object.attributes {
            if attribute.jsonKey == jsonKey {
                return attribute
            }
        }
        for relationship in self.object.relationships {
            if relationship.jsonKey == jsonKey {
                return relationship
            }
        }
        return nil
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
        if let settings = self.settings {
            return settings.encodingManager.encoding(forTargetType: self)
        }
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

extension Dictionary {
    mutating func merge(with dictionary: Dictionary) {
        for (key, value) in dictionary {
            self[key] = value
        }
    }
}
