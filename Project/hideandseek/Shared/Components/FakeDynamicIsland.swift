//
//  FakeDynamicIsland.swift
//  hideandseek
//
//  Created by Lanakee on 6/5/26.
//

import SwiftUI

struct FakeDynamicIslandView<Compact: View, Expanded: View>: View {
    let isExpanded: Bool
    @ViewBuilder var compact: () -> Compact
    @ViewBuilder var expanded: () -> Expanded

    private let compactSize = CGSize(width: 126, height: 37.33)
    private let expandedSize = CGSize(width: 370, height: 150)

    private var size: CGSize {
        isExpanded ? expandedSize : compactSize
    }

    private var cornerRadius: CGFloat {
        isExpanded ? 46 : compactSize.height / 2
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black)
                .frame(width: size.width, height: size.height)
                .shadow(color: .black.opacity(0.22), radius: 14, y: 6)

            Group {
                if isExpanded {
                    expanded()
                        .frame(width: expandedSize.width, height: expandedSize.height)
                } else {
                    compact()
                        .frame(width: compactSize.width, height: compactSize.height)
                }
            }
            .transition(.opacity)
        }
        .animation(.bouncy(duration: 0.55, extraBounce: 0.05), value: isExpanded)
    }
}

private struct IslandCompactContent: View {
    var body: some View {
        EmptyView()
    }
}

enum IslandAlertType {
    case taggerNearby
    case hiderNearby

    var message: String {
        switch self {
        case .taggerNearby: "주변에 술래가 있어요"
        case .hiderNearby: "근처에 숨은사람이 있어요"
        }
    }

    var accentColor: Color {
        switch self {
        case .taggerNearby: .appDanger
        case .hiderNearby: .appWarning
        }
    }

    var showsIcon: Bool {
        switch self {
        case .taggerNearby: true
        case .hiderNearby: false
        }
    }
}

private struct IslandExpandedContent: View {
    let timeLeft: Int
    let type: IslandAlertType

    private var formattedTime: String {
        String(format: "%d:%02d", timeLeft / 60, timeLeft % 60)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(formattedTime)
                .font(.largeTitle.bold())
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: true))

            HStack(spacing: 8) {
                if type.showsIcon {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(type.accentColor)
                }

                Text(type.message)
                    .font(.title.bold())
                    .foregroundStyle(type.accentColor)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("주변에 술래가 있어요") {
    ZStack(alignment: .top) {
        Color(.white).ignoresSafeArea()

        FakeDynamicIslandView(isExpanded: true) {
            IslandCompactContent()
        } expanded: {
            IslandExpandedContent(timeLeft: 180, type: .taggerNearby)
        }
        .padding(.top, 12)
        .ignoresSafeArea()
    }
}

#Preview("근처에 숨은사람이 있어요") {
    ZStack(alignment: .top) {
        Color(.white).ignoresSafeArea()

        FakeDynamicIslandView(isExpanded: true) {
            IslandCompactContent()
        } expanded: {
            IslandExpandedContent(timeLeft: 180, type: .hiderNearby)
        }
        .padding(.top, 12)
        .ignoresSafeArea()
    }
}
