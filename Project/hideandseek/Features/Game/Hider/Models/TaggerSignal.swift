//
//  TaggerSignal.swift
//  hideandseek
//
//  Created by KDHA on 6/1/26.
//

import Foundation

enum TaggerSignal: String, Codable {
    case unknown // 술래 위치 아직 모름
    case far // 술래가 멀리 있음
    case near // 술래가 가까이 있음
    case veryNear // 술래가 매우 가까이 있음
}
