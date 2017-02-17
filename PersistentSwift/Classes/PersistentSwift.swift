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



open class PSModelCache {
    
    public static var shared: PSModelCache = PSModelCache();
    public var models: [PSCachedModel.Type] = [];

    
    var dictionaryCache: [String: [String: PSCachedModel]] = [:];
    
    
    public init() {
        
    }
    
    
    /// get models of type from the cache as an array
    ///
    /// - Parameter ofType: the type of object to get ex. SubclassCachedModel.self
    /// - Returns: the array of models if they exist, otherwise nil
    public func getModelsFromCache<T: PSCachedModel>(ofType: PSCachedModel.Type) -> [T]? {
        if let cache = self.dictionaryCache[ofType.modelName] {
            let array = Array(cache.values);
            return array as! [T];
        }
        return nil;
    }
    
    /// get models of a specific type from the cache as a dictionary [Id String: Obj]
    ///
    /// - Parameter ofType: the type of models you want ex SubclassCachedModel.self
    /// - Returns: the dictionary of models if they exist, otherwise nil
    public func getModelsDictionaryFromCache<T: PSCachedModel>(ofType: PSCachedModel.Type) -> [String: T]? {
        return self.dictionaryCache[ofType.modelName] as? [String: T];
    }
    
    
    /// Register model types to the cache
    ///
    /// - Parameter models: the types to add to the cache, looks like [PSCachedModel.self, SubclassCachedModel.self]
    public func registerModels(models: [PSCachedModel.Type]) {
        for model in models {
            self.models.append(model);
        }
    }
    
    
    
    /// add a model to the cache. It will find the proper cache based on the models type, append it and save the cache
    ///
    /// - Parameter model: the model to add
    /// - Returns: true if model was added to the cache, false if it was already in it
    public func addModelToCache(model: PSCachedModel) -> Bool {
        let type: PSCachedModel.Type = type(of: model);
        
        var inside: Bool = false;
        for model in self.models {
            if model.modelName == type.modelName {
                inside = true;
            }
        }
        if inside == false {
            assertionFailure("You did not register the model type \(type.modelName)");
            return false;
        }
        
        
        
        let name = type.modelName;
        
        self.createCacheIfNeeded(ofName: name);
        var alreadyInCache: Bool = self.isObjectInCache(ofName: name, obj: model);
        self.appendObjectToCache(ofName: name, obj: model);
        
        model.isInCache = true;
        
        return alreadyInCache == false;
    }
    
    
    func isObjectInCache(ofName name: String, obj: PSCachedModel) -> Bool {
        if (self.dictionaryCache[name]![obj.id] != nil) {
            return true;
        }
        return false;
    }
    
    func createCacheIfNeeded(ofName name: String) {
        if self.dictionaryCache[name] == nil {
            self.dictionaryCache[name] = [:];
        }
    }
    
    func appendObjectToCache(ofName name: String, obj: PSCachedModel) {
        self.dictionaryCache[name]?[obj.id] = obj;
        
    }
    
    /// load everything in the cache
    public func loadCache() {
        for model in self.models {
            if let data = UserDefaults.standard.object(forKey: model.modelName) as? Data {
                if let objs = NSKeyedUnarchiver.unarchiveObject(with: data) as? [String: PSCachedModel] {
                    self.dictionaryCache[model.modelName] = objs;
                }
            }
            
        }
    }
    
    /// save everything in the cache
    public func saveCache() {
        
        
        for model in self.models {
            self.createCacheIfNeeded(ofName: model.modelName);
            
            //look into removing duplicate objects
            //            let ar = $.uniq(self.cache[model.modelName]!, by: {
            //                return $0.id;
            //            });
            
            
            let data = NSKeyedArchiver.archivedData(withRootObject: self.dictionaryCache[model.modelName]!);
            UserDefaults.standard.setValue(data, forKeyPath: model.modelName);
            
        }
        UserDefaults.standard.synchronize();
    }
    
    
    public func clearCache() {
        self.dictionaryCache = [:];
    }
    
    public func clearCache(ofType type: PSCachedModel.Type) {
        self.dictionaryCache[type.modelName] = [:];
    }
    
   
    
    
}


//Generic Network Manager
open class PSNetworkManager<T: PSCachedModel, TestingData: TestData, S: PSServiceSettings> {
    
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

open class PSDataManager<T: PSCachedModel> {
    
   
    
    open static func getModelsArray() -> [T] {
        return T.models as! [T];
    }
    
    open static func getModelsDictionary() -> [String: T] {
        return T.modelsDictionary as! [String : T];
    }
    
    open static func getModel(byId id: String) -> T? {
        return T.getModel(byId: id) as? T
    }
    
    open static func getModels<V: Equatable where T: AnyObject>(byValue value: Any, forKey key: String, ofType type: V.Type) -> [T] {
        let allModels = T.models as! [T];
        var foundModels: [T] = [];
        for model in allModels {
            if let v = model.value(forKey: key) {
                if let equal = isEqual(type: type, a: v, b: value) {
                    if equal {
                        foundModels.append(model);
                    }
                }
            }
        }
        return foundModels;
        
    }
    
    open static func removeModelFromCache(id: String) {
        if let obj = PSModelCache.shared.dictionaryCache[T.modelName] as? PSCachedModel {
            PSDataEvent.deleteData(obj, eventHandler: &T.eventHandler);
        }
        PSModelCache.shared.dictionaryCache[T.modelName]?.removeValue(forKey: id);
    }
    
    
    /// add a model to the cache
    ///
    /// - Returns: returns true if the model was added to the cache, false if it was already in the cache
    open static func addData(obj: T) -> Bool {
        if obj.isInCache == true {
            return false;
        }
        
        let addedToCache = PSModelCache.shared.addModelToCache(model: obj);
        if addedToCache {
            PSDataEvent.addData(obj, eventHandler: &T.eventHandler);
        } else {
            PSDataEvent.updateData(obj, eventHandler: &T.eventHandler);
        }
        
        return addedToCache;
    }
    
    
    
    static func isEqual<T: Equatable>(type: T.Type, a: Any, b: Any) -> Bool? {
        guard let a = a as? T, let b = b as? T else { return nil }
        
        return a == b
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

public protocol PSModelValueProtocol {
    func setValueFromJSON(_ json: JSON)
}




open class PSModelValue<T: Any>: PSModelValueProtocol {
    private var value: T?
    private var path: String = "";
    
    public init(jsonPath path: String) {
        self.path = path;
    }
    
    public func get() -> T? {
        return value;
    }
    
    public func set(_ value: T) {
        self.value = value;
    }
    
    public func setValueFromJSON(_ json: JSON) {
        let paths = self.path.components(separatedBy: ".");
        var j = json;
        for path in paths {
            if let value = j[path].rawValue as? T {
                self.value = value;
            } else {
                j = j[path];
            }
        }
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
    
    var value: ValueType? { get set }
    
    var deserialize: ((Any) -> ValueType?)? { get set }
    var serialize: ((ValueType) -> Any)?{ get set }
    
    
    func get() -> ValueType?
    func set(_ value: ValueType?)
}


extension PSJSONAPIWithGet {
    public func get() -> ValueType? {
        return self.value;
    }
    
    public func set(_ value: ValueType?) {
        self.value = value;
    }
    
    public func decode(_ aDecoder: NSCoder) {
        if let value = aDecoder.decodeObject(forKey: self.jsonKey) as? ValueType {
            self.set(value);
        }
    }
    
}

public class PSAttribute<T>: PSJSONAPIWithGet {
    public var value: T?

    public var deserialize: ((Any) -> T?)?
    public var serialize: ((T) -> Any)?
    
    public var jsonKey: String = "";
    
    public init(value: T, serialize: ((_ value: T) -> Any)?, jsonKey: String?, deserialize: ((Any) -> T?)?) {
        self.value = value;
        if let jsonKey = jsonKey {
            self.jsonKey = jsonKey;
        }
        self.deserialize = deserialize;
        self.serialize = serialize;
    }
    
    public required init() {
        
    }
    
    public func serializeToJSON() -> Any? {
        if let v = self.value {
            if let serialize = self.serialize {
                return serialize(v);
            } else {
                return v;
            }
        }
        return nil;
    }
    
    public func deserializeFromJSON(_ json: JSON) {
        let paths = self.jsonKey.components(separatedBy: ".");
        var j = json;
        for path in paths {
            if let value = j[path].rawValue as? ValueType {
                self.value = value;
            } else {
                j = j[path];
            }
        }
        if let deserialize = self.deserialize {
            if let value = deserialize(j.rawValue) {
                self.value = value;
            }
        }
    }
    
    public func decode(_ aDecoder: NSCoder) {
        if let value = aDecoder.decodeObject(forKey: self.jsonKey) as? ValueType {
            self.set(value);
        }
    }

}


public class PSToOne<T: PSCachedModel>: PSJSONAPIWithGet {
    
    public var value: T?
     public var jsonKey: String = "";
    
    public var deserialize: ((Any) -> T?)?
    public var serialize: ((T) -> Any)?
    
    
    public var id: String = "";
    
    convenience public init(value: T?, jsonKey: String) {
        self.init();
        self.value = value;
        self.jsonKey = jsonKey;
    }
    
    
    public func set(_ value: T?) {
        self.value = value;
        if value == nil {
            self.id = "";
        } else {
            if let v = value {
                self.id = v.id;
            }
        }
    }
    
    
    public func serializeToJSON() -> Any? {
        var topLevel: [String: Any] = [:];
        var data: [String: Any] = [:];
        data["type"] = T.modelName;
        data["id"] = self.id;
        topLevel["data"] = data;
        return topLevel;
    }
    
    public func deserializeFromJSON(_ json: JSON) {
        if let id = json[jsonKey]["data"]["id"].string {
            self.id = id;
        }
    }
    
    
    public func decode(_ aDecoder: NSCoder) {
        if let value = aDecoder.decodeObject(forKey: self.jsonKey) as? [String: Any] {
            let json = JSON([self.jsonKey: value]);
            self.deserializeFromJSON(json);
        }

    }
    
}

public class PSToMany<T: PSCachedModel>: PSJSONAPIWithGet {
   

    public var jsonKey: String = "";
    
    public var value: [T]?
    public var ids: [String] = [];
    
    public var deserialize: ((Any) -> [T]?)?
    public var serialize: (([T]) -> Any)?
    
    convenience public init(value: [T]?, jsonKey: String) {
        self.init();
        self.value = value;
        self.jsonKey = jsonKey;
    }
 
    
    public func serializeToJSON() -> Any? {
        var topLevel: [String: Any] = [:];
        var data: [[String: Any]] = [];
        for id in self.ids {
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
            var ids: [String] = [];
            for data in dataArray {
                if let i = data["id"].string {
                    ids.append(i);
                }
            }
            self.ids = ids;
        }
    }
    
    
    public func addObject(_ obj: T) {
        self.ids.append(obj.id);
        self.value?.append(obj);
    }
    
    public func set(_ value: Array<T>?) {
        self.value = value;
        if let values = self.value {
            self.ids = [];
            for value in values {
                self.ids.append(value.id);
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








/// Base cached model
@objc open class PSCachedModel: NSObject, NSCoding {
    
    static var eventHandler: DataBindType<PSDataEvent<PSCachedModel>> = DataBindType<PSDataEvent<PSCachedModel>>(value: .none);
    
    open static func addCallbackOnCacheChange(_ callback: inout (PSDataEvent<PSCachedModel>) -> ()) {
        self.eventHandler.addBindee(&callback);
    }
    
    
    /// The name of the model (used in the model cache)
    open class var modelName: String {
        get {
            assertionFailure("did not override model name in a cached model type");
            return "Cached Model"
        }
    }
    
    
    
    /// helper property, it gets all of the cached models of this type from the model cache
    open class var models: [PSCachedModel] {
        get {
            if let models = PSModelCache.shared.getModelsFromCache(ofType: self) {
                return models;
            }
            return [];
        }
    }
    
    open class var modelsDictionary: [String: PSCachedModel] {
        get {
            if let models = PSModelCache.shared.getModelsDictionaryFromCache(ofType: self) {
                return models;
            }
            return [:];
        }
    }
    
    
    open class func getModel(byId id: String) -> PSCachedModel? {
        if let models = PSModelCache.shared.getModelsDictionaryFromCache(ofType: self) {
            if let model = models[id] {
                return model;
            }
        }
        return nil;
    }
    
    
    //I am assuming every model has an id (this property is not used in the internals of the cache, you can set it to whatever is in your db)
    public var id: String = "";
    
    public var isInCache: Bool = false;
    
    
    open var attributes: [PSJSONAPIProperty] {
        assertionFailure("You did not override attributes in PSCachedModel");
        return [];
    };
    
    
    open var relationships: [PSJSONAPIProperty] {
        assertionFailure("You did not override toOneRelationships in PSCachedModel");
        return [];
    }
 
 
    
    required public init?(json: JSON) {
        super.init();
        if let id = json["id"].string {
            self.id = id;
        }
        let a = json["attributes"];
        for atts in self.attributes {
            atts.deserializeFromJSON(a);
        }
        let relationships = json["relationships"];
        for rel in self.relationships {
            rel.deserializeFromJSON(relationships);
        }
    }
    
    public func getCreateParameters(fromModelName type: String) -> [String: Any]? {
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
        for attribute in self.attributes {
            aCoder.encode(attribute.serializeToJSON(), forKey: attribute.jsonKey);
        }
        for relationship in self.relationships {
            aCoder.encode(relationship.serializeToJSON(), forKey: relationship.jsonKey);
        }
    }
    
    
    
    
    public override init() {
        super.init();
    }
    
      
    
    //FOR TESTING PURPOSES ONLY
    public func forTestingAddToCache(cache: PSModelCache) -> Bool {
        if self.isInCache == true {
            return false;
        }
        
        let addedToCache = cache.addModelToCache(model: self);
        if addedToCache {
            PSDataEvent.addData(self, eventHandler: &type(of: self).eventHandler);
        } else {
            PSDataEvent.updateData(self, eventHandler: &type(of: self).eventHandler);
        }
        
        return addedToCache;
    }
    
    /// add a model to the cache
    ///
    /// - Returns: returns true if the model was added to the cache, false if it was already in the cache
    @available(*, deprecated, message: "Data events not firing properly in all situations")
    public func addToCache() -> Bool {
        return self.forTestingAddToCache(cache: PSModelCache.shared);
        
    }
    
    
    required public init?(coder aDecoder: NSCoder) {
        super.init();
        
        for attribute in self.attributes {
            attribute.decode(aDecoder)
        }
        for relationship in self.relationships {
            relationship.decode(aDecoder);
        }
    }
    
    
    
    
}
