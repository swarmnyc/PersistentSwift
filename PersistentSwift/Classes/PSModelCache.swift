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


open class PSModelCache<T: PSCachedModel> {
    
    var eventHandler: DataBindType<PSDataEvent<T>> = DataBindType<PSDataEvent<T>>(value: .none);
    var dictionaryCache: [String: T] = [:];
    
    open var cacheId: String {
        get {
            return "";
        }
    }
    
    public var cacheName: String {
        get {
            return "\(T.modelName)\(self.cacheId)"
        }
    }
    
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
        if let data = UserDefaults.standard.object(forKey: self.cacheName) as? Data {
            if let objs = NSKeyedUnarchiver.unarchiveObject(with: data) as? [String: T] {
                self.dictionaryCache = objs;
            }
        }
    }
    
    /// save everything in the cache
    public func saveCache() {
            let data = NSKeyedArchiver.archivedData(withRootObject: self.dictionaryCache);
            UserDefaults.standard.setValue(data, forKey: self.cacheName);
    }
    
    public func saveCacheInBackground() -> Promise<Void> {
        return Promise<Void> {
            fulfill, reject in
            Background.runInBackground {
                self.saveCache();
                fulfill();
            }
        }
    }
    
    
    public func clearCache() {
        self.dictionaryCache = [:];
    }
    
    
}














