import Foundation
import AVFoundation
import SwiftUI

class CameraManager: ObservableObject {
    @Published var status: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.status = AVCaptureDevice.authorizationStatus(for: .video)
            }
        }
    }
}
