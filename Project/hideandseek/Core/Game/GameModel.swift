//
//  GameModel.swift
//  hideandseek
//
//  Created by Lanakee on 6/4/26.
//

import Foundation
import Observation

// MARK: - Phase

/// 게임 진행 단계.
enum GamePhase: Hashable {
    /// 방 대기실. 참가자가 모이고 술래를 지정하는 단계.
    case lobby
    /// 숨는 시간 카운트다운 중. (settings.hideTimeSeconds)
    case hiding
    /// 술래가 찾는 중. (settings.gameTotalSeconds)
    case playing
    /// 게임 종료.
    case ended
}

// MARK: - Room Settings

/// 방 설정값.
struct RoomSettings: Hashable {
    var name: String
    var maxCount: Int
    var hintCount: Int
    var hideTimeSeconds: Int
    var gameMinutes: Int

    /// 게임 시간 총 초.
    var gameTotalSeconds: Int {
        gameMinutes * 60
    }

    static let `default` = RoomSettings(
        name: "",
        maxCount: 6,
        hintCount: 3,
        hideTimeSeconds: 10,
        gameMinutes: 10
    )
}

// MARK: - Participant

/// 게임 참가자.
/// 네트워크 식별자(PeerID)와 별개의 안정적인 UUID를 가진다.
struct GameParticipant: Identifiable, Hashable {
    let id: UUID
    let peerID: PeerID?
    let name: String
    var isTagger: Bool
    var isHost: Bool

    init(
        id: UUID = UUID(),
        peerID: PeerID? = nil,
        name: String,
        isTagger: Bool = false,
        isHost: Bool = false
    ) {
        self.id = id
        self.peerID = peerID
        self.name = name
        self.isTagger = isTagger
        self.isHost = isHost
    }
}

// MARK: - Model

@Observable
@MainActor
final class GameModel {
    /// 방 설정.
    var settings: RoomSettings = .default

    /// 현재 방의 참가자 목록.
    var participants: [GameParticipant] = []

    /// 로컬(내 기기) 참가자 ID.
    var localParticipantID: UUID?

    /// 게임 진행 단계.
    private(set) var phase: GamePhase = .lobby

    /// 현재 단계 기준 남은 시간(초). 단계 시작 시 설정되어 1초마다 감소한다.
    private(set) var remainingSeconds: Int = 0

    /// 카운트다운 Task. 단계 전이/리셋 시 취소된다.
    private var timerTask: Task<Void, Never>?

    /// 술래로 지정된 참가자.
    var tagger: GameParticipant? {
        participants.first(where: { $0.isTagger })
    }

    /// 방 정원이 다 찼는가.
    var isFull: Bool {
        participants.count >= settings.maxCount
    }

    /// "현재/정원" 라벨용 문자열. ("4/6")
    var capacityText: String {
        "\(participants.count)/\(settings.maxCount)"
    }

    // MARK: Participants

    /// 참가자 추가. 이미 있는 ID거나 정원 초과면 무시.
    func addParticipant(_ participant: GameParticipant) {
        guard !isFull else { return }
        guard !participants.contains(where: { $0.id == participant.id }) else { return }
        participants.append(participant)
    }

    /// 참가자 제거.
    func removeParticipant(id: UUID) {
        participants.removeAll(where: { $0.id == id })
    }

    /// 술래 지정. nil을 넘기면 전원 해제.
    func setTagger(participantID: UUID?) {
        for index in participants.indices {
            participants[index].isTagger = (participants[index].id == participantID)
        }
    }

    /// 술래 미지정 상태면 무작위로 한 명을 술래로 지정한다.
    func assignRandomTaggerIfNeeded() {
        guard tagger == nil, let random = participants.randomElement() else { return }
        setTagger(participantID: random.id)
    }

    // MARK: Phase Transitions

    /// 숨는 단계 시작. 술래가 없으면 랜덤 지정.
    func startHiding() {
        assignRandomTaggerIfNeeded()
        phase = .hiding
        remainingSeconds = settings.hideTimeSeconds
        startTimer()
    }

    /// 진행 단계 시작. 남은시간 = settings.gameTotalSeconds.
    func startPlaying() {
        phase = .playing
        remainingSeconds = settings.gameTotalSeconds
        startTimer()
    }

    /// 게임 종료. 타이머 중단.
    func endGame() {
        stopTimer()
        phase = .ended
    }

    /// 대기실로 초기화. 설정/참가자는 유지하고 술래 지정만 해제.
    func resetToLobby() {
        stopTimer()
        phase = .lobby
        remainingSeconds = 0
        for index in participants.indices {
            participants[index].isTagger = false
        }
    }

    // MARK: Timer

    private func startTimer() {
        stopTimer()
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                guard let self else { return }
                self.tick()
                if self.remainingSeconds <= 0 { return }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    /// 1초마다 호출되어 남은시간을 줄이고, 0이 되면 다음 단계로 전이한다.
    private func tick() {
        guard remainingSeconds > 0 else { return }
        remainingSeconds -= 1
        if remainingSeconds <= 0 {
            advancePhaseOnTimeUp()
        }
    }

    /// 남은시간이 0이 됐을 때 단계 전이.
    /// hiding -> playing, playing -> ended.
    private func advancePhaseOnTimeUp() {
        switch phase {
        case .hiding:
            startPlaying()
        case .playing:
            endGame()
        case .lobby, .ended:
            break
        }
    }
}
