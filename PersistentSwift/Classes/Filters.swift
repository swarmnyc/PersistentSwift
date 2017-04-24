//
//  Filters.swift
//  Pods
//
//  Created by Alex Hartwell on 4/24/17.
//
//

import Foundation

public protocol JSONAPIFilter {
    func addToQuery(params: inout [String: Any])
    func getValueAsJSON() -> [String: Any]
}

public class JSONAPIEqualsFilter<T>: JSONAPIFilter {
    var jsonKey: String
    var value: T
    
    init(jsonKey: String, value: T) {
        self.jsonKey = jsonKey
        self.value = value
    }
    
    open func addToQuery(params: inout [String: Any]) {
        var filters: [String: Any] = self.getValueAsJSON()
        if let existingFilters = params["filter"] as? [String: Any] {
            filters.merge(with: existingFilters)
        }
        params["filter"] = filters
    }
    
    open func getValueAsJSON() -> [String: Any] {
        return [self.jsonKey: self.value]
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
    
    open override func getValueAsJSON() -> [String: Any] {
        return ["simple": [self.jsonKey: [self.operatorString: self.value]]]
    }
    
}

open class JSONAPIRequestSingle<T: PSJSONApiModel>: JSONAPIRequest<T> {
}

open class JSONAPIRequestEmptyResponse<T: PSJSONApiModel>: JSONAPIRequest<T> {
}
