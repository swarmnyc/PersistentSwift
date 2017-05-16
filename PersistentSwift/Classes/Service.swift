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

public enum SpoofReturn {
	case none
	case json
	case objects
}
public struct JSONAPIServiceSettings {
	public var baseUrl: String = ""
	public var spoofReturn: SpoofReturn = .none
	public var testingJSON: TestData.Type = NoTestData.self
	public var timeoutClosure: ((JSONAPITargetMethod) -> Double)?
	public var headersClosure: ((JSONAPITargetMethod) -> [String: String])?
	public var moyaProviderPlugins: [PluginType] = []
	
	// MARK: Initialization
	
	public init() {}
}

//Generic Network Manager
open class JSONAPIService<T: PSJSONApiModel>: PluginType {
	
	var settings: JSONAPIServiceSettings
	
	//the actual object used to make the requests
	lazy var provider: MoyaProvider<JSONAPIRequest<T>> = self.getProvider();
	
	/// get a MoyaProvider to make API calls
	public func getProvider<T: TargetType>() -> MoyaProvider<T> {
		let provider = MoyaProvider<T>(stubClosure: { _ in
			if self.settings.spoofReturn == .json {
				return .immediate;
			} else {
				return .never
			}
		}, plugins: [self] + self.settings.moyaProviderPlugins)
		return provider;
	}
	
	
	open var getObjectSpoof: T = T()
	open var createObjectSpoof: T = T()
	open var updateObjectSpoof: T = T()
	open var getRequestSpoof: [T] = []
	
	
	public init(settings: JSONAPIServiceSettings) {
		self.settings = settings
	}
	
	
	open func makeRequest(request: JSONAPIRequestSingle<T>) -> Promise<T> {
		let request = request.addSettings(self.settings)
		if self.settings.spoofReturn == .objects {
			return self.makeSingleRequestSpoof(target: request.type)
		}
		return self.makeRequest(request)
	}
	
	open func makeRequest(request: JSONAPIRequestEmptyResponse<T>) -> Promise<Void> {
		let request = request.addSettings(self.settings)
		if self.settings.spoofReturn == .objects {
			return Promise<Void>(value: ())
		}
		return self.makeRequestNoObjectReturn(request)
	}
	
	open func makeRequest(request: JSONAPIRequest<T>) -> Promise<[T]> {
		let request = request.addSettings(self.settings)
		if self.settings.spoofReturn == .objects {
			return self.makeArrayRequestSpoof(tagert: request.type)
		}
		return self.makeRequestArray(request)
	}
	
	
	internal func makeSingleRequestSpoof(target: JSONAPITargetMethod) -> Promise<T> {
		switch target {
		case .getObject:
			return Promise<T>(value: self.getObjectSpoof)
		case .createObject:
			return Promise<T>(value: self.createObjectSpoof)
		case .updateObject:
			return Promise<T>(value: self.updateObjectSpoof)
		default:
			return Promise<T>(value: self.getObjectSpoof)
		}
	}
	
	internal func makeArrayRequestSpoof(tagert: JSONAPITargetMethod) -> Promise<[T]> {
		return Promise<[T]>(value: self.getRequestSpoof)
	}
	
	open func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
		guard let target = target as? JSONAPIRequest<T> else {
			return request
		}
		var request = request
		
		self.addTimeoutToRequest(&request, target: target)
		self.addHeadersToRequest(&request, target: target)
		
		return request
	}
	
	internal func addTimeoutToRequest(_ request: inout URLRequest, target: JSONAPIRequest<T>) {
		if let timeout = self.settings.timeoutClosure?(target.type) {
			request.timeoutInterval = timeout
		} else {
			request.timeoutInterval = 20
		}
	}
	
	internal func addHeadersToRequest(_ request: inout URLRequest, target: JSONAPIRequest<T>) {
		if let headers = self.settings.headersClosure?(target.type) {
			for header in headers {
				request.addValue(header.value, forHTTPHeaderField: header.key)
			}
		}
	}
	
	/// Called immediately before a request is sent over the network (or stubbed).
	open func willSend(_ request: RequestType, target: TargetType) {
		
	}
	
	/// Called after a response has been received, but before the MoyaProvider has invoked its completion handler.
	open func didReceive(_ result: Result<Moya.Response>, target: TargetType) {
		
	}
	
	/// Called to modify a result before completion
	open func process(_ result: Result<Moya.Response>, target: TargetType) -> Result<Moya.Response> {
		return result
	}
	
	
	//a wrapper for a request which returns a single object, type is the type of request, defined in the API map
	internal func makeRequest(_ type: JSONAPIRequest<T>) -> Promise<T> {
		DispatchQueue.main.async {
			UIApplication.shared.isNetworkActivityIndicatorVisible = true
		}
		let pending = Promise<T>.pending()
		self.provider.request(type) { result in
			DispatchQueue.global(qos: .utility).async {
				switch result {
				case let .success(moyaResponse):
					do {
						_ = try moyaResponse.filterSuccessfulStatusAndRedirectCodes()
						let object: T = try moyaResponse.map(to: T.self)
						DispatchQueue.main.async {
							UIApplication.shared.isNetworkActivityIndicatorVisible = false
							pending.fulfill(object)
						}
					} catch {
						DispatchQueue.main.async {
							print(error)
							print(type)
							UIApplication.shared.isNetworkActivityIndicatorVisible = false;
							pending.reject(error)
						}
					}
				case let .failure(error):
					DispatchQueue.main.async {
						UIApplication.shared.isNetworkActivityIndicatorVisible = false
						pending.reject(error)
					}
				}
			}
		}
		return pending.promise
	}
	
	internal func makeRequestNoObjectReturn(_ type: JSONAPIRequest<T>) -> Promise<Void> {
		DispatchQueue.main.async {
			UIApplication.shared.isNetworkActivityIndicatorVisible = true;
		}
		let pending = Promise<Void>.pending()
		self.provider.request(type) { result in
			DispatchQueue.global(qos: .utility).async {
				switch result {
				case let .success(moyaResponse):
					do {
						_ = try moyaResponse.filterSuccessfulStatusAndRedirectCodes()
						DispatchQueue.main.async {
							UIApplication.shared.isNetworkActivityIndicatorVisible = false
							pending.fulfill()
						}
					} catch {
						DispatchQueue.main.async {
							print(error)
							UIApplication.shared.isNetworkActivityIndicatorVisible = false
							pending.reject(error)
						}
					}
				case let .failure(error):
					DispatchQueue.main.async {
						UIApplication.shared.isNetworkActivityIndicatorVisible = false
						pending.reject(error)
					}
				}
			}
		}
		return pending.promise
	}
	
	//a wrapper for a request which returns an array of objects
	internal func makeRequestArray(_ type: JSONAPIRequest<T>) -> Promise<[T]> {
		let pending = Promise<[T]>.pending()
		self.provider.request(type) { result in
			DispatchQueue.global(qos: .utility).async {
				switch result {
				case let .success(moyaResponse):
					do {
						_ = try moyaResponse.filterSuccessfulStatusAndRedirectCodes()
						let objects: [T] = try moyaResponse.map(to: [T.self])
						DispatchQueue.main.async {
							pending.fulfill(objects)
						}
					} catch {
						DispatchQueue.main.async {
							print(error)
							pending.reject(error)
						}
					}
				case let .failure(error):
					DispatchQueue.main.async {
						pending.reject(error)
					}
				}
			}
		}
		return pending.promise
	}
}

public class JSONAPIServiceModelStore {
	internal var objStore: [String: [String: PSJSONApiModel]] = [:]
	
	func addObj<T: PSJSONApiModel>(_ obj: T) {
		if self.objStore[T.modelName] == nil {
			self.objStore[T.modelName] = [:]
		}
		self.objStore[T.modelName]?[obj.id] = obj
	}
	
	func getObj<T: PSJSONApiModel>(byId id: String) -> T? {
		return self.objStore[T.modelName]?[id] as? T
	}
	
}

public enum JSONAPITargetMethod {
	case get
	case createObject
	case updateObject
	case deleteObject
	case getObject
}
