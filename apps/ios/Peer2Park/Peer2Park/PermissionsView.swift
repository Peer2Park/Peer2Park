import SwiftUI

struct PermissionsView: View {
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var locationManager: LocationManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image("peer2park")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 160, height: 160)
                .cornerRadius(20)

            Text("Welcome to Peer2Park")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .padding(.bottom, 10)

            Text("To get started, allow location and camera access.")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundColor(.gray)

            VStack(spacing: 16) {
                Button("Request Location Access") {
                    locationManager.requestPermission()
                }
                .buttonStyle(.borderedProminent)

                Button("Request Camera Access") {
                    cameraManager.requestPermission()
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Text("You can manage permissions anytime in Settings.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}
