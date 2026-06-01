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
        
        if isAlertPresented {
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        //is AlertPresented = false
                    }
                VStack(alignment: .leading, spacing: 16) {
                    Text("힌트를 사용할까요?")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text("가장 가까운 사람의 방향이 잠시동안 표시됩니다")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                }
            }
        }
    }
}
    
    #Preview {
        HintActivationView(isAlertPresented: .constant(true))
    }
