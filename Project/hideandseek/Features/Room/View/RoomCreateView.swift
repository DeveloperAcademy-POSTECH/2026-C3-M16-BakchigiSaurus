//
//  RoomCreateView.swift
//  hideandseek
//
//  Created by Lanakee on 6/4/26.
//

import SwiftUI

struct RoomCreateView: View {
    @State private var roomName: String = ""
    @State private var hintCount: Int = 3
    @State private var hideTime: Int = 10
    @State private var gameMinutes: Int = 10
    @FocusState private var gameTimeFocused: Bool

    private let hideTimeOptions = [10, 15, 30, 45, 60]
    private let hintRange = 1 ... 9
    private let gameMinutesRange = 1 ... 99

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    roomNameSection
                    hintCountSection
                    hideTimeSection
                    gameTimeSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.immediately)

            Button {} label: {
                Text("설정 완료")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .tint(.accent)
            .buttonStyle(.glassProminent)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(.appBackground)
        .navigationTitle("방 설정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var roomNameSection: some View {
        section(title: "방 이름") {
            TextField(
                "",
                text: $roomName,
                prompt:
                Text("예: 박치기 사우루스 숨바꼭질").foregroundStyle(.secondary)
            )
            .font(.body)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var hintCountSection: some View {
        section(title: "힌트 수") {
            HStack(spacing: 12) {
                stepperButton(systemName: "minus") {
                    if hintCount > hintRange.lowerBound { hintCount -= 1 }
                }
                Spacer()
                Text("\(hintCount)")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Spacer()
                stepperButton(systemName: "plus") {
                    if hintCount < hintRange.upperBound { hintCount += 1 }
                }
            }
        }
    }

    private var hideTimeSection: some View {
        section(title: "숨는 시간") {
            Picker("", selection: $hideTime) {
                ForEach(hideTimeOptions, id: \.self) { value in
                    Text("\(value)초").tag(value)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var gameTimeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("게임 시간")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Spacer()
                TextField("0", value: $gameMinutes, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .fixedSize()
                    .focused($gameTimeFocused)
                    .onChange(of: gameMinutes) { _, newValue in
                        if newValue < gameMinutesRange.lowerBound {
                            gameMinutes = gameMinutesRange.lowerBound
                        } else if newValue > gameMinutesRange.upperBound {
                            gameMinutes = gameMinutesRange.upperBound
                        }
                    }
                Text("분")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .contentShape(Rectangle())
            .onTapGesture { gameTimeFocused = true }
        }
    }

    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func stepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.bold())
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

#Preview {
    NavigationStack {
        RoomCreateView()
    }
    .preferredColorScheme(.dark)
}
