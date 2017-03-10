//
//  JSONApiTesting.swift
//  PersistentSwift
//
//  Created by Alex Hartwell on 2/5/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
import PersistentSwift
import SwiftyJSON
import PromiseKit
import CoreLocation
import Moya

//swiftlint:disable line_length
//swiftlint:disable trailing_whitespace
class JSONApiTestingErrors: XCTestCase {
    
   
    
    final class Author: PSJSONApiModel {
        
        override class var modelName: String {
            return "authors"
        }
        
        override func register(attributes: inout [PSJSONAPIProperty], andRelationships relationships: inout [PSJSONAPIProperty]) {
            
        }
        
    }
    public class Articles: PSJSONApiModel {
        
        override class var modelName: String {
            return "articles"
        }

        open var title: String = "test"
        open var body: String = "body"
        lazy var author: Author? = Author()
        var location: CLLocationCoordinate2D = CLLocationCoordinate2D()
        
        override public func register(attributes: inout [PSJSONAPIProperty], andRelationships relationships: inout [PSJSONAPIProperty]) {
            attributes.append(PSAttribute<String>(property: &self.body, jsonKey: "body"))
            attributes.append(PSAttribute<String>(property: &self.title, jsonKey: "title"))
            attributes.append(PSLocationAttribute(property: &self.location, jsonKey: "location"))
            relationships.append(PSToOne<Author>(property: &self.author, jsonKey: "author"))
        }
    }
    
    class ArticlesTestData: TestData {
        public static var getTestData: Data {
            return Data()
        }
        public static var getListPaginatedTestData: Data {
            return Data()
        }
        public static var getListWithParamsTestData: Data {
            return Data()
        }
        public static var deleteTestData: Data {
            return "{\n  \"test\": [{\n    \"type\": \"articles\",\n    \"id\": \"1\",\n    \"attributes\": {\n      \"title\": \"JSON API paints my bikeshed!\",\n      \"body\": \"The shortest article. Ever.\",\n      \"created\": \"2015-05-22T14:56:29.000Z\",\n      \"updated\": \"2015-05-22T14:56:28.000Z\"\n    },\n    \"relationships\": {\n      \"author\": {\n        \"data\": {\"id\": \"42\", \"type\": \"people\"}\n      }\n    }\n  }],\n  \"included\": [\n    {\n      \"type\": \"people\",\n      \"id\": \"42\",\n      \"attributes\": {\n        \"name\": \"John\",\n        \"age\": 80,\n        \"gender\": \"male\"\n      }\n    }\n  ]\n}".data(using: String.Encoding.utf8)!
        }
        public static var getListTestData: Data {
            // swiftlint:disable:next line_length
            return Data()
        }
        public static var getCreateTestData: Data {
            // swiftlint:disable:next line_length
            return Data()
            // swiftlint:disable:previous line_length
        }
        
    }
    
    class ArticlesNetworkManager: JSONAPIService<Articles> {
        static var shared: ArticlesNetworkManager = ArticlesNetworkManager(settings: ArticlesNetworkManager.getSettings())
        
        static func getSettings() -> JSONAPIServiceSettings {
            var settings = JSONAPIServiceSettings()
            settings.baseUrl = "http://google.com"
            settings.spoofJSON = true
            settings.testingJSON = ArticlesTestData.self
            return settings
        }
    }
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        print("do some set up!")
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
//    func testGetRequestError() {
//        
//        let exp = self.expectation(description: "will get a list of articles")
//        ArticlesNetworkManager.shared.getListOfObjects(query: Query()).then(execute: { _ -> Void in
//            exp.fulfill()
//        }).catch { _ in
//            XCTAssert(true)
//            exp.fulfill()
//        }
//        
//        self.waitForExpectations(timeout: 15, handler: nil)
//    }
    
}
