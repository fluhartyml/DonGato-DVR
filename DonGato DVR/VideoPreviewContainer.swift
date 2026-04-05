//
//  VideoPreviewContainer.swift
//  DonGato DVR
//
//  Created by Michael Fluharty on 4/5/26.
//

import SwiftUI
import AVFoundation

#if os(iOS)
struct VideoPreviewContainer: UIViewRepresentable {
    @Environment(CaptureService.self) private var captureService

    func makeUIView(context: Context) -> VideoPreviewUIView {
        let view = VideoPreviewUIView()
        return view
    }

    func updateUIView(_ uiView: VideoPreviewUIView, context: Context) {
        if let layer = captureService.previewLayer {
            uiView.updatePreviewLayer(layer)
        }
    }
}

class VideoPreviewUIView: UIView {
    private var currentPreviewLayer: AVCaptureVideoPreviewLayer?

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    func updatePreviewLayer(_ newLayer: AVCaptureVideoPreviewLayer) {
        guard currentPreviewLayer?.session !== newLayer.session else { return }
        currentPreviewLayer?.removeFromSuperlayer()

        newLayer.frame = bounds
        newLayer.videoGravity = .resizeAspect
        layer.addSublayer(newLayer)
        currentPreviewLayer = newLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        currentPreviewLayer?.frame = bounds
    }
}

#elseif os(macOS)
struct VideoPreviewContainer: NSViewRepresentable {
    @Environment(CaptureService.self) private var captureService

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let layer = captureService.previewLayer, let viewLayer = nsView.layer {
            if viewLayer.sublayers?.first(where: { $0 is AVCaptureVideoPreviewLayer }) == nil {
                layer.frame = nsView.bounds
                viewLayer.addSublayer(layer)
            }
        }
    }
}
#endif
