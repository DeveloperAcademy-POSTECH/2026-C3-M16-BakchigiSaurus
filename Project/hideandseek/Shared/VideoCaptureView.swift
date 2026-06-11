//
//  VideoCaptureView.swift
//  hideandseek
//
//  Created by Gosan on 5/29/26.
//

import AVFoundation
import SwiftUI

// =====================================================================
// MARK: - Usage Examples

// 아래 세 뷰는 사용법을 보여주는 예시다. 핵심은:
//   · 카메라 모델은 루트에서 1개만 만들어 공유한다.
//   · reveal(블러) 조건을 페이지마다 다르게 줄 수 있다.
// =====================================================================

// 게임 루트: 카메라 1개를 만들어 게임 내내 유지하고 각 페이지에 주입한다.
// ```swift
// struct GameRootView: View {
//    @State private var camera = CameraModel()   // @Observable → @State로 소유
//
//    var body: some View {
//        // 실제로는 NavigationStack 등으로 두 페이지를 오가며 같은 camera를 전달한다.
//        SeekerPage(camera: camera, isHiderNearby: false, isUsingHint: false)
//            .task { await camera.bootstrap() }   // 시동은 여기서 단 한 번
//    }
// }
// ```
// 숨는 사람 화면: 술래가 근접하면 화면이 공개된다.
// ```swift
// struct HiderPage: View {
//    let camera: CameraModel        // @Observable → 그냥 let으로 받음
//    let isSeekerNearby: Bool       // NearbyInteraction 등 근접 판정에서 주입
//
//    var body: some View {
//        ZStack {
//            GameCameraBackground(camera: camera,
//                                 isRevealed: isSeekerNearby)
//            // ... 게임 UI를 위에 얹음
//        }
//    }
// }
// ```
//
// 술래 화면: 블러는 "근접 + 힌트 사용 중"일 때만 걷힌다.
// ```swift
// struct SeekerPage: View {
//    let camera: CameraModel
//    let isHiderNearby: Bool
//    let isUsingHint: Bool
//
//    var body: some View {
//        ZStack {
//            GameCameraBackground(camera: camera,
//                                 isRevealed: isHiderNearby && isUsingHint)
//            // ... 게임 UI를 위에 얹음
//        }
//    }
// }
// ```
//

// =====================================================================
// MARK: - Preview Bridge

// =====================================================================

/// `AVCaptureVideoPreviewLayer`를 호스팅하는 UIKit 뷰.
///
/// `layerClass`를 오버라이드해 레이어를 뷰의 backing layer로 직접 쓰므로
/// 프레임 동기화를 수동으로 할 필요가 없다.
final class PreviewView: UIView {
    // swiftlint:disable:next static_over_final_class
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

/// 카메라 미리보기를 SwiftUI에 올리는 브리지.
///
/// `AVCaptureVideoPreviewLayer`는 `CALayer`라 SwiftUI에 직접 못 올리므로
/// `UIViewRepresentable`로 ``PreviewView``를 감싼다.
struct CameraPreview: UIViewRepresentable {
    /// 미리보기에 연결할 캡처 세션. 보통 `camera.service.session`을 넘긴다.
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

// =====================================================================
// MARK: - GameCameraBackground

// =====================================================================

/// 화면 배경에 카메라 미리보기를 깔고, 촬영 가능 여부에 따라 블러로 가리는 재사용 컴포넌트.
///
/// 카메라는 항상 켜져 있고(``CameraModel``이 관리), 이 뷰는 `isRevealed` 하나로만 동작한다.
/// 페이지 배경(ZStack 최하단)에 깔아 그 위에 게임 UI를 얹는 용도다.
///
/// `isRevealed`는 "촬영 가능 상태"를 뜻한다.
///  · true  → 블러 없이 카메라가 보임 = 촬영 가능
///  · false → 블러로 가림 = 촬영 불가
///
/// ```swift
/// // 숨는 사람: 항상 촬영 가능
/// GameCameraBackground(camera: camera, isRevealed: true)
/// // 술래: 다이내믹 아일랜드가 확장됐을 때만 촬영 가능
/// GameCameraBackground(camera: camera, isRevealed: viewModel.isIslandExpanded)
/// ```
struct GameCameraBackground: View {
    /// 게임 루트에서 만든 **공유** 카메라 모델.
    let camera: CameraModel
    /// `false`면 블러로 카메라를 가린다(촬영 불가). 공개 조건은 페이지마다 다르게 주입한다.
    let isRevealed: Bool

    var body: some View {
        ZStack {
            CameraPreview(session: camera.service.session)
                .ignoresSafeArea()

            if !isRevealed {
                Rectangle()
                    .fill(.regularMaterial) // 더 진하게 가리려면 .thickMaterial
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isRevealed)
    }
}

// #Preview {
//    GameCameraBackground()
// }
