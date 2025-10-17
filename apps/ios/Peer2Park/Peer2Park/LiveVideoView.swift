import SwiftUI
import AVFoundation

struct LiveVideoView: View {
    @State private var session = AVCaptureSession()
    @State private var isSessionRunning = false
    @State private var errorMessage: String? = nil
    
    
    // MARK: - Main View Body
    var body: some View {
        ZStack {
            CameraPreview(session: session)
                .edgesIgnoringSafeArea(.all)
            VStack {
                Spacer()
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(10)
                }
            }
        }
        .onAppear(perform: startSession)
        .onDisappear(perform: stopSession)
    }
    // MARK: - Session Management
    private func startSession() {
        guard !isSessionRunning else { return }
        session.beginConfiguration()
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back ) else {
            DispatchQueue.main.async {
                errorMessage = "Camera device not available."
            }
            session.commitConfiguration()
            return
        }
        
        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            DispatchQueue.main.async {
                errorMessage = "Unable to create camera input."
            }
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        session.commitConfiguration()
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            DispatchQueue.main.async {
                isSessionRunning = true
                errorMessage = nil
            }
        }
    }
    
    private func stopSession() {
        guard isSessionRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
            DispatchQueue.main.async {
                isSessionRunning = false
            }
        }
    }
}
