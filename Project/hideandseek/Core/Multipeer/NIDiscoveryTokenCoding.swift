//
//  NIDiscoveryTokenCoding.swift
//  hideandseek
//
//  Created by 서혜린 on 6/5/26.
//
//  NIDiscoveryTokenCoding.swift
//  hideandseek
//

import Foundation
import NearbyInteraction

/// NIDiscoveryToken을 MCSession으로 보내기 위해 Data로 변환하고,
/// 수신한 Data를 다시 NIDiscoveryToken으로 복원하는 유틸.
enum NIDiscoveryTokenCoding {
    enum CodingError: Error {
        case invalidTokenData
    }

    static func encode(_ token: NIDiscoveryToken) throws -> Data {
        try NSKeyedArchiver.archivedData(
            withRootObject: token,
            requiringSecureCoding: true
        )
    }

    static func decode(from data: Data) throws -> NIDiscoveryToken {
        guard let token = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: NIDiscoveryToken.self,
            from: data
        ) else {
            throw CodingError.invalidTokenData
        }

        return token
    }
}
