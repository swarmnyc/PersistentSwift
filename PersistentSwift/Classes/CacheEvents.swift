//
//  CacheEvents.swift
//  Pods
//
//  Created by Alex Hartwell on 3/4/17.
//
//

import Foundation



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
        case .newDataAdded(let data):
            return data;
        case .dataUpdated(let data):
            return data;
        case .dataDeleted(let data):
            return data;
        }
    }
    
    public func isDataAdded() -> Bool {
        switch self {
        case .newDataAdded(_):
            return true;
        default:
            return false;
        }
    }
    public func isDataUpdated() -> Bool {
        switch self {
        case .dataUpdated(_):
            return true;
        default:
            return false;
        }
    }
    
    public func isDataDeleted() -> Bool {
        switch self {
        case .dataDeleted:
            return true;
        default:
            return false;
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
