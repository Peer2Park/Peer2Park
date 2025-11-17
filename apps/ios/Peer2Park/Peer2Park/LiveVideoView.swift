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
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                CameraPreview(session: cameraManager.session)
                    .ignoresSafeArea()

                ForEach(cameraManager.yoloDetections) { detection in
                    detectionOverlay(for: detection, in: geo.size)
                }
            }
        }
        .onAppear {
            OrientationLock.lock(.landscape)
        }
        .onDisappear {
            OrientationLock.unlock()
        }
    }

    @ViewBuilder
    private func detectionOverlay(for detection: Detection, in size: CGSize) -> some View {
        let rect = rect(for: detection.boundingBox, in: size)

        ZStack(alignment: .topLeading) {
            Path { path in
                path.addRoundedRect(in: rect, cornerSize: CGSize(width: 8, height: 8))
            }
            .stroke(Color.green, style: StrokeStyle(lineWidth: 2))

            let label = "\(detection.label) \(String(format: "%.0f%%", detection.confidence * 100))"
            Text(label)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.65), in: Capsule())
                .foregroundColor(.white)
                .offset(x: rect.minX, y: max(rect.minY - 24, 0))
        }
    }

    private func rect(for boundingBox: CGRect, in size: CGSize) -> CGRect {
        let width = boundingBox.width * size.width
        let height = boundingBox.height * size.height
        let x = boundingBox.minX * size.width
        let y = boundingBox.minY * size.height
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
