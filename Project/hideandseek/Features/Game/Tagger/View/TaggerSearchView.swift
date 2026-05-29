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
            // TODO: CameraView 호출
            VStack {
                Text("timer")
                Spacer()
                HStack {
                    VStack (alignment: .leading) {
                        Text("주변에")
                            .font(.title)
                            .bold()
                            .foregroundStyle(Color.gray)
                        Text("숨은 사람을 찾는 중")
                            .font(.title)
                            .bold()
                            .foregroundStyle(Color.gray)
                        Button("힌트 n개 남음") {
                            //힌트플로우 연결
                        }
                        .padding(.top,2)
                        .padding(.bottom,10)
                    }
                    Spacer()
                }
            }
        }
        .padding(30)
    }
}

#Preview {
    TaggerSearchView()
}
