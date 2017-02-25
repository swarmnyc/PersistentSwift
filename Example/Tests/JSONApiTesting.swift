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

class JSONApiTesting: XCTestCase {
    open class PSLocationAttribute: PSAttribute<CLLocationCoordinate2D> {
        
        open override func serializeToJSON() -> Any? {
            return [self.value.pointee?.longitude, self.value.pointee?.latitude];
        }
        
        open override func deserializeFromJSON(_ json: JSON) {
            if let value = json[self.jsonKey].array {
                self.value.pointee = CLLocationCoordinate2D(latitude: value[0].doubleValue, longitude: value[1].doubleValue);
            }
        }
        
        
    }

    
    public struct ArticleSettings: PSServiceSettings {
        
        static var isTesting: Bool {
            return true;
        }
        
        static var baseUrl: String {
            return "http://google.com/"
        }
        
        static func getTimeout<Model : PSJSONApiModel, TestD : TestData, S : PSServiceSettings>(_ target: PSServiceMap<Model, TestD, S>) -> Double {
            switch target {
            case .createObject( _):
                return 4;
            case .getListPaginated( _):
                return 5;
            default:
                return 12;
            }
        }
        
        static func getAuthToken<Model : PSJSONApiModel, TestD : TestData, S : PSServiceSettings>(_ target: PSServiceMap<Model, TestD, S>) -> String? {
            return nil;
        }
    }
    
    
    final class Author: PSJSONApiModel {
        
        override class var modelName: String {
            return "authors";
        }
        
        
        
        override func register(attributes: inout [PSJSONAPIProperty], andRelationships relationships: inout [PSJSONAPIProperty]) {
            
        }
        
        
    }
    public class Articles: PSJSONApiModel {
        
        override class var modelName: String {
            return "articles";
        }
        
        open var title: String? = "test";
        open var body: String? = "body";
        var author: Author? {
            didSet {
                if let author = self.author {
                    self.authorId = author.id;
                    return;
                }
                self.authorId = nil;
            }
        }
        var authorId: String?
        
        var location: CLLocationCoordinate2D?
        
        override public func register(attributes: inout [PSJSONAPIProperty], andRelationships relationships: inout [PSJSONAPIProperty]) {
            attributes.append(PSAttribute<String>(property: &self.body, jsonKey: "body"));
            attributes.append(PSAttribute<String>(property: &self.title, jsonKey: "title"));
            attributes.append(PSLocationAttribute(property: &self.location, jsonKey: "location"))
            relationships.append(PSToOne<Author>(property: &self.author, idProperty: &self.authorId, jsonKey: "author"));
        }

        
        
        
    }
    
    class ArticlesTestData: TestData {
        public static var getTestData: Data {
            return Data();
        }

        
        public static var getListPaginatedTestData: Data {
            return Data();
        }

        public static var getListWithParamsTestData: Data {
            return Data();
        }

        public static var deleteTestData: Data {
            return Data();
        }

        public static var getListTestData: Data {
            return "{\n  \"data\": [{\n    \"type\": \"articles\",\n    \"id\": \"1\",\n    \"attributes\": {\n      \"title\": \"JSON API paints my bikeshed!\",\n      \"body\": \"The shortest article. Ever.\",\n      \"created\": \"2015-05-22T14:56:29.000Z\",\n      \"updated\": \"2015-05-22T14:56:28.000Z\"\n    },\n    \"relationships\": {\n      \"author\": {\n        \"data\": {\"id\": \"42\", \"type\": \"people\"}\n      }\n    }\n  }],\n  \"included\": [\n    {\n      \"type\": \"people\",\n      \"id\": \"42\",\n      \"attributes\": {\n        \"name\": \"John\",\n        \"age\": 80,\n        \"gender\": \"male\"\n      }\n    }\n  ]\n}".data(using: String.Encoding.utf8)!;
        }
        
        public static var getCreateTestData: Data {
            return "{\n  \"data\": {\n    \"type\": \"articles\",\n    \"attributes\": {\n      \"title\": \"test title\",\n      \"body\": \"test body\"\n    },\n    \"relationships\": {\n      \"author\": {\n        \"data\": { \"type\": \"authors\", \"id\": \"test id\" }\n      }\n    }\n  }\n}".data(using: String.Encoding.utf8)!;
        }
        
    }

    
    
    class ArticlesNetworkManager: PSNetworkManager<Articles, ArticlesTestData, ArticleSettings> {
        static var shared: ArticlesNetworkManager = ArticlesNetworkManager();
        
       
        
    }
    
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        print("do some set up!");
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    
    func testGetRequest() {
       
        let exp = self.expectation(description: "will get a list of articles");
        ArticlesNetworkManager.shared.getListOfObjects().then(execute: {
            articles -> Void in
            XCTAssertEqual(articles.count, 1)
            XCTAssertEqual(articles[0].title, "JSON API paints my bikeshed!");
            XCTAssertEqual(articles[0].body, "The shortest article. Ever.");
            exp.fulfill();
        }).catch {
            error in
            XCTAssert(false);
        }
        
        self.waitForExpectations(timeout: 15, handler: nil);
        
    }
    
    func testCreatingPostParams() {
       
        let article = Articles();
        article.title = "test title";
        article.body = "test body";
        let a = Author();
        a.id = "test id";
        article.author = a;
        let params = article.getCreateParameters(fromModelName: Articles.modelName);
        
        let data = params!["data"]! as! [String: Any];
        let type = data["type"] as! String;
        XCTAssertEqual(type, "articles");
        
        let attributes = data["attributes"] as! [String: Any];
        XCTAssertEqual(attributes["title"] as! String, "test title");
        XCTAssertEqual(attributes["body"] as! String, "test body");
        
        let relationships = data["relationships"] as! [String: Any];
        let author = relationships["author"] as! [String: Any];
        let authorData = author["data"] as! [String: Any];
        XCTAssertEqual(authorData["id"] as! String, "test id");
        XCTAssertEqual(authorData["type"] as! String, "authors");
        
        
        
    }
    
    func testCreatingPostMultiRelationshipParams() {
        class MultiAuthorPost: Articles {
            var authors: [Author]? = [] {
                didSet {
                    if let authors = self.authors {
                        var ids: [String] = [];
                        for author in authors {
                            ids.append(author.id);
                        }
                        self.authorsIds = ids;
                        return;
                    }
                    self.authorsIds = nil;
                }
            };
            var authorsIds: [String]?
            
            
            override public func register(attributes: inout [PSJSONAPIProperty], andRelationships relationships: inout [PSJSONAPIProperty]) {
                super.register(attributes: &attributes, andRelationships: &relationships);
                relationships.append(PSToMany<Author>(property: &self.authors, idProperty: &self.authorsIds, jsonKey: "authors"));

            }

            
        }
        
        let article = MultiAuthorPost();
        article.title = "test title";
        article.body = "test body";
        var a1 = Author()
        a1.id = "1";
        var a2 = Author();
        a2.id = "2";
        article.authors = [a1, a2];
        let params = article.getCreateParameters(fromModelName: Articles.modelName);
        
        let data = params!["data"]! as! [String: Any];
        let type = data["type"] as! String;
        XCTAssertEqual(type, "articles");
        
        let attributes = data["attributes"] as! [String: Any];
        XCTAssertEqual(attributes["title"] as! String, "test title");
        XCTAssertEqual(attributes["body"] as! String, "test body");
        
        let relationships = data["relationships"] as! [String: Any];
        let author = relationships["authors"] as! [String: Any];
        let authorData = author["data"] as! [[String: Any]];
        XCTAssertEqual(authorData[0]["id"] as! String, "1");
        XCTAssertEqual(authorData[1]["id"] as! String, "2");
        XCTAssertEqual(authorData[0]["type"] as! String, "authors");
        
    }
    
    func testCreateRequest() {
        let exp = self.expectation(description: "will create an article");
       
        let article = Articles();
        article.title = "test title";
        article.body = "test body";
        var author = Author();
        author.id = "test id";
        article.author = author;
        
        
        ArticlesNetworkManager.shared.saveNewObject(obj: article).then(execute: {
            article -> Void in
            XCTAssertEqual(article.authorId, "test id");
            XCTAssertEqual(article.title, "test title");
            XCTAssertEqual(article.body, "test body");
            exp.fulfill();
        }).catch {
            error in
            XCTAssert(false, "request failed");

      
        }
        /*
        PSDataManager<Articles, ArticlesTestData>.saveNewObject(obj: article).then {
            article -> Void in
            XCTAssertEqual(article.authorId, "test id");
            XCTAssertEqual(article.title, "test title");
            XCTAssertEqual(article.body, "test body");
            exp.fulfill();

            }.catch {
                error in
                XCTAssert(false, "request failed");
        }
 */
        /*
        ArticleService.shared.makeRequest(.createObject(obj: article)).then {
            article -> Void in
            XCTAssertEqual(article.authorId, "test id");
            XCTAssertEqual(article.title, "test title");
            XCTAssertEqual(article.body, "test body");
            exp.fulfill();
            }.catch {
                error in
                XCTAssert(false, "request failed");
        }
 */
        
        self.waitForExpectations(timeout: 30, handler: nil);
        
    }
    
    func testDeleteData() {
        let exp = self.expectation(description: "will delete an article");
        
        let article = Articles();
        article.title = "test title";
        article.body = "test body";
        let author = Author();
        author.id = "test id";
        
        ArticlesNetworkManager.shared.deleteObject(obj: article).then {
            exp.fulfill();
            }.catch {_ in 
                XCTAssert(false, "this request never finished");
        }
        self.waitForExpectations(timeout: 5, handler: nil);
    }
    
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
