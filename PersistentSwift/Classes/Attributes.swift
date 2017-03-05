//
//  Attributes.swift
//  Pods
//
//  Created by Alex Hartwell on 3/4/17.
//
//

import Foundation
import SwiftyJSON

public protocol PSJSONAPIProperty: class {
    var jsonKey: String { get set }
    
    
    func serializeToJSON() -> Any?
    func deserializeFromJSON(_ json: JSON)
    func decode(_ aDecoder: NSCoder)
}

public protocol PSJSONAPIWithGet: PSJSONAPIProperty {
    associatedtype ValueType
    
    var value: UnsafeMutablePointer<ValueType> { get set }
    
}




open class PSAttribute<T>: PSJSONAPIWithGet {
    
    public typealias ValueType = T?
    
    public var value: UnsafeMutablePointer<ValueType>
    
    public var jsonKey: String = "";
    
    public init(property: inout T?, jsonKey: String) {
        
        self.value = UnsafeMutablePointer<T?>(&property);
        self.jsonKey = jsonKey;
    }
    
    
    open func decode(_ aDecoder: NSCoder) {
        if let value = aDecoder.decodeObject(forKey: self.jsonKey) as? ValueType {
            self.value.pointee = value;
        }
    }
    
    
    open func deserializeFromJSON(_ json: JSON) {
        self.value.pointee = (json[self.jsonKey].rawValue as? T);
    }
    
    
    
    open func serializeToJSON() -> Any? {
        return self.value.pointee
    }
    
    
}


public class PSToOne<T: PSJSONApiModel>: PSJSONAPIWithGet {
    
    
    
    public typealias ValueType = T?
    
    public var value: UnsafeMutablePointer<ValueType>
    public var id: UnsafeMutablePointer<String?>
    public var jsonKey: String = "";
    
    
    public init(property: inout T?, idProperty: inout String?, jsonKey: String) {
        self.value = UnsafeMutablePointer<ValueType>(&property);
        self.id = UnsafeMutablePointer<String?>(&idProperty);
        self.jsonKey = jsonKey;
    }
    
    
    
    
    public func decode(_ aDecoder: NSCoder) {
        if let value = aDecoder.decodeObject(forKey: self.jsonKey) as? [String: Any] {
            let json = JSON([self.jsonKey: value]);
            self.deserializeFromJSON(json);
        }
        
    }
    
    
    
    
    public func serializeToJSON() -> Any? {
        if let id = self.id.pointee {
            var topLevel: [String: Any] = [:];
            var data: [String: Any] = [:];
            data["type"] = T.modelName;
            data["id"] = id;
            topLevel["data"] = data;
            return topLevel;
        } else {
            return nil;
        }
    }
    
    public func deserializeFromJSON(_ json: JSON) {
        if let id = json[jsonKey]["data"]["id"].string {
            self.id.pointee = id;
        }
    }
    
    
}

public class PSToMany<T: PSJSONApiModel>: PSJSONAPIWithGet {
    
    
    public typealias ValueType = [T]?
    
    public var value: UnsafeMutablePointer<ValueType>
    public var ids: UnsafeMutablePointer<[String]?>
    public var jsonKey: String = "";
    
    
    
    
    public init(property: inout [T]?, idProperty: inout [String]?, jsonKey: String) {
        self.value = UnsafeMutablePointer<[T]?>(&property);
        self.ids = UnsafeMutablePointer<[String]?>(&idProperty);
        self.jsonKey = jsonKey;
    }
    
    
    
    public func serializeToJSON() -> Any? {
        var topLevel: [String: Any] = [:];
        var data: [[String: Any]] = [];
        if let ids = self.ids.pointee {
            for id in ids {
                var d: [String: Any] = [:];
                d["type"] = T.modelName;
                d["id"] = id;
                data.append(d);
            }
        }
        
        topLevel["data"] = data;
        return topLevel
    }
    
    
    
    public func deserializeFromJSON(_ json: JSON) {
        if let dataArray = json[self.jsonKey]["data"].array {
            var ids: [String] = [];
            for data in dataArray {
                if let i = data["id"].string {
                    ids.append(i);
                }
            }
            self.ids.pointee = ids;
        }
    }
    
    
    public func decode(_ aDecoder: NSCoder) {
        if let value = aDecoder.decodeObject(forKey: self.jsonKey) as? [String: Any] {
            let json = JSON([self.jsonKey: value]);
            self.deserializeFromJSON(json);
        }
    }
    
}