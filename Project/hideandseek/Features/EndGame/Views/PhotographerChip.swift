//
//  PhotographerChip.swift
//  hideandseek
//

import SwiftUI

struct PhotographerChip: View {
    let photo: CapturedPhoto

    var body: some View {
        HStack(spacing: 10) {
            Text(initial)
                .font(.caption.bold())
                .foregroundStyle(.black)
                .frame(width: 32, height: 32)
                .background(.white, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(photo.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    roleBadge
                        .fixedSize()
                }

                Text(timeText)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.black.opacity(0.34), in: Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var roleBadge: some View {
        Text(roleText)
            .font(.caption2.bold())
            .foregroundStyle(roleForeground)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(roleBackground, in: Capsule())
    }

    private var initial: String {
        String(photo.displayName.prefix(1))
    }

    private var roleText: String {
        switch photo.photographerRole {
        case .tagger:
            "술래"
        case .hider:
            "숨는 사람"
        case .unassigned, nil:
            "참여자"
        }
    }

    private var roleForeground: Color {
        switch photo.photographerRole {
        case .tagger:
            .yellow
        case .hider:
            .green
        case .unassigned, nil:
            .white
        }
    }

    private var roleBackground: Color {
        switch photo.photographerRole {
        case .tagger:
            .yellow.opacity(0.18)
        case .hider:
            .green.opacity(0.18)
        case .unassigned, nil:
            .white.opacity(0.14)
        }
    }

    private var timeText: String {
        let elapsed = Date().timeIntervalSince(photo.capturedAt)
        if elapsed < 60 {
            return "방금"
        }

        if elapsed < 60 * 60 {
            return "\(Int(elapsed / 60))분 전"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: photo.capturedAt)
    }
}
