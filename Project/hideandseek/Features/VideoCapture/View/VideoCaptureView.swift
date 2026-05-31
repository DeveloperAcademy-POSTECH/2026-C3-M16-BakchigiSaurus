//
//  VideoCaptureView.swift
//  hideandseek
//
//  Created by Gosan on 5/29/26.
//

import AVFoundation
import SwiftUI

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    
    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

struct RecordingView: View {
    @State private var model = CameraModel()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            CameraPreview(session: model.service.session)
                .ignoresSafeArea()
            
            Button {
                Task { await model.toggleRecording() }
            } label: {
                Circle()
                    .fill(model.isRecording ? .red : .white)
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(.white, lineWidth: 4).padding(4))
            }
            .padding(.bottom, 40)
        }
        .task { await model.bootstrap() }
    }
}

#Preview {
    RecordingView()
}
