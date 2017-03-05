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


/// A cache for PSCachedModels, saves objects to NSUserDefaults via NSKeyedArchiver
open class PSModelCache<T: PSCachedModel> {
    
    /// an event emitter for addition, updates, or removals from cache
    var eventHandler: DataBindType<PSDataEvent<T>> = DataBindType<PSDataEvent<T>>(value: .none);
    /// the objects in the cache [String(object id): Model]
    var dictionaryCache: [String: T] = [:];
    
    /// appended to the model name when saving to user defaults (useful for multiple caches of the same obejct type)
    open var cacheId: String {
        get {
            return "";
        }
    }
    
    /// the model name and the cache id mashed together
    public var cacheName: String {
        get {
            return "\(T.modelName)\(self.cacheId)"
        }
    }
    
    public init() {
        
    }
    
    
    /// Hook into data events inside the cache
    ///
    /// - Parameter callback: the function to call when the cache is changed
    public func addCallbackOnCacheChange(_ callback: inout (PSDataEvent<T>) -> ()) {
        self.eventHandler.addBindee(&callback);
    }
    
    /// Get all of the models from the cache
    ///
    /// - Returns: an array containing every model in the cache
    public func getModelsFromCache() -> [T] {
        let array = Array(self.dictionaryCache.values);
        return array;
    }
    
    /// Get all of the models from the cache
    ///
    /// - Returns: A dicitonary of all of the caches objects [ModelID: Object]
    public func getModelsDictionaryFromCache() -> [String: T] {
        return self.dictionaryCache
    }
    
    /// Get a specific object from the cache
    ///
    /// - Parameter id: the id of the object you are looking for
    /// - Returns: the object, if found, or nil
    public func getModelFromCache(byId id: String) -> T? {
        return self.dictionaryCache[id];
    }
    
    
    
    /// Add a model to cache, will replace and call update events if a modle of the same id is already inside
    ///
    /// - Parameter model: the object to add
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
    
    /// Remove a model of id from cache
    ///
    /// - Parameter id: the id of the model to remove
    public func removeModelFromCache(ofId id: String) {
        if let model = self.dictionaryCache[id] {
            PSDataEvent.deleteData(model, eventHandler: &self.eventHandler);
            self.dictionaryCache.removeValue(forKey: id);
        }
    }
    
    /// add an array of objects to the cache
    ///
    /// - Parameter models: the models to add
    public func addModelsToCache(models: [T]) {
        for model in models {
            self.addModelToCache(model: model);
        }
    }
  
    /// Check if an object is in the cache
    ///
    /// - Parameter obj: the object to check for
    /// - Returns: true if it is in the cache, false if it isn't
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
    
    /// Save the cache in a background thread
    ///
    /// - Returns: a promise that will be fulfilled when saving is finished
    public func saveCacheInBackground() -> Promise<Void> {
        return Promise<Void> {
            fulfill, reject in
            Background.runInBackground {
                self.saveCache();
                fulfill();
            }
        }
    }
    
    
    /// remove everything from the cache, does not save the cache
    public func clearCache() {
        self.dictionaryCache = [:];
    }
    
    
}














