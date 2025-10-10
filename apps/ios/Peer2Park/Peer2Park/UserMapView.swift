import SwiftUI
import MapKit

struct UserCoordinate: Identifiable, Equatable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    static func == (lhs: UserCoordinate, rhs: UserCoordinate) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

struct UserMapView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    var userCoordinate: UserCoordinate? {
        locationManager.userLocation.map { UserCoordinate(coordinate: $0) }
    }
    
    var body: some View {
        ZStack {
            if let userCoord = userCoordinate {
                Map(
                    position: $cameraPosition
                ) {
                    Marker("You", systemImage: "location.fill", coordinate: userCoord.coordinate)
                        .tint(.blue)
                }
                .edgesIgnoringSafeArea(.all)
                .onChange(of: userCoordinate) { oldValue, newValue in
                    if let newCoord = newValue {
                        cameraPosition = .region(MKCoordinateRegion(
                            center: newCoord.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))
                    }
                }
            } else {
                VStack {
                    Spacer()
                    Text(locationManager.status == .denied ? "Location permission denied." : "Locating...")
                        .foregroundColor(.gray)
                        .padding()
                    Spacer()
                }
            }
        }
        .onAppear {
            locationManager.requestPermission()
        }
    }
}
