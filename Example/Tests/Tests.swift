import UIKit
import XCTest
import PersistentSwift
import SwiftyJSON

class Tests: XCTestCase {
   
    class Cache: PSModelCache<TestModel> {
        
    }
    var cache = Cache();
    
    
    class TestModel: PSJSONApiModel {
        
        
        override class var modelName: String {
            get {
                return "Test Model"
            }
        }
        var relToManyId: [String]?
        var relToMany: [TestModel]?
        
        var relToOneId: String?
        var relToOne: TestModel?
        
        var name: String?
        var isLive: Bool?
        
        public override func register(attributes: inout [PSJSONAPIProperty], andRelationships relationships: inout [PSJSONAPIProperty]) {
            attributes.append(PSAttribute(property: &self.name, jsonKey: "name"));
            attributes.append(PSAttribute(property: &self.isLive, jsonKey: "isLive"));
            
            relationships.append(PSToMany(property: &self.relToMany, idProperty: &self.relToManyId, jsonKey: "relToMany"));
            relationships.append(PSToOne(property: &self.relToOne, idProperty: &self.relToOneId, jsonKey: "relToOne"));
        }
        
        
    }
    
    
    func testInOut() {
        
        
        class TestHolder {
            var pointer: UnsafeMutablePointer<Int?>;
            
            init(value: inout Int?) {
                let pointer: UnsafeMutablePointer<Int?> = UnsafeMutablePointer<Int?>(&value);
                pointer.pointee = value;
                self.pointer = pointer;
            }
            
            
        }
        
        class Test {
            
            var v: Int?;
            var holder: TestHolder?
            
            init() {
                self.holder = TestHolder(value: &self.v);
            }
            
            deinit {
                
                print("deinit")
                
                //exp.fulfill();
            }
            
        }
        
        
        let test: () -> () = {
            let t = Test();
            t.v = 0;
            t.v! += 5;
            XCTAssertEqual(t.v, t.holder!.pointer.pointee);
            t.holder!.pointer.pointee = nil;
            
            XCTAssertEqual(t.v, nil);
            
        }
        
        test();
        
        
        
    }
    
    func testInOutString() {
        
        
        class TestHolder {
            var pointer: UnsafeMutablePointer<String?>;
            
            init(value: inout String?) {
                let pointer: UnsafeMutablePointer<String?> = UnsafeMutablePointer<String?>(&value);
                pointer.pointee = value;
                self.pointer = pointer;
            }
            
            
        }
        
        class Test {
            
            var v: String?;
            var holder: TestHolder?
            
            init() {
                self.holder = TestHolder(value: &self.v);
            }
            
            deinit {
                
                print("deinit")
                
                //exp.fulfill();
            }
            
        }
        
        let t = Test();
        t.v = "";
        let test: () -> () = {
            
            t.v = "test"
            XCTAssertEqual(t.v, t.holder!.pointer.pointee);
            
            XCTAssertEqual(t.v, "test");
            t.holder!.pointer.pointee = nil;
            XCTAssertEqual(t.holder!.pointer.pointee, nil);
            
        }
        
        test();
        
        t.v = "what what";
        XCTAssertEqual(t.holder!.pointer.pointee, "what what");
        
        
    }
    
    
    
    
    //
    //
    
    func testCachedModels() {
        
        
        
        
        var newModel = TestModel();
        newModel.name = "test";
        newModel.isLive = false;
        cache.addModelToCache(model: newModel);
        
        newModel.relToOneId = "test";
        newModel.relToManyId = ["test1, test2"];
        
        
        let data = NSKeyedArchiver.archivedData(withRootObject: newModel);
        
        UserDefaults.standard.setValue(data, forKey: "cacheTest");
        
        
        if let dataFromCache = UserDefaults.standard.object(forKey: "cacheTest") as? Data {
            if let objs = NSKeyedUnarchiver.unarchiveObject(with: dataFromCache) as? TestModel {
                XCTAssertEqual(newModel.name, objs.name);
                XCTAssertEqual(newModel.isLive, objs.isLive);
                XCTAssertEqual(newModel.relToOneId, objs.relToOneId);
                XCTAssertEqual(newModel.relToManyId!, objs.relToManyId!);
            } else {
                XCTAssert(false);
            }
        } else {
            XCTAssert(false);
        }
        
        
        
        
    }
    
    
    func testTwoCaches() {
        
        class Cache2: PSModelCache<TestModel> {
            
            static var shared: Cache2 = Cache2();
            
            override var cacheId: String {
                get {
                    return "cache2";
                }
            }
            
        }
        let model = TestModel();
        model.id = "1";
        model.isLive = true;
        model.name = "hello";
        
        let model2 = TestModel();
        model2.id = "2";
        model2.isLive = false;
        model2.name = "h";
        
        cache.addModelToCache(model: model);
        Cache2.shared.addModelToCache(model: model2);
        
        cache.saveCache();
        Cache2.shared.saveCache();
        
        cache.clearCache();
        Cache2.shared.clearCache();
        
        cache.loadCache();
        Cache2.shared.loadCache();
        
        let cache1 = cache.getModelsFromCache();
        let cache2 = Cache2.shared.getModelsFromCache();
        
        XCTAssertEqual(cache1[0].id, "1");
        XCTAssertEqual(cache2[0].id, "2");
    }
    
    func testCacheName() {
        class Cache2: PSModelCache<TestModel> {
            
            static var shared: Cache2 = Cache2();
            
            override var cacheId: String {
                get {
                    return "cache2";
                }
            }
            
        }
        
        XCTAssertEqual(Cache2.shared.cacheName, "\(TestModel.modelName)cache2")
        
    }
    
    func testCache() {
        let exp = self.expectation(description: "loading cache works");
        let model = TestModel();
        model.id = "1";
        model.isLive = true;
        model.name = "hello";
        
        cache.addModelToCache(model: model);
        
        cache.saveCache();
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
            
            self.cache.clearCache();
            self.cache.loadCache();
            
            let newModel = self.cache.getModelFromCache(byId: "1");
            XCTAssertEqual(newModel?.isLive, model.isLive);
            XCTAssertEqual(newModel?.name, model.name);
            exp.fulfill();
            
        });
        self.waitForExpectations(timeout: 3, handler: nil);
        
    }
    
    func testRemoveFromCache() {
        let model = TestModel();
        model.id = "1";
        model.isLive = true;
        model.name = "hello";
        
        cache.addModelToCache(model: model);
        
        cache.saveCache();
        
        cache.removeModelFromCache(ofId: "1");
        XCTAssertEqual(cache.getModelsFromCache().count, 0);
    }
    
}
