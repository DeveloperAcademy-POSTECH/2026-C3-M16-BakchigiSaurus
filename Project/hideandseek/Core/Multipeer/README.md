# Multipeer 사용 가이드

## 개요

MultipeerGameSession은 GameSession 프로토콜을 실제 MultipeerConnectivity로 구현한 객체입니다.

Feature 쪽에서는 가능한 한 GameSession, PeerID, SessionEvent 같은 추상 타입을 기준으로 사용하고, MCPeerID, MCSession, MCNearbyServiceAdvertiser, MCNearbyServiceBrowser 같은 내부 MC 타입에는 직접 의존하지 않는 것을 목표로 합니다.

현재 MC 구현은 아래 흐름을 담당합니다.

text 호스트 세션 광고 → 주변 호스트 탐색 → 발견된 호스트에게 초대 요청 → MCSession 연결 → 연결/끊김 이벤트 전달 → NI DiscoveryToken 교환 

## 1. 세션 생성

MultipeerGameSession은 MC 연결 흐름을 담당하는 실제 구현체입니다.

swift let multipeerSession = MultipeerGameSession() 

기본적으로 displayName은 UIDevice.current.name을 사용합니다.

swift let multipeerSession = MultipeerGameSession(     displayName: "Player" ) 

PeerID.rawID는 LocalPeerIdentityStore를 통해 로컬에 저장된 UUID 기반 값으로 생성됩니다.  
displayName은 화면에 보여줄 이름으로 사용됩니다.

## 2. 호스트 시작

방을 만든 디바이스는 아래 함수를 호출합니다.

swift multipeerSession.startHosting() 

이 함수는 MCNearbyServiceAdvertiser를 시작해 주변 기기들이 이 호스트를 발견할 수 있게 합니다.

호스트 광고를 중지하려면 아래 함수를 호출합니다.

swift multipeerSession.stopHosting() 

## 3. 주변 호스트 탐색

방에 참가하는 디바이스는 아래 함수를 호출합니다.

swift multipeerSession.startBrowsing() 

이 함수는 MCNearbyServiceBrowser를 사용해 주변에서 광고 중인 호스트를 탐색합니다.

탐색을 중지하려면 아래 함수를 호출합니다.

swift multipeerSession.stopBrowsing() 

## 4. 발견된 호스트 목록 확인

탐색된 호스트 목록은 아래 값으로 확인합니다.

swift multipeerSession.discoveredPeers 

discoveredPeers는 현재 GameSession 프로토콜에는 포함되어 있지 않은 MultipeerGameSession 구현체 전용 상태입니다.

각 peer는 PeerID 타입입니다.

swift struct PeerID {     let rawID: String     let displayName: String } 

rawID는 내부 식별용 값이고, displayName은 화면 표시용 이름입니다.

## 5. 발견된 호스트에게 참가 요청

방 찾기 화면에서 사용자가 특정 호스트를 선택하면 아래 함수를 호출합니다.

swift multipeerSession.invite(selectedPeer) 

Feature 쪽에서는 PeerID만 넘기면 됩니다.  
실제 MC 연결에 필요한 MCPeerID는 MultipeerGameSession 내부에서 매핑해 처리합니다.

사용 예시:

swift let selectedPeer = multipeerSession.discoveredPeers[0] multipeerSession.invite(selectedPeer) 

## 6. 현재 연결된 peer 확인

현재 세션에 연결된 peer 목록은 아래 값으로 확인합니다.

swift multipeerSession.currentPeers 

currentPeers는 GameSession 프로토콜에 포함된 값입니다.

## 7. 연결/끊김 이벤트 구독

연결 상태 변화는 makeEventStream()으로 구독할 수 있습니다.

swift let stream = multipeerSession.makeEventStream()  Task {     for await event in stream {         switch event {         case .peerConnected(let peer):             print("connected:", peer.displayName)          case .peerDisconnected(let peer):             print("disconnected:", peer.displayName)         }     } } 

연결 완료 시에는 아래 이벤트가 전달됩니다.

swift SessionEvent.peerConnected(PeerID) 

연결이 끊기면 아래 이벤트가 전달됩니다.

swift SessionEvent.peerDisconnected(PeerID) 

## 8. NI DiscoveryToken 전송

NearbyInteraction 담당 코드에서 NIDiscoveryToken을 생성한 뒤, 아래 함수를 호출해 상대 peer에게 전송할 수 있습니다.

swift multipeerSession.sendNIDiscoveryToken(localDiscoveryToken) 

특정 peer에게만 보내려면 아래처럼 호출합니다.

swift multipeerSession.sendNIDiscoveryToken(     localDiscoveryToken,     to: targetPeer ) 

peer를 지정하지 않으면 현재 연결된 모든 peer에게 전송합니다.

## 9. NI DiscoveryToken 수신

상대방이 보낸 NIDiscoveryToken은 아래 스트림으로 받을 수 있습니다.

swift let stream = multipeerSession.makeNIDiscoveryTokenStream()  Task {     for await event in stream {         let peer = event.peer         let token = event.token          print("NI token received from:", peer.displayName)     } } 

수신 이벤트 타입은 아래와 같습니다.

swift struct NIDiscoveryTokenEvent {     let peer: PeerID     let token: NIDiscoveryToken } 

MC는 NI token을 전달하는 통로 역할만 합니다.  
실제 NISession 생성, NINearbyPeerConfiguration 적용, 거리/방향 업데이트 처리는 NI 담당 코드에서 처리합니다.

## 10. 호스트/게스트 기본 테스트 흐름

### 호스트 디바이스

swift let session = MultipeerGameSession() session.startHosting() 

### 게스트 디바이스

swift let session = MultipeerGameSession() session.startBrowsing() 

탐색된 호스트 확인:

swift let peers = session.discoveredPeers 

호스트 선택 후 초대:

swift if let host = peers.first {     session.invite(host) } 

연결 이벤트 확인:

swift let stream = session.makeEventStream()  Task {     for await event in stream {         print(event)     } } 

## 11. 주의사항

- 실제 기기 2대 이상에서 테스트하는 것을 권장합니다.
- Local Network 권한 요청이 뜨면 허용해야 합니다.
- 호스트와 게스트는 같은 근거리 네트워크 환경에 있어야 합니다.
- serviceType은 코드의 "hide-seek"과 Info 설정의 "_hide-seek._tcp"가 일치해야 합니다.
- MCPeerID, MCSession 등 MC 내부 타입은 가능한 한 Feature 쪽에 직접 노출하지 않습니다.
- Feature는 PeerID, SessionEvent, NIDiscoveryTokenEvent 중심으로 사용합니다.

