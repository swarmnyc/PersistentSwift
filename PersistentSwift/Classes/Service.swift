//
//  Service.swift
//  Pods
//
//  Created by Alex Hartwell on 2/9/17.
//
//

import Foundation
import Moya
import PromiseKit
import Alamofire


public struct TimeoutPlugin<T:JsonApiModel, D:TestData, S:PSServiceSettings>: PluginType {

	var timeoutGetter: ((JsonApiTargetType<T, D, S>) -> Double)?

	init(timeoutGetter: ((JsonApiTargetType<T, D, S>) -> Double)?) {
		self.timeoutGetter = timeoutGetter
	}

	/// Called to modify a request before sending
	public func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
		var req = request;
		if let timeout = self.timeoutGetter?(target as! JsonApiTargetType<T, D, S>) {
			req.timeoutInterval = timeout;
		}
		return req;
	}


}


public protocol PSServiceSettings {

	static var baseUrl: String { get }
	static var isTesting: Bool { get }
	static var verboseLogging: Bool { get }
	static func getTimeout<Model:JsonApiModel, TestD:TestData, S:PSServiceSettings>(
		_ target: JsonApiTargetType<Model, TestD, S>) -> Double

	static func getAuthToken<Model:JsonApiModel, TestD:TestData, S:PSServiceSettings>(
		_ target: JsonApiTargetType<Model, TestD, S>) -> String?

}


struct TestSettings: PSServiceSettings {
	static var baseUrl: String {
		return "";
	}

	static var isTesting: Bool {
		return false;
	}

	static var verboseLogging: Bool {
		return false
	}

	static func getTimeout<Model:JsonApiModel, TestD:TestData, S:PSServiceSettings>(
		_ target: JsonApiTargetType<Model, TestD, S>) -> Double {
		return 12;
	}

	static func getAuthToken<Model:JsonApiModel, TestD:TestData, S:PSServiceSettings>(
		_ target: JsonApiTargetType<Model, TestD, S>) -> String? {
		return nil;
	}

}

public class PSServiceModelStore {
	internal var objStore: [String: [String: JsonApiModel]] = [:]

	func addObj<T:JsonApiModel>(_ obj: T) {
		if self.objStore[T.modelName] == nil {
			self.objStore[T.modelName] = [:]
		}
		self.objStore[T.modelName]?[obj.id] = obj
	}

	func getObj<T:JsonApiModel>(byId id: String) -> T? {
		return self.objStore[T.modelName]?[id] as? T
	}

}



//A Generic class for making network requests (to be subclassed for each section of the API eg. AvatarService, EventService, UserService etc

public class JsonApiService<T:JsonApiModel, D:TestData, S:PSServiceSettings> {

	public typealias JsonApiTarget = JsonApiTargetType<T, D, S>;


	//the actual object used to make the requests
	lazy var provider: MoyaProvider<JsonApiTargetType<T, D, S>> = self.getProvider();

	/// get a MoyaProvider to make API calls
	func getProvider() -> MoyaProvider<JsonApiTargetType<T, D, S>> {
		let provider = MoyaProvider<JsonApiTargetType<T, D, S>>(stubClosure: {
			_ in
			if S.isTesting {
				return .immediate;
			}
			else {
				return .never
			}
		}, plugins: [
			AuthPlugin<T, D, S>(tokenClosure: S.getAuthToken),
			TimeoutPlugin<T, D, S>(timeoutGetter: S.getTimeout),
			NetworkLoggerPlugin(verbose: S.verboseLogging)
		]
		)
		return provider;
	}


	/// Get all objects from the server (a plain old get request with no params)
	///
	/// - Returns: A promise with an array of objects
	open func getListOfObjects() -> Promise<[T]> {
		return makeRequestArray(JsonApiTarget.getList());
	}





	//a wrapper for a request which returns a single object, type is the type of request, defined in the API map
	public func makeRequest(_ type: JsonApiTargetType<T, D, S>) -> Promise<T> {
		Background.runInMainThread {
			UIApplication.shared.isNetworkActivityIndicatorVisible = true;
		}
		let promise = Promise<T>.pending();
		self.provider.request(type, completion: {
			result in
			switch result {
				case let .success(moyaResponse):
					Background.runInBackground {

						do {
							try moyaResponse.filterSuccessfulStatusAndRedirectCodes();
							let object = try moyaResponse.map(to: T.self);
							Background.runInMainThread {
								UIApplication.shared.isNetworkActivityIndicatorVisible = false;
								promise.fulfill(object);
							}
						}
						catch {
							print(error);
							print(type);
							Background.runInMainThread {
								UIApplication.shared.isNetworkActivityIndicatorVisible = false;
								promise.reject(error);
							}
						}
					}
					break;
				case let .failure(error):
					Background.runInMainThread {
						UIApplication.shared.isNetworkActivityIndicatorVisible = false;
						promise.reject(error);
					}
					break;
			}
		});
		return promise.promise;
	}

	public func makeRequestNoObjectReturn(_ type: JsonApiTargetType<T, D, S>) -> Promise<Void> {
		Background.runInMainThread {
			UIApplication.shared.isNetworkActivityIndicatorVisible = true;
		}
		let promise = Promise<Void>.pending();
		Background.runInBackground {
			self.provider.request(type, completion: {
				result in

				switch result {
					case let .success(moyaResponse):
						do {
							try moyaResponse.filterSuccessfulStatusAndRedirectCodes();
							Background.runInMainThread {
								UIApplication.shared.isNetworkActivityIndicatorVisible = false;
								promise.fulfill();
							}

						}
						catch {
							print(error);
							Background.runInMainThread {
								UIApplication.shared.isNetworkActivityIndicatorVisible = false;
								promise.reject(error);
							}
						}
						break;
					case let .failure(error):
						Background.runInMainThread {
							UIApplication.shared.isNetworkActivityIndicatorVisible = false;
							promise.reject(error);
						}
						break;
				}
			});
		}

		return promise.promise;
	}


	//a wrapper for a request which returns an array of objects
	public func makeRequestArray(_ type: JsonApiTargetType<T, D, S>) -> Promise<[T]> {

		UIApplication.shared.isNetworkActivityIndicatorVisible = true;
		let promise = Promise<[T]>.pending();

		self.provider.request(type, completion: {
			result in

			UIApplication.shared.isNetworkActivityIndicatorVisible = false;

			switch result {
				case let .success(moyaResponse):
					do {
						// check for Http errors
						try moyaResponse.filterSuccessfulStatusAndRedirectCodes();

						let objects = try moyaResponse.map(to: [T.self]) as! [T];

						promise.fulfill(objects);
					}
					catch {
						print(error);
						promise.reject(error);
					}
					break;
				case let .failure(error):
					promise.reject(error);
					break;
			}
		});

		return promise.promise;
	}


}

public class JsonApiQuery {
	var  filter : String?
	var  sort : String?
	var  include : String?

	var page : Int?
	var perPage : Int?


	/*
	let p = : [String: Any]?
	p["page"] = page;
				p["per_page"] = limit;

	*/
}


public enum JsonApiTargetType<T:JsonApiModel, D:TestData, S:PSServiceSettings> {

	case getList()
	case createObject(obj: T)
	case updateObject(obj: T)
	case deleteObject(obj: T)
	case getObject(obj: T)
}



extension JsonApiTargetType: TargetType {

	typealias Model = T;
	typealias TestData = D;


	/// The target's base `URL`. TODO consder how to move base URL elsewehre
	public var baseURL: URL {
		return URL(string: S.baseUrl)!;
	}

	/// The path to be appended to `baseURL` to form the full `URL`.
	public var path: String {
		switch self {
			case .getList:
				return "/\(T.modelName)";
			case .createObject(let obj):
				return "/\(T.modelName)";
			case .updateObject(let obj):
				return "/\(T.modelName)/\(obj.id)";
			case .deleteObject(let obj):
				return "/\(T.modelName)/\(obj.id)";
			case .getObject(let obj):
				return "/\(T.modelName)/\(obj.id)";
		}
	}

	/// The HTTP method used in the request.
	public var method: Moya.Method {
		switch self {
			case .getList:
				return .get;
			case .createObject(_):
				return .post;
			case .updateObject(obj: _):
				return .patch;
			case .deleteObject(_):
				return .delete
			case .getObject(_):
				return .get
		}
	}

	/// The parameters to be incoded in the request.
	public var parameters: [String: Any]? {
		switch self {
			case .getList:
				return nil;
			case .createObject(let obj):
				return obj.getCreateParameters(fromModelName: T.modelName);
			case .updateObject(let obj):
				return obj.getCreateParameters(fromModelName: T.modelName);
			case .deleteObject(_):
				return nil;
			case .getObject(let obj):
				return obj.getCreateParameters(fromModelName: T.modelName);
		}
	}

	/// The method used for parameter encoding.
	public var parameterEncoding: ParameterEncoding {
		switch self {
			case .getList:
				return URLEncoding.default;
			case .createObject(_):
				return JSONEncoding.default;
			case .updateObject(_):
				return JSONEncoding.default;
			case .deleteObject(_):
				return URLEncoding.default;
			case .getObject(_):
				return JSONEncoding.default;
		}
	}

	/// Provides stub data for use in testing.
	public var sampleData: Data {
		switch self {
			case .getList:
				return D.getListTestData;
			case .createObject(_):
				return D.getCreateTestData;
			case .updateObject(_):
				return D.getCreateTestData;
			case .deleteObject(_):
				return D.deleteTestData;
			case .getObject(_):
				return D.getTestData;
		}
	}

	/// The type of HTTP task to be performed.
	public var task: Task {
		return Task.request
	}


}

