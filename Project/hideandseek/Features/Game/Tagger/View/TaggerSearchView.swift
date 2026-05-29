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
                                .font(.title)
                                .bold()
                                .foregroundStyle(Color.gray)
                            HStack {
                                Text("숨은 사람")
                                    .font(.title)
                                    .bold()
                                    .foregroundStyle(Color.white)
                                Text("을 찾는 중")
                                    .font(.title)
                                    .bold()
                                    .foregroundStyle(Color.gray)
                            }
                            Button("힌트 n 개 남음") {
                                // TODO: 힌트 갯수 연결
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.clear)
                            .background(.ultraThinMaterial)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.5), lineWidth: 1))
                            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                            .cornerRadius(20)
                            .padding(.top, 2)
                            .padding(.bottom, 10)
                        }
                        Spacer()
                    }
                }
            }
            .padding(30)
        }
    }
}

#Preview {
    TaggerSearchView()
}
