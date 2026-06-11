//
//  HiderSearchView.swift
//  hideandseek
//
//  Created by KDHA on 6/2/26.
//

import SwiftUI

/// 숨는 사람이 처음 보는 기본 화면
struct HiderSearchView: View {
    let camera: CameraModel // 상위 View에서 공유받은 카메라
    let timeLeft: Int // 남은 게임 시간. 초단위

    var body: some View {
        VStack {
            GameTimer(timeLeft: timeLeft)
            Spacer()
            bottomMessage
                .padding(.leading, 36)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var bottomMessage: some View {
        VStack(alignment: .leading) {
            Text("주변에")
                .foregroundStyle(.secondary)

            Text("\(Text("술래").foregroundStyle(.primary))를 탐지중")
                .foregroundStyle(.secondary)
        }
        .font(.largeTitle.bold())
    }
}

#Preview {
    HiderSearchView(camera: CameraModel(), timeLeft: 180)
}
