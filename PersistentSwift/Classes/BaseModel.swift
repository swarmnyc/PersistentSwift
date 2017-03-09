//
//  BaseModel.swift
//  Pods
//
//  Created by Alex Hartwell on 3/4/17.
//
//

import Foundation
import SwiftyJSON

public protocol PSCachedModel {
    static var modelName: String { get }
    var id: String { get set }
}

open class JsonApiModel: NSObject, NSCoding, PSCachedModel {
    
    open class var modelName: String {
        assertionFailure("You did not override modelName in a PSJSONApiModel");
        return "";
    }
    
    public var id: String = "";
    /// is true if the object wasn't included in the API response and just contains the id
    public var isBlank: Bool = false
    
    var attributes: [PSJSONAPIProperty] = [];
    var relationships: [PSJSONAPIProperty] = [];
    
    required override public init() {
        super.init();
        self.register(attributes: &self.attributes, andRelationships: &self.relationships);
    }
    
    open func register(attributes: inout [PSJSONAPIProperty], andRelationships relationships: inout [PSJSONAPIProperty]) {
        assertionFailure("You did not override register(attribuets andRelationships) inside of an PSJSONApiModel");
    }
    
    
    public required convenience init?(json: JSON, include: JSON?, objStore: PSServiceModelStore) {
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
        if let incl = include {
            
            for relationships in self.relationships {
                relationships.addFromIncluded(incl, objStore: objStore)
            }
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
