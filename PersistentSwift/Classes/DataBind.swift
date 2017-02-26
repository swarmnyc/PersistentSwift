//
//  DataBind.swift
//  DataBind
//
//  Created by Alex Hartwell on 8/8/16.
//  Copyright © 2016 Alex Hartwell. All rights reserved.
//
import Foundation
import UIKit





open class DataBindee<A> {
    typealias DataBindCallback = (A) -> ()
    
    /// The callback that will be called when a data bind type gets set. The function has the value as the parameter.
    var callback: ((A) -> ())?
    var oldValueCellback: ((A, A) -> ())? //new value, old value
    
    /**
     Creates a Listener
     
     - parameter listener: A closure/function that takes the DataBindType Value as a parameter
     
     - returns: A Data Bind Listener
     */
    init (listener: inout (A) -> ()) {
        //self.callback = listener;
        
        
        self.callback = listener;
        
        
    }
    
}

////How to use
/*
 
 
 class Model {
 var dataBindedInt: DataBindType<Int> = DataBindType<Int>(value: 0);
 }
 
 class Controller {
 
 var model = Model();
 
 override func loadView() {
 super.loadView();
 self.model.dataBindedInt.addBindee(&self.onDataBindedIntChange);
 self.model.dataBindedInt.addBindee(&self.onDataBindedIntChangeWithOldValue);
 }
 
 
 var onDataBindedIntChange: DataBindCallback<Int> = {
 newValue in
 print("got the new value \(newValue)");
 }
 
 var onDataBindedIntChangeWithOldValue: DataBindCallbackWithOldValue<Int> = {
 newValue, oldValue in
 print("got the new value \(newValue) got the oldValue \(oldValue)");
 }
 
 
 
 }
 
 
 
 
 */


public typealias DataBindCallback<T> = (T) -> ()
public typealias DataBindCallbackWithOldValue<T> = (T,T) -> ()

class DataBindType<T> {
    
    
    private var value: T
    var bindees: [DataBindee<T>] = [];
    var dontRun: Bool = false;
    
    
    
    public init(value: T) {
        self.value = value;
    }
    
    public func addBindee(_ callback: inout (T) -> ()) {
        let listener: DataBindee = DataBindee<T>(listener: &callback);
        self.bindees.append(listener);
    }
    
    
    public func set(_ value: T) {
        let oldValue = self.value;
        self.value = value;
        if !dontRun {
            for bindee in bindees {
                bindee.callback?(value);
                bindee.oldValueCellback?(value, oldValue);
            }
        }
        self.dontRun = false;
        
    }
 
    public func get() -> T {
        return self.value;
    }
    
}
