//
//  CameraManager.swift
//  Peer2Park
//
//  Updated for YOLO11n CoreML with built-in NMS
//

import Foundation
import AVFoundation
import SwiftUI
import Vision
import CoreML

struct Detection: Identifiable {
    let id = UUID()
    let label: String
    let confidence: Float
    let boundingBox: CGRect // normalized coordinates (x, y, w, h)
}

final class CameraManager: NSObject, ObservableObject {
    @Published var status: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published var session = AVCaptureSession()
    @Published var yoloDetections: [Detection] = []

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoOutput = AVCaptureVideoDataOutput()
    private var visionRequest: VNCoreMLRequest?
    private var modelLoaded = false
    private var lastInferenceTime: CFTimeInterval = 0
    private let minInferenceInterval: CFTimeInterval = 1.0 / 15.0
    
    // MARK: - Initialization
    override init() {
        super.init()
        print("[CameraManager] init() – configuring session and model…")
        configureSession()
        setupVision()
    }
    
    // MARK: Setup Video
    func requestPermission() {
        print("[CameraManager] Requesting camera permission…")
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.status = AVCaptureDevice.authorizationStatus(for: .video)
                print("[CameraManager] Permission result: granted? \(granted)")
                if granted { self.startSession() }
            }
        }
    }
    
    private func configureSession() {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: .back)
            else {
                print("[CameraManager] ❌ No camera device found!")
                self.session.commitConfiguration()
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
            } catch {
                print("[CameraManager] Input creation error: \(error)")
            }

            self.videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            let outputQueue = DispatchQueue(label: "camera.video.output.queue")
            self.videoOutput.setSampleBufferDelegate(self, queue: outputQueue)

            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            }

            if let conn = self.videoOutput.connection(with: .video) {
                let portraitAngle: CGFloat = 90
                                if conn.isVideoRotationAngleSupported(portraitAngle) {
                                    conn.videoRotationAngle = portraitAngle
                                    print("[CameraManager] 🎞️ Set videoRotationAngle = \(portraitAngle)")
                }
            }


            self.session.commitConfiguration()
            print("[CameraManager] ✅ Session configured")
        }
    }
    // MARK: Setup Vision
    private func setupVision() {
        sessionQueue.async {
            guard let modelURL = Bundle.main.url(forResource: "yolo11n", withExtension: "mlmodelc") else {
                print("[CameraManager] ❌ Model not found in bundle")
                return
            }
            do {
                let coreMLModel = try MLModel(contentsOf: modelURL)
                let vnModel = try VNCoreMLModel(for: coreMLModel)
                self.visionRequest = VNCoreMLRequest(model: vnModel) { [weak self] request, error in
                    self?.handleVisionResults(request: request, error: error)
                }
                self.visionRequest?.imageCropAndScaleOption = .scaleFill
                self.modelLoaded = true
                print("[CameraManager] ✅ Vision model loaded and ready")
            } catch {
                print("[CameraManager] ❌ Model load error: \(error)")
            }
        }
    }

    func startSession() {
        sessionQueue.async {
            guard !self.session.isRunning else { return }
            self.session.startRunning()
            print("[CameraManager] ▶️ Session started")
        }
    }

    func stopSession() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            print("[CameraManager] ⏹ Session stopped")
        }
    }

    private func handleVisionResults(request: VNRequest, error: Error?) {
        if let error = error {
            print("[CameraManager] Vision error: \(error)")
            return
        }
        guard let results = request.results as? [VNRecognizedObjectObservation] else {
            print("[CameraManager] No recognized objects")
            return
        }

        var newDetections: [Detection] = []
        for obs in results {
            guard let best = obs.labels.first else { continue }
            let rect = CGRect(
                x: obs.boundingBox.origin.x,
                y: 1 - obs.boundingBox.origin.y - obs.boundingBox.height,
                width: obs.boundingBox.width,
                height: obs.boundingBox.height
            )
            newDetections.append(
                Detection(label: best.identifier,
                          confidence: best.confidence,
                          boundingBox: rect)
            )
        }

        DispatchQueue.main.async {
            self.yoloDetections = newDetections
            print("[CameraManager] 🧠 \(newDetections.count) detections")
        }
    }
}

// MARK: - AVCapture Delegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let request = self.visionRequest,
              modelLoaded else { return }

        let now = CACurrentMediaTime()
        if now - lastInferenceTime < minInferenceInterval { return }
        lastInferenceTime = now

        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up)
        do {
            try handler.perform([request])
        } catch {
            print("[CameraManager] VN handler error: \(error)")
        }
    }
}
