# PersistentSwift
A model cache and JSON API client for swift
[![Build Status](https://travis-ci.org/swarmnyc/PersistentSwift.svg?branch=master)](https://travis-ci.org/swarmnyc/PersistentSwift) [![codecov](https://codecov.io/gh/swarmnyc/PersistentSwift/branch/master/graph/badge.svg)](https://codecov.io/gh/swarmnyc/PersistentSwift)

## Requirements
-Swift 3
## Installation

PersistentSwift is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "PersistentSwift", :git => 'https://github.com/swarmnyc/PersistentSwift'
```

## Author

ahartwel, hartwellalex@gmail.com

## License

PersistentSwift is available under the MIT license. See the LICENSE file for more info.



##How to use the cache



```swift
	   class Article: PSJSONApiModel {
        
        //the model name, specified by your api
        //it is used for caching and JSON API requests
        override class var modelName: String {
            get {
                return "articles"
            }
        }
        var commentIds: [String]?
        var comments: [Comment]?
        
        var authorId: String?
        var author: Author?
        
        var title: String?
        var body: String?
        
        public override func register(attributes: inout [PSJSONAPIProperty], andRelationships relationships: inout [PSJSONAPIProperty]) {
            attributes.append(PSAttribute(property: &self.title, jsonKey: "title"));
            attributes.append(PSAttribute(property: &self.body, jsonKey: "body"));
            
            relationships.append(PSToMany(property: &self.comments, idProperty: &self.commentIds, jsonKey: "comments"));
            relationships.append(PSToOne(property: &self.author, idProperty: &self.authorId, jsonKey: "author"));
        }
        
        
    }
	class ArticleCache: PSModelCache<Article> {
        static var shared: ArticleCache = ArticleCache();
    }
        
        
    let article = Article();
    article.title = "The Best Article Ever!
    article.body = "A really good read. You are learning a lot and having fun while doing it!"
    article.authorId = "1";
        
    article.commentIds = ["1", "2", "3", "4", "5", "6"];
        
    ArticleCache.shared.addModelToCache(model: article);
        
    ArticleCache.shared.saveCache(); //saves it to UserDefaults
        
    ArticleCache.shared.getModelsFromCache(); //returns an array of all models in the cache;
    ArticleCache.shared.getModelsDictionaryFromCache(); //returns a dictionary where the key is the model id and the values are the models;
    ArticleCache.shared.getModelFromCache(byId: "1"); //return the model of id from cache
    
    
    //after saving the cache on subsequent loads you can call
    ArticleCache.shared.loadCache();
    //and have access to your saved articles in the cache
        
```

###Custom property types.
For any property type that doesn't conform to NSCoding and can't be cached properly by default or needs to be transformed to be sent in a web request you can create a custom PSAttribute to use when registering the property.

Example for CLLocationCoordinate2D:

```swift
open class PSLocationAttribute: PSAttribute<CLLocationCoordinate2D> {
    
    open override func serializeToJSON() -> Any? {
        return [self.value.pointee?.longitude, self.value.pointee?.latitude];
    }
    
    open override func deserializeFromJSON(_ json: JSON) {
        if let value = json[self.jsonKey].array {
            self.value.pointee = CLLocationCoordinate2D(latitude: value[1].doubleValue, longitude: value[0].doubleValue);
        }
    }
    
    open override func decode(_ aDecoder: NSCoder) {
        if let value = aDecoder.decodeObject(forKey: self.jsonKey) as? [Double] {
            self.value.pointee = CLLocationCoordinate2D(latitude: value[1], longitude: value[0]);
        }
    }
    
    
}

```
Example for Date Objects:

```swift

open class PSDateAttribute: PSAttribute<Date> {
    
    override open func serializeToJSON() -> Any? {
        return self.value.pointee?.utcString();
    }
    
    override open func deserializeFromJSON(_ json: JSON) {
        if let dateString = json[self.jsonKey].rawValue as? String {
            self.value.pointee = Date.utcDate(dateString);
        }
    }
    

    override open func decode(_ aDecoder: NSCoder) {
        if let value = aDecoder.decodeObject(forKey: self.jsonKey) as? String {
            self.value.pointee = Date.utcDate(value);
        }
    }
    


}

```


##How to make json api requests

```swift
	public struct ArticlesNetworkSettings: PSServiceSettings {
        //whether or not you want to stub the request and return test data
        static var isTesting: Bool {
            return false; 
        }
 
 			//the base url of the request       
        static var baseUrl: String {
            return "http://google.com/" 
        }
        
        //you can set a different timeout based on which request is being sent
        static func getTimeout<Model : PSJSONApiModel, TestD : TestData, S : PSServiceSettings>(_ target: JsonApiTargetType<Model, TestD, S>) -> Double {
            switch target {
            case .createObject( _):
                return 4;
            case .getListPaginated( _):
                return 5;
            default:
                return 12;
            }
        }
        
        //use the type of request to determine which API token, if any should be sent up
        static func getAuthToken<Model : PSJSONApiModel, TestD : TestData, S : PSServiceSettings>(_ target: JsonApiTargetType<Model, TestD, S>) -> String? {
            return nil;
        }
    }
    
	//Optional: setting up test data, you can just use the helper class NoTestData if you don't want to worry about this
	 class ArticlesTestData: TestData {
	 	//the body of the response for a simple get request
        public static var getTestData: Data {
            return Data();
        }

        //body of the response for a paginated list request
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


	//Create the network manager, used for actually making requests
	class ArticlesNetworkManager: PSNetworkManager<Article, ArticlesTestData, ArticlesNetworkSettings> {
        static var shared: ArticlesNetworkManager = ArticlesNetworkManager();
    }


	ArticlesNetworkManager.shared.getListOfObjects().then {
		articles -> Void in 
		//here you have the response with all the articles returned by your api and you can add the objects to the cache if you want or do whatever you need to do
	}.catch {
		error -> Void in 
		// handle any errors here
	}
	
	//other requests on the network manager
	getListOfObjects()
	getListOfObjects(params: [String: Any]) //with filter
	getPaginatedList(page: Int, limit: Int, params: [String: Any])
	saveNewObject(obj: T)
	updateObject(obj: T)
	deleteObject(obj: T)
	getObject(obj: T)
	getPaginatedList(page: Int, limit: Int, params: [String: Any])
	
```
