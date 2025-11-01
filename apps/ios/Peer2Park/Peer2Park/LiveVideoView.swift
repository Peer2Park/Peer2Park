//
//  LiveVideoView.swift
//  Peer2Park
//
//  Updated for YOLO11n CoreML (with NMS)
//

import SwiftUI
import AVFoundation

struct LiveVideoView: View {
    @ObservedObject var cameraManager: CameraManager

    var body: some View {
        ZStack {
            CameraPreview(session: cameraManager.session)
                .ignoresSafeArea()

            ForEach(cameraManager.yoloDetections) { detection in
                GeometryReader { geo in
                    let frame = detection.boundingBox
                    let rect = CGRect(
                        x: frame.minX * geo.size.width,
                        y: frame.minY * geo.size.height,
                        width: frame.width * geo.size.width,
                        height: frame.height * geo.size.height
                    )

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.green, lineWidth: 2)
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)

                        Text("\(detection.label) \(String(format: "%.2f", detection.confidence))")
                            .font(.caption2)
                            .padding(4)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                            .position(x: rect.minX + 6, y: rect.minY + 10)
                    }
                }
            }
        }
    }
}
