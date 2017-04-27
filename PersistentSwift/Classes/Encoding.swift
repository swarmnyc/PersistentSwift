//
//  Encoding.swift
//  Pods
//
//  Created by Alex Hartwell on 4/26/17.
//
//

import Foundation
import Moya


public protocol JSONAPIParamEncodingOptions {
    func encoding(forTargetType targetType: TargetType) -> Moya.ParameterEncoding
}

public struct DefaultJSONAPIParamEncodingOptions: JSONAPIParamEncodingOptions {
    public func encoding(forTargetType targetType: TargetType) -> Moya.ParameterEncoding {
        switch targetType.method {
        case .get:
            return URLEncoding.default
        case .post:
            return JSONEncoding.default
        case .patch:
            return JSONEncoding.default
        case .delete:
            return URLEncoding.default
        case .put:
            return JSONEncoding.default
        default:
            return JSONEncoding.default
        }
    }
}
