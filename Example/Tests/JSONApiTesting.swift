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
import Fakery
// swiftlint:disable line_length
// swiftlint:disable type_body_length
// swiftlint:disable trailing_whitespace
class JSONApiTesting: XCTestCase {
   
    
    
    final class Author: PSJSONApiModel {

        open var name: String = ""
        open var age: Int = 0
        open var gender: String = ""
        open var articles: [Articles] = []
        
        override class var modelName: String {
            return "authors"
        }
       
        override func register(attributes: inout [PSJSONAPIProperty], andRelationships relationships: inout [PSJSONAPIProperty]) {
            attributes.append(PSAttribute(property: &self.name, jsonKey: "name"))
            attributes.append(PSAttribute(property: &self.age, jsonKey: "age"))
            attributes.append(PSAttribute(property: &self.gender, jsonKey: "gender"))
            relationships.append(PSToMany(property: &self.articles, jsonKey: "articles"))
        }

    }
    
    enum TestingEnum {
        case test
    }
    
    public class Articles: PSJSONApiModel {
        //json keys
        static var titleKey: String = "title"
        static var bodyKey: String = "body"
        static var locationKey: String = "location"
        static var authorKey: String = "author"
        
        override class var modelName: String {
            return "articles"
        }
      
        open var title: String = "test"
        open var body: String = "body"
        var author: Author?
        
        
        var location: CLLocationCoordinate2D = CLLocationCoordinate2D()

        override public func register(attributes: inout [PSJSONAPIProperty], andRelationships relationships: inout [PSJSONAPIProperty]) {
            attributes.append(PSAttribute<String>(property: &self.body, jsonKey: Articles.bodyKey))
            attributes.append(PSAttribute<String>(property: &self.title, jsonKey: Articles.titleKey))
            attributes.append(PSLocationAttribute(property: &self.location, jsonKey: Articles.locationKey))
            relationships.append(PSToOne<Author>(property: &self.author, jsonKey: Articles.authorKey))
        }
    }
    class MultiAuthorPost: Articles {
        var authors: [Author] = []
        // swiftlint:disable:next line_length
        override public func register(attributes: inout [PSJSONAPIProperty],
                                      andRelationships relationships: inout [PSJSONAPIProperty]) {
            super.register(attributes: &attributes, andRelationships: &relationships)
            let authorRelationship = PSToMany<Author>(property: &self.authors,
                                                      jsonKey: "authors")
            relationships.append(authorRelationship)
        }
    }

    class ArticlesNetworkManager: JSONAPIService<Articles> {
        // swiftlint:disable:next line_length
        static var shared: ArticlesNetworkManager = ArticlesNetworkManager(settings: ArticlesNetworkManager.getSettings())
        
        static func getSettings() -> JSONAPIServiceSettings {
            var settings = JSONAPIServiceSettings()
            settings.baseUrl = "http://google.com"
            settings.spoofReturn = .json
            settings.testingJSON = ArticlesTestData.self
            return settings
        }
    }

    class MultiAuthorArticleNetworkManager: JSONAPIService<MultiAuthorPost> {
        // swiftlint:disable:next line_length
        static var shared: MultiAuthorArticleNetworkManager = MultiAuthorArticleNetworkManager(settings: MultiAuthorArticleNetworkManager.getSettings())
        
        static func getSettings() -> JSONAPIServiceSettings {
            var settings = JSONAPIServiceSettings()
            settings.baseUrl = "http://google.com"
            settings.spoofReturn = .json
            settings.testingJSON = ArticlesTestData.self
            settings.moyaProviderPlugins = []
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
    
    func testSpoofingReturnWithCreatedObject() {
        let exp = self.expectation(description: "Will spoof response with object of your choosing")
        
        //set up the settings and tell it to spoof the return with objects
        var settings: JSONAPIServiceSettings = JSONAPIServiceSettings()
        settings.spoofReturn = .objects
        settings.baseUrl = "test"
        let service = JSONAPIService<Articles>(settings: settings)
        
        //create the object
        let article = self.getTestArticle()
        //set the spoof object on the service
        service.getObjectSpoof = article
        
        let request = JSONAPIRequest<Articles>.getObject(id: "test")
        
        _ = service.makeRequest(request: request).then { art -> Void in
            XCTAssertEqual(art, article)
            exp.fulfill()
        }
        
        self.waitForExpectations(timeout: 0.5, handler: nil)
    }
    
    func testSpoofingReturnWithCreatedArrayOfObjects() {
        let exp = self.expectation(description: "Will spoof response with object of your choosing")
        
        var settings: JSONAPIServiceSettings = JSONAPIServiceSettings()
        settings.spoofReturn = .objects
        settings.baseUrl = "test"
        let service = JSONAPIService<Articles>(settings: settings)
        
        let articles = self.getMultipleTestArticles(10)
        
        let request = JSONAPIRequest<Articles>.getObjects()
        
        service.getRequestSpoof = articles
        
        _ = service.makeRequest(request: request).then { art -> Void in
            XCTAssertEqual(art, articles)
            exp.fulfill()
        }
        
        self.waitForExpectations(timeout: 0.5, handler: nil)
    }
    
    func testWhereAttributeEquals() {
        let query = JSONAPIRequest<Articles>.getObjects()
            .whereAttribute(jsonKey: Articles.titleKey,
                            equals: "testing test test")
        let params = query.createParameters()
        XCTAssertEqual(params[Articles.titleKey] as? String, "testing test test")
    }
    
    func testWhereAttributeEqualsWithCustomPSAttributeClass() {
        let query = JSONAPIRequest<Articles>.getObjects()
            .whereAttribute(jsonKey: Articles.locationKey,
                            equals: CLLocationCoordinate2D(latitude: 100, longitude: 100))
        let params = query.createParameters()
        // swiftlint:disable:next force_cast
        XCTAssertEqual(params[Articles.locationKey] as! [Double], [100, 100])
    }
    
    func testWhereRelationshipsEqualsWithId() {
        let query = JSONAPIRequest<Articles>.getObjects()
        .whereRelationship(jsonKey: Articles.authorKey, idEquals: "test_id")
        
        let params = query.createParameters()
        XCTAssertEqual(params[Articles.authorKey] as? String, "test_id")
    }

    func testGetRequest() {
        
        print(#keyPath(Articles.author))
        
        let exp = self.expectation(description: "will get a list of articles")
        let request = JSONAPIRequest<Articles>.getObjects()
            .sortBy(jsonKey: Articles.titleKey, ascending: true)
        
        ArticlesNetworkManager.shared.makeRequest(request: request).then(execute: { articles -> Void in
            XCTAssertEqual(articles.count, 1)
            XCTAssertEqual(articles[0].title, "JSON API paints my bikeshed!")
            XCTAssertEqual(articles[0].body, "The shortest article. Ever.")
            exp.fulfill()
        }).catch { _ in
            XCTAssert(false)
        }

        self.waitForExpectations(timeout: 15, handler: nil)
    }
//    func testGetListWithParams() {
//        let exp = self.expectation(description: "will get a list of articles")
//        ArticlesNetworkManager.shared.getListOfObjects(params: ["test": "test"]).then(execute: { articles -> Void in
//            XCTAssertEqual(articles.count, 1)
//            XCTAssertEqual(articles[0].title, "JSON API paints my bikeshed!")
//            XCTAssertEqual(articles[0].body, "The shortest article. Ever.")
//            exp.fulfill()
//        }).catch { _ in
//            XCTAssert(false)
//        }
//        self.waitForExpectations(timeout: 15, handler: nil)
//    }
    // swiftlint:disable trailing_whitespace
    
    func testGetSingleRequest() {
        let exp = self.expectation(description: "will get single object")
        let article = Articles()
        article.id = "test"
        let request = JSONAPIRequest<Articles>.getObject(id: "test")
                                              .addIncludeType(Author.self)
        _ = ArticlesNetworkManager.shared.makeRequest(request: request).then { art -> Void in
            XCTAssertEqual(art.title, "JSON API paints my bikeshed!")
            XCTAssertEqual(art.body, "The shortest article. Ever.")
            XCTAssertEqual(art.author?.id, "42")
            exp.fulfill()
        }
       
        self.waitForExpectations(timeout: 1.5, handler: nil)
    }
    func testGetSingleRequestWithToManyRelation() {
        let exp = self.expectation(description: "will get single object")
        let article = MultiAuthorPost()
        article.id = "test"
        let request = JSONAPIRequest<MultiAuthorPost>.getObject(id: "test")
        _ = MultiAuthorArticleNetworkManager.shared.makeRequest(request: request).then { art -> Void in
            XCTAssertEqual(art.title, "JSON API paints my bikeshed!")
            XCTAssertEqual(art.body, "The shortest article. Ever.")
            XCTAssertEqual(art.author?.id, "42")
            XCTAssertEqual(art.authors.count, 3)
            exp.fulfill()
        }
        self.waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testGetSingleRequestIncludeToOneRelationship() {
        let exp = self.expectation(description: "will get single object and relationship")
        let article = MultiAuthorPost()
        article.id = "test"
        let request = JSONAPIRequest<MultiAuthorPost>.getObject(id: "test")
        _ = MultiAuthorArticleNetworkManager.shared.makeRequest(request: request).then { art -> Void in
            XCTAssertEqual(art.author?.name, "John")
            XCTAssertEqual(art.author?.age, 80)
            XCTAssertEqual(art.author?.gender, "male")
            XCTAssertEqual(art.author?.isBlank, false)
            exp.fulfill()

        }
        self.waitForExpectations(timeout: 2, handler: nil)
    }

    func testGetSingleRequestIncludeToMany() {
        let exp = self.expectation(description: "will get single object")
        let article = MultiAuthorPost()
        article.id = "test"
        let request = JSONAPIRequest<MultiAuthorPost>.getObject(id: "test")
        _ = MultiAuthorArticleNetworkManager.shared.makeRequest(request: request).then { art -> Void in
            XCTAssertEqual(art.authors.count, 3)
            XCTAssertEqual(art.authors[0].name, "John")
            XCTAssertEqual(art.authors[0].isBlank, false)
            XCTAssertEqual(art.authors[1].name, "Joe")
            XCTAssertEqual(art.authors[2].name, "Jack")
            exp.fulfill()
        }
        self.waitForExpectations(timeout: 1000, handler: nil)
    }
    
    func testEqualsFilter() {
        

    }
    
//    func testGetPaginatedListWithParams() {
//        let exp = self.expectation(description: "will get a list of articles")
//        let params: [String: Any] = ["test": "test"]
//        ArticlesNetworkManager.shared.getPaginatedList(page: 2,
//                                                       limit: 10,
//                                                       params: params).then(execute: { articles -> Void in
//            XCTAssertEqual(articles.count, 1)
//            XCTAssertEqual(articles[0].title, "JSON API paints my bikeshed!")
//            XCTAssertEqual(articles[0].body, "The shortest article. Ever.")
//            exp.fulfill()
//        }).catch { _ in
//            XCTAssert(false)
//        }
//        self.waitForExpectations(timeout: 15, handler: nil)
//    }
//    
//    func testPaginatedParams() {
//        typealias APIMap = JSONAPITargetType<Articles, ArticlesTestData, ArticleSettings>
//        let paginatedParams = APIMap.getListPaginated(page: 2, limit: 10, params: ["test": "test"])
//        // swiftlint:disable:next force_cast
//        XCTAssertEqual((paginatedParams.parameters!["page"] as! Int), 2)
//        // swiftlint:disable:next force_cast
//        XCTAssertEqual((paginatedParams.parameters!["per_page"] as! Int), 10)
//        // swiftlint:disable:next force_cast
//        XCTAssertEqual((paginatedParams.parameters!["test"] as! String), "test")
//
//    }

    func testCreatingPostParams() {

        let article = Articles()
        article.title = "test title"
        article.body = "test body"
        let a = Author()
        a.id = "test id"
        article.author = a
        let params = article.getCreateParameters(fromModelName: Articles.modelName)
        //swiftlint:disable force_cast
        let data = params!["data"] as! [String: Any]
        let type = data["type"] as! String
        XCTAssertEqual(type, "articles")

        let attributes = data["attributes"] as! [String: Any]
        XCTAssertEqual(attributes["title"] as! String, "test title")
        XCTAssertEqual(attributes["body"] as! String, "test body")

        let relationships = data["relationships"] as! [String: Any]
        let author = relationships["author"] as! [String: Any]
        let authorData = author["data"] as! [String: Any]
        XCTAssertEqual(authorData["id"] as! String, "test id")
        XCTAssertEqual(authorData["type"] as! String, "authors")

    }

    func testCreatingPostMultiRelationshipParams() {
       
        let article = MultiAuthorPost()
        article.title = "test title"
        article.body = "test body"
        let a1 = Author()
        a1.id = "1"
        let a2 = Author()
        a2.id = "2"
        article.authors = [a1, a2]
        let params = article.getCreateParameters(fromModelName: Articles.modelName)

        let data = params!["data"]! as! [String: Any]
        let type = data["type"] as! String
        XCTAssertEqual(type, "articles")

        let attributes = data["attributes"] as! [String: Any]
        XCTAssertEqual(attributes["title"] as! String, "test title")
        XCTAssertEqual(attributes["body"] as! String, "test body")

        let relationships = data["relationships"] as! [String: Any]
        let author = relationships["authors"] as! [String: Any]
        let authorData = author["data"] as! [[String: Any]]
        XCTAssertEqual(authorData[0]["id"] as! String, "1")
        XCTAssertEqual(authorData[1]["id"] as! String, "2")
        XCTAssertEqual(authorData[0]["type"] as! String, "authors")

    }

//     func testUpdatingAnObject() {
//        let exp = self.expectation(description: "will update an article")
//        let article = Articles()
//        article.title = "test title"
//        article.body = "test body"
//        let author = Author()
//        author.id = "test id"
//        article.author = author
//        ArticlesNetworkManager.shared.updateObject(obj: article).then(execute: { article -> Void in
//            XCTAssertEqual(article.author?.id, "test id")
//            XCTAssertEqual(article.title, "test title")
//            XCTAssertEqual(article.body, "test body")
//            exp.fulfill()
//        }).catch { _ in
//            XCTAssert(false, "request failed")
//        }
//        self.waitForExpectations(timeout: 30, handler: nil)
//    }
//    func testCreateRequest() {
//        let exp = self.expectation(description: "will create an article")
//
//        let article = Articles()
//        article.title = "test title"
//        article.body = "test body"
//        let author = Author()
//        author.id = "test id"
//        article.author = author
//
//        ArticlesNetworkManager.shared.saveNewObject(obj: article).then(execute: { article -> Void in
//            XCTAssertEqual(article.author?.id, "test id")
//            XCTAssertEqual(article.title, "test title")
//            XCTAssertEqual(article.body, "test body")
//            exp.fulfill()
//        }).catch { _ in
//            XCTAssert(false, "request failed")
//        }
//
//        self.waitForExpectations(timeout: 30, handler: nil)
//
//    }
//
//    func testDeleteData() {
//        let exp = self.expectation(description: "will delete an article")
//
//        let article = Articles()
//        article.title = "test title"
//        article.body = "test body"
//        let author = Author()
//        author.id = "test id"
//
//        ArticlesNetworkManager.shared.deleteObject(obj: article).then {
//            exp.fulfill()
//            }.catch {_ in
//                XCTAssert(false, "this request never finished")
//        }
//        self.waitForExpectations(timeout: 5, handler: nil)
//    }

    func testNoData() {
        XCTAssertEqual(NoTestData.deleteTestData, Data())
        XCTAssertEqual(NoTestData.getCreateTestData, Data())
        XCTAssertEqual(NoTestData.getListPaginatedTestData, Data())
        XCTAssertEqual(NoTestData.getListTestData, Data())
        XCTAssertEqual(NoTestData.getListWithParamsTestData, Data())
        XCTAssertEqual(NoTestData.getTestData, Data())
    }

    
    
    // swiftlint:disable line_length
    class ArticlesTestData: TestData {
        public static var getTestData: Data {
            return "{\n  \"data\": {\n    \"type\": \"articles\",\n    \"id\": \"1\",\n    \"attributes\": {\n      \"title\": \"JSON API paints my bikeshed!\",\n      \"body\": \"The shortest article. Ever.\",\n      \"created\": \"2015-05-22T14:56:29.000Z\",\n      \"updated\": \"2015-05-22T14:56:28.000Z\"\n    },\n    \"relationships\": {\n      \"author\": {\n        \"data\": {\"id\": \"42\", \"type\": \"people\"}\n      },\n \"authors\": {\n        \"data\": [{\"id\": \"42\", \"type\": \"people\"}, {\"id\": \"43\", \"type\": \"people\"}, {\"id\": \"44\", \"type\": \"people\"}]\n      }\n     }\n  },\n  \"included\": [\n    {\n      \"type\": \"authors\",\n      \"id\": \"42\",\n      \"attributes\": {\n        \"name\": \"John\",\n        \"age\": 80,\n        \"gender\": \"male\"\n      }\n    }\n, {\n      \"type\": \"authors\",\n      \"id\": \"43\",\n      \"attributes\": {\n        \"name\": \"Joe\",\n        \"age\": 80,\n        \"gender\": \"male\"\n      }\n    }\n, {\n      \"type\": \"authors\",\n      \"id\": \"44\",\n      \"attributes\": {\n        \"name\": \"Jack\",\n        \"age\": 80,\n        \"gender\": \"male\"\n      }\n    }\n,  ]\n}".data(using: String.Encoding.utf8)!
        }
        
        public static var getListPaginatedTestData: Data {
            return "{\n  \"data\": [{\n    \"type\": \"articles\",\n    \"id\": \"1\",\n    \"attributes\": {\n      \"title\": \"JSON API paints my bikeshed!\",\n      \"body\": \"The shortest article. Ever.\",\n      \"created\": \"2015-05-22T14:56:29.000Z\",\n      \"updated\": \"2015-05-22T14:56:28.000Z\"\n    },\n    \"relationships\": {\n      \"author\": {\n        \"data\": {\"id\": \"42\", \"type\": \"people\"}\n      }\n    }\n  }],\n  \"included\": [\n    {\n      \"type\": \"people\",\n      \"id\": \"42\",\n      \"attributes\": {\n        \"name\": \"John\",\n        \"age\": 80,\n        \"gender\": \"male\"\n      }\n    }\n  ]\n}".data(using: String.Encoding.utf8)!
        }
        
        public static var getListWithParamsTestData: Data {
            return "{\n  \"data\": [{\n    \"type\": \"articles\",\n    \"id\": \"1\",\n    \"attributes\": {\n      \"title\": \"JSON API paints my bikeshed!\",\n      \"body\": \"The shortest article. Ever.\",\n      \"created\": \"2015-05-22T14:56:29.000Z\",\n      \"updated\": \"2015-05-22T14:56:28.000Z\"\n    },\n    \"relationships\": {\n      \"author\": {\n        \"data\": {\"id\": \"42\", \"type\": \"people\"}\n      }\n    }\n  }],\n  \"included\": [\n    {\n      \"type\": \"people\",\n      \"id\": \"42\",\n      \"attributes\": {\n        \"name\": \"John\",\n        \"age\": 80,\n        \"gender\": \"male\"\n      }\n    }\n  ]\n}".data(using: String.Encoding.utf8)!
        }
        
        public static var deleteTestData: Data {
            return Data()
        }
        public static var getListTestData: Data {
            // swiftlint:disable:next line_length
            return "{\n  \"data\": [{\n    \"type\": \"articles\",\n    \"id\": \"1\",\n    \"attributes\": {\n      \"title\": \"JSON API paints my bikeshed!\",\n      \"body\": \"The shortest article. Ever.\",\n      \"created\": \"2015-05-22T14:56:29.000Z\",\n      \"updated\": \"2015-05-22T14:56:28.000Z\"\n    },\n    \"relationships\": {\n      \"author\": {\n        \"data\": {\"id\": \"42\", \"type\": \"people\"}\n      }\n    }\n  }],\n  \"included\": [\n    {\n      \"type\": \"people\",\n      \"id\": \"42\",\n      \"attributes\": {\n        \"name\": \"John\",\n        \"age\": 80,\n        \"gender\": \"male\"\n      }\n    }\n  ]\n}".data(using: String.Encoding.utf8)!
        }
        
        public static var getCreateTestData: Data {
            // swiftlint:disable:next line_length
            return "{\n  \"data\": {\n    \"type\": \"articles\",\n    \"attributes\": {\n      \"title\": \"test title\",\n      \"body\": \"test body\"\n    },\n    \"relationships\": {\n      \"author\": {\n        \"data\": { \"type\": \"authors\", \"id\": \"test id\" }\n      }\n    }\n  }\n}".data(using: String.Encoding.utf8)!
            // swiftlint:disable:previous line_length
        }
        
    }
    
    func getTestArticle() -> Articles {
        let faker = Faker()
        let article = Articles()
        article.title = faker.name.firstName() + faker.name.lastName()
        article.body = faker.lorem.paragraph()
        return article
    }
    
    func getMultipleTestArticles(_ numberOfArticles: Int) -> [Articles] {
        var articles: [Articles] = []
        for _ in 0..<numberOfArticles {
            articles.append(self.getTestArticle())
        }
        return articles
    }
    
}
