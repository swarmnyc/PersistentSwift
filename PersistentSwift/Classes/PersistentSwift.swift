//
//  PersistantSwift.swift
//  PersistentSwift
//
//  Created by Alex Hartwell on 1/28/17.
//  Copyright © 2017 hartwell. All rights reserved.
//
import Foundation
import SwiftyJSON
import PromiseKit




public protocol PSCodableEnum {
    func int() -> Int;
    
    init?(rawValue:Int);
    
    init(defaultValue:Any)
    
}


extension NSCoder {
    func encodeEnum(_ anEnum: PSCodableEnum, forKey:String) {
        self.encode(anEnum.int(), forKey: forKey);
    };
    
    func decodeEnum<T: PSCodableEnum>(forKey key:String) -> T {
        if let t = T(rawValue:self.decodeInteger(forKey: key)) {
            return t
        } else {
            return T(defaultValue:0)
        }
    }
}



open class PSModelCache<T: PSCachedModel> {
    
    var eventHandler: DataBindType<PSDataEvent<T>> = DataBindType<PSDataEvent<T>>(value: .none);
    var dictionaryCache: [String: T] = [:];
    
    public init() {
        
    }
    
    
    public func addCallbackOnCacheChange(_ callback: inout (PSDataEvent<T>) -> ()) {
        self.eventHandler.addBindee(&callback);
    }
    
    public func getModelsFromCache() -> [T] {
        let array = Array(self.dictionaryCache.values);
        return array;
    }
    
    public func getModelsDictionaryFromCache() -> [String: T] {
        return self.dictionaryCache
    }
    
    public func getModelFromCache(byId id: String) -> T? {
        return self.dictionaryCache[id];
    }
    
    
    
    public func addModelToCache(model: T) {
        var alreadyInCache: Bool = self.isObjectInCache(model);
        self.appendObjectToCache(model);
        let addedToCache = alreadyInCache == false;
        
        if addedToCache {
            PSDataEvent.addData(model, eventHandler: &self.eventHandler);
        } else {
            PSDataEvent.updateData(model, eventHandler: &self.eventHandler);
        }
    }
    
    public func removeModelFromCache(ofId id: String) {
        if let model = self.dictionaryCache[id] {
            PSDataEvent.deleteData(model, eventHandler: &self.eventHandler);
            self.dictionaryCache.removeValue(forKey: id);
        }
    }
    
    
    public func addModelsToCache(models: [T]) {
        for model in models {
            self.addModelToCache(model: model);
        }
    }
    
    
    
    
    func isObjectInCache(_ obj: T) -> Bool {
        if (self.dictionaryCache[obj.id] != nil) {
            return true;
        }
        return false;
    }
    
    
    
    func appendObjectToCache(_ obj: T) {
        self.dictionaryCache[obj.id] = obj;
        
    }
    
    /// load everything in the cache
    public func loadCache() {
        if let data = UserDefaults.standard.object(forKey: T.modelName) as? Data {
            if let objs = NSKeyedUnarchiver.unarchiveObject(with: data) as? [String: T] {
                self.dictionaryCache = objs;
            }
        }
    }
    
    /// save everything in the cache
    public func saveCache() {
        Background.runInBackground {
            let data = NSKeyedArchiver.archivedData(withRootObject: self.dictionaryCache);
            UserDefaults.standard.setValue(data, forKey: T.modelName);
        }
    }
    
    
    public func clearCache() {
        self.dictionaryCache = [:];
    }
    
    
}




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



/// An Enum outlining different data events that can happen and exposing functions for hooking into and calling these events
///
/// - none: the starting value
/// - newDataAdded: call when you want to add data to the data store
/// - dataUpdated: call when you want to update data in the datastore
/// - removedData: call when you want to remove data in the datastore(may not be complete, not tested)
public enum PSDataEvent<T: PSCachedModel> {
    case none
    case newDataAdded(T)
    case dataUpdated(T)
    case dataDeleted(T)
    
    /// get the data associated with the event
    ///
    /// - Returns: returns the added, updated, or removed data
    public func getData() -> T? {
        switch self {
        case .none:
            return nil;
            break;
        case .newDataAdded(let data):
            return data;
            break;
        case .dataUpdated(let data):
            return data;
            break;
        case .dataDeleted(let data):
            return data;
            break;
            
        }
    }
    
    public func isDataAdded() -> Bool {
        switch self {
        case .newDataAdded(_):
            return true;
            break;
        default:
            return false;
            break;
        }
    }
    public func isDataUpdated() -> Bool {
        switch self {
        case .dataUpdated(_):
            return true;
            break;
        default:
            return false;
            break;
        }
    }
    
    public func isDataDeleted() -> Bool {
        switch self {
        case .dataDeleted:
            return true;
        default:
            return false;
            break;
        }
    }
    
    /// add data to the data store
    ///
    /// - Parameters:
    ///   - data: the object to add
    ///   - json: the json to populate the object with
    ///   - eventHandler: the event handler that will alert other objects about the addition
    static func addData(_ data: T, eventHandler: inout DataBindType<PSDataEvent>) {
        eventHandler.set(.newDataAdded(data));
    }
    
    
    /// update data in the data store
    ///
    /// - Parameters:
    ///   - data: the object to update
    ///   - json: the json to populate the object with
    ///   - eventHandler: the event handler that will alert other objects about the update
    static func updateData(_ data: T, eventHandler: inout DataBindType<PSDataEvent>) {
        eventHandler.set(.dataUpdated(data));
    }
    
    /// called when data is deleted from the data store
    ///
    /// - Parameters:
    ///   - data: the object that is being deleted
    ///   - eventHandler: the event handler htat will alert objects about the update
    static func deleteData(_ data: T, eventHandler: inout DataBindType<PSDataEvent>) {
        eventHandler.set(.dataDeleted(data));
    }
    
    
}





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
        var topLevel: [String: Any] = [:];
        var data: [String: Any] = [:];
        data["type"] = T.modelName;
        data["id"] = self.id.pointee;
        topLevel["data"] = data;
        return topLevel;
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

public protocol PSCachedModel {
    static var modelName: String { get }
    
    var id: String { get set }
        
}



open class PSJSONApiModel: NSObject, NSCoding, PSCachedModel {
    
    
    open class var modelName: String {
        assertionFailure("You did not override modelName in a PSJSONApiModel");
        return "";
    }
    
    public var id: String = "";
    
    
    var attributes: [PSJSONAPIProperty] = [];
    var relationships: [PSJSONAPIProperty] = [];
    
    override public init() {
        super.init();
        self.register(attributes: &self.attributes, andRelationships: &self.relationships);
    }
    
    open func register(attributes: inout [PSJSONAPIProperty], andRelationships relationships: inout [PSJSONAPIProperty]) {
        assertionFailure("You did not override register(attribuets andRelationships) inside of an PSJSONApiModel");
    }
    
    
    public required convenience init?(json: JSON) {
        self.init();
        
        if let id = json["id"].string {
            self.id = id;
        }
        
        let atts = json["attributes"]
        for attribute in self.attributes {
            attribute.deserializeFromJSON(atts);
        }
        let rel = json["relationships"];
        for relationship in self.relationships {
            relationship.deserializeFromJSON(rel);
        }
        
    }
    
    public required convenience init(coder aDecoder: NSCoder) {
        self.init();
        if let id = aDecoder.decodeObject(forKey: "id") as? String {
            self.id = id;
        }
        for attribute in self.attributes {
            attribute.decode(aDecoder)
        }
        for relationship in self.relationships {
            relationship.decode(aDecoder);
        }
    }
    
    
    open func getCreateParameters(fromModelName type: String) -> [String: Any]? {
        var params: [String: Any] = [:];
        
        var data: [String: Any] = [:];
        data["type"] = type;
        
        var attributes: [String: Any] = [:];
        for att in self.attributes {
            if let j = att.serializeToJSON() {
                attributes[att.jsonKey] = j;
            }
        }
        
        var relationships: [String: Any] = [:];
        for rel in self.relationships {
            if let j = rel.serializeToJSON() {
                relationships[rel.jsonKey] = j;
            }
        }
        
        data["attributes"] = attributes;
        data["relationships"] = relationships;
        params["data"] = data;
        
        return params;
        
        
        
    }
    
    open func encode(with aCoder: NSCoder) {
        aCoder.encode(self.id as? Any, forKey: "id");
        for attribute in self.attributes {
            aCoder.encode(attribute.serializeToJSON(), forKey: attribute.jsonKey);
        }
        for relationship in self.relationships {
            aCoder.encode(relationship.serializeToJSON(), forKey: relationship.jsonKey);
        }
    }
    
    
}

extension PSJSONApiModel {
    
    
    
    
}


