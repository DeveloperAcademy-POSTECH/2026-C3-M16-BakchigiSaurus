//
//  HiderModeState.swift
//  hideandseek
//
//  Created by KDHA on 6/1/26.
//

import Foundation

enum HiderModeState {
    case hiding // 숨는 중. 술래 탐지 중
    case taggerNearby // 술래가 가까움, 경고 표시
    case recording // 카메라 켜지고 녹화됨
    case taggedCheck // 술래에게 잡혔는지 확인 화면
}
