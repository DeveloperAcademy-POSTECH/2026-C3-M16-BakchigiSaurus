//
//  TaggerSignalView.swift
//  hideandseek
//
//  Created by KDHA on 6/1/26.
//

import SwiftUI

/// 술래 접근 정도를 보여주는 컴포넌트
struct TaggerSignalView: View {
    let signal: TaggerSignal

    var body: some View {
        VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(signalColor.opacity(0.18))
                            .frame(width: 96, height: 96)

                        Circle()
                            .stroke(signalColor.opacity(0.45), lineWidth: 2)
                            .frame(width: 84, height: 84)

                        Image(systemName: signalIcon)
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(signalColor)
                    }

                    VStack(spacing: 4) {
                        Text(signalTitle)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)

                        Text(signalDescription)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .multilineTextAlignment(.center)
                }
            }

            private var signalIcon: String {
                switch signal {
                case .unknown:
                    return "questionmark"

                case .far:
                    return "checkmark"

                case .near:
                    return "exclamationmark"

                case .veryNear:
                    return "exclamationmark.triangle.fill"
                }
            }

            private var signalTitle: String {
                switch signal {
                case .unknown:
                    return "탐색 중"

                case .far:
                    return "안전"

                case .near:
                    return "주의"

                case .veryNear:
                    return "위험"
                }
            }

            private var signalDescription: String {
                switch signal {
                case .unknown:
                    return "술래 위치를 알 수 없음"

                case .far:
                    return "술래가 멀리 있어요"

                case .near:
                    return "술래가 가까워지고 있어요"

                case .veryNear:
                    return "술래가 매우 가까워요"
                }
            }

            private var signalColor: Color {
                switch signal {
                case .unknown:
                    return .gray

                case .far:
                    return .green

                case .near:
                    return .orange

                case .veryNear:
                    return Color(red: 1.0, green: 0.24, blue: 0.27)
                }
            }
        }

        #Preview("위치 모름") {
            TaggerSignalView(signal: .unknown)
                .padding()
                .background(.black)
        }

        #Preview("안전") {
            TaggerSignalView(signal: .far)
                .padding()
                .background(.black)
        }

        #Preview("주의") {
            TaggerSignalView(signal: .near)
                .padding()
                .background(.black)
        }

        #Preview("위험") {
            TaggerSignalView(signal: .veryNear)
                .padding()
                .background(.black)
        }
