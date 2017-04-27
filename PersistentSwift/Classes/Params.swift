//
//  Filters.swift
//  Pods
//
//  Created by Alex Hartwell on 4/24/17.
//
//

import Foundation

public protocol JSONAPIParamValue {
    var jsonKey: String { get }
    func addToQuery(withProperty property: PSJSONAPIProperty, params: inout [String: Any])
    func getValueAsJSON(withProperty property: PSJSONAPIProperty) -> Any?
}

public class JSONAPISortQuery: JSONAPIParamValue {
    public var jsonKey: String = ""
    var filterString: String = ""
    var ascending: Bool = true
    

    
    open func addToQuery(withProperty property: PSJSONAPIProperty, params: inout [String: Any]) {
        if params["sort"] == nil {
            params["sort"] = []
        }
        guard var sortParams = params["sort"] as? [String] else {
            return
        }
        
        if ascending == false {
            self.filterString = "-\(self.filterString)"
        }
        sortParams.append(self.filterString)
        params["sort"] = sortParams
    }
    
    open func getValueAsJSON(withProperty property: PSJSONAPIProperty) -> Any? {
        return nil
    }
    
}

public class JSONAPIEqualsFilter<T>: JSONAPIParamValue {
    public var jsonKey: String
    var value: T
    
    init(jsonKey: String, value: T) {
        self.jsonKey = jsonKey
        self.value = value
    }
    
    open func addToQuery(withProperty property: PSJSONAPIProperty, params: inout [String: Any]) {
        guard var filters = self.getValueAsJSON(withProperty: property) as? [String: Any] else {
            return
        }
        if let existingFilters = params["filter"] as? [String: Any] {
            filters.merge(with: existingFilters)
        }
        params["filter"] = filters
    }
    
    open func getValueAsJSON(withProperty property: PSJSONAPIProperty) -> Any? {
        if let propertyJSON = property.serializeToJSON(fromValue: self.value) {
            return [self.jsonKey: propertyJSON]
        }
        return nil
    }
}

public enum JSONAPIFilterOperator {
    case lessThan
    case greaterThan
}

public class JSONAPISimpleSortFilter<T>: JSONAPIEqualsFilter<T> {
    var operatorDirection: JSONAPIFilterOperator = .greaterThan
    var operatorString: String {
        if self.operatorDirection == .greaterThan {
            return "$gt"
        } else {
            return "$lt"
        }
    }
    public convenience init(jsonKey: String, value: T, operator operatorDirection: JSONAPIFilterOperator) {
        self.init(jsonKey: jsonKey, value: value)
        self.operatorDirection = operatorDirection
    }
    
    fileprivate override init(jsonKey: String, value: T) {
        super.init(jsonKey: jsonKey, value: value)
    }
    
    open override func getValueAsJSON(withProperty property: PSJSONAPIProperty) -> Any? {
        if let propertyJSON = property.serializeToJSON(fromValue: self.value) {
            let dict: [String: Any] = ["simple": [self.jsonKey: [self.operatorString: propertyJSON]]]
            return dict
        }
        return nil
    }
    
}

open class JSONAPIRequestSingle<T: PSJSONApiModel>: JSONAPIRequest<T> {
}

open class JSONAPIRequestEmptyResponse<T: PSJSONApiModel>: JSONAPIRequest<T> {
}
