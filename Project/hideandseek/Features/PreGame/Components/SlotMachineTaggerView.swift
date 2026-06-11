//
//  SlotMachineTaggerView.swift
//  hideandseek
//
//  Created by Lanakee on 6/10/26.
//

import SwiftUI

struct SlotMachineTaggerView: View {
    let playerNames: [String]
    let taggerName: String
    var onComplete: (() -> Void)?

    @State private var stream: [String] = []
    @State private var scrollOffset: CGFloat = 0
    @State private var labelOpacity: Double = 0
    @State private var landed: Bool = false
    @State private var didStart = false

    private let rowHeight: CGFloat = 52
    private let visibleRows = 5

    private var slotHeight: CGFloat {
        rowHeight * CGFloat(visibleRows)
    }

    private var landedLabelOffset: CGFloat {
        rowHeight * 0.72
    }

    private var spinningLabelOffset: CGFloat {
        slotHeight / 2 + 28
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            slotWindow

            Text("술래는")
                .font(.title)
                .foregroundStyle(.white.opacity(0.85))
                .opacity(labelOpacity)
                .offset(y: landed ? -landedLabelOffset : -spinningLabelOffset)

            Text("입니다")
                .font(.title)
                .foregroundStyle(.white.opacity(0.85))
                .opacity(labelOpacity)
                .offset(y: landed ? landedLabelOffset : spinningLabelOffset)
        }
        .onAppear {
            guard !didStart else { return }
            didStart = true
            stream = buildStream()
            Task { await runAnimation() }
        }
    }

    private var slotWindow: some View {
        GeometryReader { proxy in
            let centerY = proxy.size.height / 2
            VStack(spacing: 0) {
                ForEach(stream.indices, id: \.self) { index in
                    row(name: stream[index], centerY: centerY)
                }
            }
            .offset(y: scrollOffset)
        }
        .frame(height: slotHeight)
        .coordinateSpace(name: slotCoordinateSpace)
        .mask(
            LinearGradient(
                stops: maskStops,
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var maskStops: [Gradient.Stop] {
        if landed {
            return [
                .init(color: .clear, location: 0.0),
                .init(color: .clear, location: 0.44),
                .init(color: .white, location: 0.48),
                .init(color: .white, location: 0.52),
                .init(color: .clear, location: 0.56),
                .init(color: .clear, location: 1.0)
            ]
        }
        return [
            .init(color: .clear, location: 0.0),
            .init(color: .white, location: 0.35),
            .init(color: .white, location: 0.65),
            .init(color: .clear, location: 1.0)
        ]
    }

    private func row(name: String, centerY: CGFloat) -> some View {
        GeometryReader { proxy in
            let rowCenter = proxy.frame(in: .named(slotCoordinateSpace)).midY
            let distance = abs(rowCenter - centerY) / rowHeight
            let normalized = min(distance / 2.0, 1.0)
            Text(name)
                .font(.system(size: 28 - normalized * 12, weight: .bold))
                .foregroundStyle(.white.opacity(1.0 - normalized * 0.78))
                .scaleEffect(1.0 - normalized * 0.15)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: rowHeight)
    }

    private var slotCoordinateSpace: String {
        "slot-machine"
    }

    private func buildStream() -> [String] {
        guard !playerNames.isEmpty else { return [taggerName] }

        let leading = visibleRows / 2
        let trailing = visibleRows - leading - 1
        var built: [String] = Array(repeating: "", count: leading)

        for _ in 0 ..< 5 {
            built.append(contentsOf: playerNames.shuffled())
        }

        let others = playerNames.filter { $0 != taggerName }
        built.append(contentsOf: others.shuffled())
        built.append(taggerName)
        built.append(contentsOf: Array(repeating: "", count: trailing))

        return built
    }

    @MainActor
    private func runAnimation() async {
        guard stream.count > visibleRows else {
            withAnimation(.easeInOut(duration: 0.5)) {
                labelOpacity = 1
                landed = true
            }
            onComplete?()
            return
        }

        let totalTicks = stream.count - visibleRows
        let labelTriggerTick = Int(Double(totalTicks) * 0.7)

        for tick in 1 ... totalTicks {
            let progress = Double(tick) / Double(totalTicks)
            let interval = 0.04 + pow(progress, 3.2) * 0.5

            withAnimation(.easeOut(duration: interval * 0.95)) {
                scrollOffset = -CGFloat(tick) * rowHeight
            }

            if tick == labelTriggerTick {
                withAnimation(.easeIn(duration: 0.5)) {
                    labelOpacity = 1
                }
            }

            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }

        withAnimation(.easeInOut(duration: 0.55)) {
            labelOpacity = 1
            landed = true
        }

        onComplete?()
    }
}

#Preview {
    SlotMachineTaggerView(
        playerNames: ["플레이어 1", "플레이어 2", "플레이어 3", "플레이어 4", "캄초의 iPhone"],
        taggerName: "캄초의 iPhone"
    )
}
