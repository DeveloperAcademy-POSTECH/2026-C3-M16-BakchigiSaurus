//
//  TaggerSearchView.swift
//  hideandseek
//
//  Created by 캄초 on 5/28/26.
//

import SwiftUI

struct TaggerSearchView: View {
    var body: some View {
        ZStack {
//            TODO: CameraView 호출
//            Color.orange
//                .ignoresSafeArea()
            ZStack {
                VStack {
                    GameTimer(timeLeft: 300)
                    Spacer()
                    HStack {
                        VStack(alignment: .leading) {
                            Text("주변에")
                                .font(.largeTitle.bold())
                                .foregroundStyle(Color.gray)
                            HStack {
                                Text("숨은 사람")
                                    .font(.largeTitle.bold())
                                    .foregroundStyle(Color.white)
                                Text("을 찾는 중")
                                    .font(.largeTitle.bold())
                                    .foregroundStyle(Color.gray)
                            }
                            Button {
                                // TODO: 힌트 갯수 연결

                            } label: {
                                Label("힌트 (n개 남음)", systemImage: "magnifyingglass")
                                    .padding(.vertical, 10)
                                    .font(.title3)
                            }
                            .buttonStyle(.glass)
                            .cornerRadius(20)
                            .padding(.bottom, 7)
                        }
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

#Preview {
    TaggerSearchView()
}
