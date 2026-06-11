//
//  CameraErrorEnum.swift
//  hideandseek
//
//  Created by Lanakee on 6/2/26.
//

enum CameraError: Error {
    /// 세션이 실행 중이 아니라 촬영할 수 없는 상태.
    case sessionNotRunning
    /// 캡처는 됐지만 이미지 데이터로 인코딩하지 못한 경우.
    case photoEncodingFailed
}
