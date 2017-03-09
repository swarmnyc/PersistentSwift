//
//  Attributes.swift
//  Pods
//
//  Created by Alex Hartwell on 3/4/17.
//
//

import Foundation
import SwiftyJSON
import CoreLocation

public protocol PSJSONAPIProperty: class {
    var jsonKey: String { get set }
    
    /// Any transforms necessary to turn the property into json
    ///
    /// - Returns: Any representation of the property
    func serializeToJSON() -> Any?
    /// Any transforms necessary from the json to assing a value to the pointer
    ///
    /// - Parameter json: the json from the request
    func deserializeFromJSON(_ json: JSON)
    /// Setup relationships that are included inside of the JSON response
    ///
    /// - Parameter json: the "included" dictionary inside of the json Response
    func addFromIncluded(_ json: JSON, objStore: JSONAPIServiceModelStore)
    func decode(_ aDecoder: NSCoder)
}


public protocol PSJSONAPIWithGet: PSJSONAPIProperty {
    associatedtype ValueType
    
    var value: UnsafeMutablePointer<ValueType> { get set }
    
}

extension PSJSONAPIWithGet {
    fileprivate func isModelNameEqual(json: JSON, modelType: PSJSONApiModel.Type) -> Bool {
        return json["type"].string == modelType.modelName
    }
    
    fileprivate func isIdEqual(json: JSON, value: PSJSONApiModel) -> Bool {
        return json["id"].string == value.id
    }
}




/// A basic attribute property (takes care of transforming from json to a swift object
open class PSAttribute<T>: PSJSONAPIWithGet {
    
    public typealias ValueType = T
    
    public var value: UnsafeMutablePointer<ValueType>
    
    public var jsonKey: String = "";
    
    /// Create an attribute object
    ///
    /// - Parameters:
    ///   - property: a pointer to the property
    ///   - jsonKey: the name of the property in the JSON response
    public init(property: inout T, jsonKey: String) {
        
        self.value = UnsafeMutablePointer<T>(&property);
        self.jsonKey = jsonKey;
    }
    
    
    open func decode(_ aDecoder: NSCoder) {
        if let value = aDecoder.decodeObject(forKey: self.jsonKey) as? ValueType {
            self.value.pointee = value;
        }
    }
    
    
    /// Any transforms necessary from the json to assing a value to the pointer
    ///
    /// - Parameter json: the json from the request
    open func deserializeFromJSON(_ json: JSON) {
        if let value = json[self.jsonKey].rawValue as? T {
            self.value.pointee = value;
        }
    }
    
    
    
    /// Any transforms necessary to turn the property into json
    ///
    /// - Returns: Any representation of the property
    open func serializeToJSON() -> Any? {
        return self.value.pointee
    }
    
    
    public func addFromIncluded(_ json: JSON, objStore: JSONAPIServiceModelStore) {
        
    }
    
}


open class PSLocationAttribute: PSAttribute<CLLocationCoordinate2D> {
    
    open override func serializeToJSON() -> Any? {
        return [self.value.pointee.longitude, self.value.pointee.latitude]
    }
    
    open override func deserializeFromJSON(_ json: JSON) {
        if let value = json[self.jsonKey].array {
            self.value.pointee = CLLocationCoordinate2D(latitude: value[0].doubleValue, longitude: value[1].doubleValue)
        }
    }
    
}

/// Takes care of bridging to one relationships from swift to json
public class PSToOne<T: PSJSONApiModel>: PSJSONAPIWithGet {
    
    
    public typealias ModelType = T
    public typealias ValueType = T?
    
    public var value: UnsafeMutablePointer<ValueType>
    public var jsonKey: String = "";
    
    
    /// Create a PSToOne object
    ///
    /// - Parameters:
    ///   - property: a pointer to the property
    ///   - idProperty: a pointer to a property holding the id of the relationship object
    ///   - jsonKey: the name of the key in the json response
    public init(property: inout T?, jsonKey: String) {
        self.value = UnsafeMutablePointer<ValueType>(&property);
        self.jsonKey = jsonKey;
    }
    
    
    
    
    public func decode(_ aDecoder: NSCoder) {
        if let value = aDecoder.decodeObject(forKey: self.jsonKey) as? [String: Any] {
            let json = JSON([self.jsonKey: value]);
            self.deserializeFromJSON(json);
        }
        
    }
    
    
    
    /// Any transforms necessary to turn the property into json
    ///
    /// - Returns: Any representation of the property
    public func serializeToJSON() -> Any? {
        if let obj = self.value.pointee {
            if obj.id != "" {
                return self.setUpJsonForId(obj.id)
            }
        }
        return nil
        
    }
    
    fileprivate func setUpJsonForId(_ id: String) -> Any? {
        var topLevel: [String: Any] = [:];
        var data: [String: Any] = [:];
        data["type"] = T.modelName;
        data["id"] = id;
        topLevel["data"] = data;
        return topLevel;
        
    }
    
    /// Any transforms necessary from the json to assing a value to the pointer
    ///
    /// - Parameter json: the json from the request
    public func deserializeFromJSON(_ json: JSON) {
        if let id = json[jsonKey]["data"]["id"].string {
            let obj = ModelType()
            obj.id = id
            obj.isBlank = true
            self.value.pointee = obj
        }
    }
    
    public func addFromIncluded(_ json: JSON, objStore: JSONAPIServiceModelStore) {
        let json = json.arrayValue
        if let value = self.value.pointee {
            if let obj: ModelType = objStore.getObj(byId: value.id) {
                self.value.pointee = obj
                return
            }
            for entry in json {
                if self.isIdEqual(json: entry, value: value) && self.isModelNameEqual(json: entry, modelType: ModelType.self) {
                    let newObj = ModelType(json: entry, include: nil, objStore: objStore)
                    self.value.pointee = newObj
                    if let newObj = newObj {
                        objStore.addObj(newObj)
                    }
                }
            }
        }
    }
    
    
    
}

/// Takes care of bridging to many relationships from swift to json
public class PSToMany<T: PSJSONApiModel>: PSJSONAPIWithGet {
    
    public typealias ModelType = T
    public typealias ValueType = [T]
    
    public var value: UnsafeMutablePointer<ValueType>
    public var jsonKey: String = "";
    
    
    
    /// Create a PSToMany object
    ///
    /// - Parameters:
    ///   - property: a pointer to the property
    ///   - idProperty: a pointer to a property holding the id of the relationship object
    public init(property: inout [T], jsonKey: String) {
        self.value = UnsafeMutablePointer<[T]>(&property);
        self.jsonKey = jsonKey;
    }
    
    
    
    public func serializeToJSON() -> Any? {
        var topLevel: [String: Any] = [:];
        var data: [[String: Any]] = [];
        let objs = self.value.pointee
        for obj in objs {
            let id = obj.id
            var d: [String: Any] = [:];
            d["type"] = T.modelName;
            d["id"] = id;
            data.append(d);
        }
        topLevel["data"] = data;
        return topLevel
    }
    
    
    
    public func deserializeFromJSON(_ json: JSON) {
        if let dataArray = json[self.jsonKey]["data"].array {
            var objs: [ModelType] = [];
            for data in dataArray {
                if let i = data["id"].string {
                    let obj = ModelType()
                    obj.id = i
                    obj.isBlank = true
                    objs.append(obj)
                }
            }
            self.value.pointee = objs
        }
    }
    
    public func addFromIncluded(_ json: JSON, objStore: JSONAPIServiceModelStore) {
        let json = json.arrayValue
        let values = self.value.pointee
        for (i, value) in values.enumerated() {
            if let obj: T = objStore.getObj(byId: value.id) {
                self.value.pointee[i] = obj
                continue
            }
            for entry in json {
                if self.isIdEqual(json: entry, value: value) && self.isModelNameEqual(json: entry, modelType: ModelType.self) {
                    if let newObj = ModelType(json: entry, include: nil, objStore: objStore) {
                        self.value.pointee[i] = newObj
                        objStore.addObj(newObj)
                    }
                }
            }
        }
    }
    
    public func decode(_ aDecoder: NSCoder) {
        if let value = aDecoder.decodeObject(forKey: self.jsonKey) as? [String: Any] {
            let json = JSON([self.jsonKey: value]);
            self.deserializeFromJSON(json);
        }
    }
    
}
