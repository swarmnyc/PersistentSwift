# PersistentSwift
A model cache for swift
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



##How to use

- Every model that subclasses PSCachedModel will automatically be NSCoding compliant and archive and unarchive without any extra effort. (besides overriding modelName)
- Register models you want to cache with the Model Cache
- You need to manually add models to the cache with addToCache();


```swift
	   class ModelToCache: PSCachedModel {
            
            override class var modelName: String {
                get {
                    return "Test Model"
                }
            }
            
            var name: String = "Hello";
            var isLive: Bool = true;
            var number: Double = 1000;
            
        }
        
        PSModelCache.shared.registerModels(models: [ModelToCache.self]);
        
        
        let newModel = TestModel();
        newModel.name = "tester test"
        newModel.addToCache();
        
        PSModelCache.saveCache();
        PSModelCache.loadCache();
        
        
        let models: [ModelToCache] = ModelToCache.models; //gets all of the cached models
        print(models);
        /// prints an array of models
        ///  [ ModelToCache {
        ///	 name = "tester test"
        ///  isLive = true
        ///  number = 1000;
        ///  }]
        
        
```
