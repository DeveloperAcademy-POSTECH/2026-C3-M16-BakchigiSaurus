//
//  HintActivationView.swift
//  hideandseek
//
//  Created by 캄초 on 5/28/26.
//

import SwiftUI

struct HintActivationView: View {
    
    @Binding var isAlertPresented: Bool
    
    var body: some View {
        EmptyView()
            .alert("힌트를 사용할까요?", isPresented: $isAlertPresented) {
                Button("네", role: .none) {
                    //TODO: HintSuccessView Or HintFailureView 로 이동함
                }
                Button("아니요", role: .cancel) { }
            } message: {
                Text("가장 가까운 사람의 방향이 잠시동안 표시됩니다")
            }
    }
}

#Preview {
    HintActivationView(isAlertPresented: .constant(true))
}
