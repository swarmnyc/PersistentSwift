import UIKit
import XCTest
import PersistentSwift
import SwiftyJSON
// swiftlint:disable:next type_body_length
class Tests: XCTestCase {

    class Cache: PSModelCache<TestModel> {

    }
    var cache = Cache()

    class TestModel: PSJSONApiModel {

        override class var modelName: String {
            return "Test Model"
        }
        var relToMany: [TestModel] = []

        var relToOne: TestModel?

        var name: String?
        var isLive: Bool?
        // swiftlint:disable:next line_length
        public override func register(attributes: inout [PSJSONAPIProperty], andRelationships relationships: inout [PSJSONAPIProperty]) {
            attributes.append(PSAttribute(property: &self.name, jsonKey: "name"))
            attributes.append(PSAttribute(property: &self.isLive, jsonKey: "isLive"))

            //swiftlint:disable:next line_length
            relationships.append(PSToMany(property: &self.relToMany, jsonKey: "relToMany"))
            relationships.append(PSToOne(property: &self.relToOne, jsonKey: "relToOne"))
        }

    }
    //swiftlint:disable trailing_whitespace
    
    class TestHolder {
        var pointer: UnsafeMutablePointer<Int?>
        
        init(value: inout Int?) {
            let pointer: UnsafeMutablePointer<Int?> = UnsafeMutablePointer<Int?>(&value)
            pointer.pointee = value
            self.pointer = pointer
        }
        
    }
    
    class Test {
        
        var value: Int?
        var holder: TestHolder?
        
        init() {
            self.holder = TestHolder(value: &self.value)
        }
        
        deinit {
            
            print("deinit")
            
            //exp.fulfill();
        }
        
    }
    
    func testInOut() {

        let test: () -> Void = {
            let t = Test()
            t.value = 0
            t.value! += 5
            XCTAssertEqual(t.value, t.holder!.pointer.pointee)
            t.holder!.pointer.pointee = nil

            XCTAssertEqual(t.value, nil)

        }

        test()

    }

    func testInOutString() {
        // swiftlint:disable nesting
        class TestHolder {
            var pointer: UnsafeMutablePointer<String?>

            init(value: inout String?) {
                let pointer: UnsafeMutablePointer<String?> = UnsafeMutablePointer<String?>(&value)
                pointer.pointee = value
                self.pointer = pointer
            }

        }

        class Test {

            var value: String?
            var holder: TestHolder?

            init() {
                self.holder = TestHolder(value: &self.value)
            }

            deinit {

                print("deinit")

                //exp.fulfill();
            }

        }

        let t = Test()
        t.value = ""
        let test: () -> Void = {

            t.value = "test"
            XCTAssertEqual(t.value, t.holder!.pointer.pointee)

            XCTAssertEqual(t.value, "test")
            t.holder!.pointer.pointee = nil
            XCTAssertEqual(t.holder!.pointer.pointee, nil)

        }

        test()

        t.value = "what what"
        XCTAssertEqual(t.holder!.pointer.pointee, "what what")

    }

    func testCachedModels() {

        let newModel = TestModel()
        newModel.name = "test"
        newModel.isLive = false
        cache.addModelToCache(model: newModel)

        let relToOneModel = TestModel()
        relToOneModel.id = "test"
        newModel.relToOne = relToOneModel
        
        let testModel = TestModel()
        testModel.id = "test1"
        
        let testModel2 = TestModel()
        testModel2.id = "test2"
        
        newModel.relToMany = [testModel, testModel2]

        let data = NSKeyedArchiver.archivedData(withRootObject: newModel)

        UserDefaults.standard.setValue(data, forKey: "cacheTest")

        if let dataFromCache = UserDefaults.standard.object(forKey: "cacheTest") as? Data {
            if let objs = NSKeyedUnarchiver.unarchiveObject(with: dataFromCache) as? TestModel {
                XCTAssertEqual(newModel.name, objs.name)
                XCTAssertEqual(newModel.isLive, objs.isLive)
                XCTAssertEqual(newModel.relToOne?.id, objs.relToOne?.id)
                XCTAssertEqual(newModel.relToMany.count, objs.relToMany.count)
            } else {
                XCTAssert(false)
            }
        } else {
            XCTAssert(false)
        }

    }

    func testTwoCaches() {

        class Cache2: PSModelCache<TestModel> {

            static var shared: Cache2 = Cache2()

            override var cacheId: String {
                get {
                    return "cache2"
                }
            }

        }
        let model = TestModel()
        model.id = "1"
        model.isLive = true
        model.name = "hello"

        let model2 = TestModel()
        model2.id = "2"
        model2.isLive = false
        model2.name = "h"

        cache.addModelToCache(model: model)
        Cache2.shared.addModelToCache(model: model2)

        cache.saveCache()
        Cache2.shared.saveCache()

        cache.clearCache()
        Cache2.shared.clearCache()

        cache.loadCache()
        Cache2.shared.loadCache()

        let cache1 = cache.getModelsFromCache()
        let cache2 = Cache2.shared.getModelsFromCache()

        XCTAssertEqual(cache1[0].id, "1")
        XCTAssertEqual(cache2[0].id, "2")
    }

    func testCacheName() {
        class Cache2: PSModelCache<TestModel> {

            static var shared: Cache2 = Cache2()

            override var cacheId: String {
                get {
                    return "cache2"
                }
            }

        }

        XCTAssertEqual(Cache2.shared.cacheName, "\(TestModel.modelName)cache2")

    }

    func testCache() {
        let model = TestModel()
        model.id = "1"
        model.isLive = true
        model.name = "hello"

        cache.addModelToCache(model: model)

        cache.saveCache()
        
        self.cache.clearCache()
        self.cache.loadCache()
        
        let newModel = self.cache.getModelFromCache(byId: "1")
        XCTAssertEqual(newModel?.isLive, model.isLive)
        XCTAssertEqual(newModel?.name, model.name)
        
    }
    
    func testAddingArrayToCache() {
        let model = TestModel()
        model.id = "1"
        model.isLive = true
        model.name = "hello"

        let model2 = TestModel()
        model2.id = "2"
        model2.isLive = true
        model2.name = "hello"

        self.cache.addModelsToCache(models: [model, model2])
        
        XCTAssertEqual(self.cache.getModelsFromCache().count, 2)
        XCTAssertEqual(self.cache.getModelsDictionaryFromCache().count, 2)
    }
    
    func testCacheInBackground() {
        let exp = self.expectation(description: "loading cache works")
        let model = TestModel()
        model.id = "1"
        model.isLive = true
        model.name = "hello"
        
        cache.addModelToCache(model: model)
        _ = cache.saveCacheInBackground().then { () -> Void in
            self.cache.clearCache()
            self.cache.loadCache()
            
            let newModel = self.cache.getModelFromCache(byId: "1")
            XCTAssertEqual(newModel?.isLive, model.isLive)
            XCTAssertEqual(newModel?.name, model.name)
            exp.fulfill()

        }
        
        self.waitForExpectations(timeout: 3, handler: nil)
        
    }

    func testRemoveFromCache() {
        let model = TestModel()
        model.id = "1"
        model.isLive = true
        model.name = "hello"

        cache.addModelToCache(model: model)

        cache.saveCache()

        cache.removeModelFromCache(ofId: "1")
        XCTAssertEqual(cache.getModelsFromCache().count, 0)
    }
    
    func testPSDataEventGetData() {
        let model = TestModel()
        model.id = "1"
        model.isLive = true
        model.name = "hello"
        let event = PSDataEvent.dataDeleted(model)
        XCTAssertEqual(event.getData()!.id, "1")
        model.id = "2"
        let event2 = PSDataEvent.dataUpdated(model)
        XCTAssertEqual(event2.getData()!.id, "2")
        model.id = "3"
        let event3 = PSDataEvent.newDataAdded(model)
        XCTAssertEqual(event3.getData()!.id, "3")
        
        let event4 = PSDataEvent<TestModel>.none
        XCTAssertEqual(event4.getData(), nil)
        
    }
    
    func testPSDataEventEventType() {
        let model = TestModel()
        model.id = "1"
        model.isLive = true
        model.name = "hello"
        let event = PSDataEvent.dataDeleted(model)
        XCTAssertEqual(event.isDataDeleted(), true)
        XCTAssertEqual(event.isDataUpdated(), false)
        XCTAssertEqual(event.isDataAdded(), false)
        model.id = "2"
        let event2 = PSDataEvent.dataUpdated(model)
        XCTAssertEqual(event2.isDataUpdated(), true)
        XCTAssertEqual(event2.isDataDeleted(), false)
        XCTAssertEqual(event2.isDataAdded(), false)
        model.id = "3"
        let event3 = PSDataEvent.newDataAdded(model)
        XCTAssertEqual(event3.isDataAdded(), true)
        XCTAssertEqual(event3.isDataDeleted(), false)
        XCTAssertEqual(event3.isDataUpdated(), false)
        
        let event4 = PSDataEvent<TestModel>.none
        XCTAssertEqual(event4.getData(), nil)
        XCTAssertEqual(event4.isDataAdded(), false)
        XCTAssertEqual(event4.isDataDeleted(), false)
        XCTAssertEqual(event4.isDataUpdated(), false)
    }
    
    func testEventHandlerOnAddOnCache() {
        let expAdd = self.expectation(description: "add callback gets called")
        var callbackAdd: (PSDataEvent<TestModel>) -> Void = { event in
            if event.isDataAdded() {
                expAdd.fulfill()
            }
        }
        let expUpdate = self.expectation(description: "update callback gets called")
        var callbackUpdate: (PSDataEvent<TestModel>) -> Void = { event in
            if event.isDataUpdated() {
                expUpdate.fulfill()
            }
        }
        let expDelete = self.expectation(description: "deleteUpdateGetsCalled")
        var callbackDelete: (PSDataEvent<TestModel>) -> Void = { event in
            if event.isDataDeleted() {
                expDelete.fulfill()
            }
        }
        self.cache.addCallbackOnCacheChange(&callbackAdd)
        self.cache.addCallbackOnCacheChange(&callbackUpdate)
        self.cache.addCallbackOnCacheChange(&callbackDelete)
    
        let model = TestModel()
        model.id = "jjjj"
        model.name = "hello"
        
        self.cache.addModelToCache(model: model)
        model.name = "what"
        self.cache.addModelToCache(model: model)
        self.cache.removeModelFromCache(ofId: "jjjj")
        self.waitForExpectations(timeout: 4, handler: nil)
    }
    
}
