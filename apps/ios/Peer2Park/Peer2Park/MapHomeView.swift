//
//  MapHomeView.swift
//  Peer2Park
//
//  Created by Trent S on 11/1/25.
//

import Foundation
import SwiftUI
import MapKit
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

struct MapHomeView: View {
    @ObservedObject var locationManager: LocationManager
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var searchQuery: String = ""
    @State private var selectedDestination: MKMapItem?
    @State private var route: MKRoute?
    @State private var routeError: String?
    @FocusState private var searchFieldFocused: Bool
    @Namespace private var mapScope
    @State private var searchTask: Task<Void, Never>?
    @State private var routeTask: Task<Void, Never>?
    @State private var searchInFlight = false
    @State private var routingInFlight = false
    @State private var currentStepIndex: Int = 0
    @State private var hasArrived: Bool = false
    @State private var navigationStarted: Bool = false

    // New state for reporting spots
    @State private var spotPosting: Bool = false
    @State private var spotMessage: String? = nil
    @State private var showSpotMessage: Bool = false

    private let formatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .medium
        formatter.unitOptions = .naturalScale
        return formatter
    }()

    private var userCoordinate: CLLocationCoordinate2D? {
        locationManager.userLocation
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                mapLayer
                    .overlay(alignment: .center) {
                        if userCoordinate == nil {
                            progressOverlay
                        }
                    }
                    .ignoresSafeArea()

                overlayControls(for: geometry)

                // Centered closable popup for showing POST response
                if showSpotMessage {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(100)

                    spotPopup
                        .zIndex(101)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .onAppear {
#if canImport(UIKit)
            OrientationLock.lock(.landscape)
#endif
            if let coordinate = userCoordinate {
                recenterCamera(on: coordinate)
            }
        }
        .onReceive(locationManager.$userLocation.compactMap { $0 }) { newCoord in
            let span = route == nil
                ? MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                : MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)
            withAnimation(.easeInOut(duration: 0.45)) {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: newCoord,
                        span: span
                    )
                )
            }
            if route != nil, navigationStarted {
                updateNavigationProgress(for: newCoord)
            }
        }
        .onChange(of: searchQuery) { newValue in
            if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                routeError = nil
            }
        }
        .onDisappear {
#if canImport(UIKit)
            OrientationLock.unlock()
#endif
            searchTask?.cancel()
            routeTask?.cancel()
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: route)
    }

    // MARK: - Map Layer
    private var mapLayer: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $cameraPosition, scope: mapScope) {
                // User location “blue dot”
                UserAnnotation()

                // Route polyline
                if let route {
                    MapPolyline(route.polyline)
                        .stroke(.blue.gradient, lineWidth: 8)
                        .mapOverlayLevel(level: .aboveRoads)
                }

                // Destination pin
                if let destination = selectedDestination?.placemark.coordinate {
                    Annotation("Destination", coordinate: destination) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.gradient)
                                .frame(width: 32, height: 32)
                            Image(systemName: "flag.checkered")
                                .foregroundStyle(.white)
                                .font(.system(size: 16, weight: .bold))
                        }
                        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 4)
                    }
                }
            }
            // Floating report button
            Button(action: {
                guard let coord = userCoordinate else {
                    spotMessage = "Unable to determine your location"
                    showSpotMessage = true
                    return
                }

                spotPosting = true
                Task {
                    await sendSpot(coord)
                    spotPosting = false
                }
            }) {
                if spotPosting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(width: 56, height: 56)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 4)
                }
            }
            .padding(16)
            .accessibilityLabel("Report a parking spot at your current location")

        }
        .mapStyle(.standard(elevation: .realistic))
        .mapScope(mapScope)
        .mapControls {
            MapUserLocationButton(scope: mapScope)
            MapCompass(scope: mapScope)
            MapPitchToggle(scope: mapScope)
            MapScaleView(scope: mapScope)
        }
    }

    private var progressOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Locating you...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Overlay Controls
    @ViewBuilder
    private func overlayControls(for geometry: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            topOverlay(for: geometry)

            if let routeError {
                Text(routeError)
                    .font(.footnote)
                    .foregroundColor(.orange)
                    .transition(.opacity)
            }

            Spacer()

            bottomOverlay(for: geometry)
        }
        .padding(.horizontal, 24)
        .padding(.top, geometry.safeAreaInsets.top + 2)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func topOverlay(for geometry: GeometryProxy) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                searchStrip(for: geometry)
                Spacer(minLength: 0)
            }

            if routingInFlight {
                routingStatusBadge
            }

            if navigationStarted, let route {
                navigationHeader(for: route)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private func bottomOverlay(for geometry: GeometryProxy) -> some View {
        Group {
            if let route {
                if navigationStarted {
                    turnByTurnCard(for: route, width: geometry.size.width)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    routePreviewSheet(for: route, width: geometry.size.width)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 8)
    }

    // MARK: - Search Strip
    private func searchStrip(for geometry: GeometryProxy) -> some View {
        HStack(alignment: .center, spacing: 16) {
            searchField(width: searchFieldWidth(for: geometry.size.width))
                .animation(.easeInOut(duration: 0.2), value: searchFieldFocused)
                .animation(.easeInOut(duration: 0.2), value: searchQuery)
        }
    }

    private func searchField(width: CGFloat) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search destinations", text: $searchQuery)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($searchFieldFocused)
                .submitLabel(.search)
                .onSubmit { triggerSearch() }
            if searchInFlight {
                ProgressView()
                    .controlSize(.small)
            }
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    routeError = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search text")
            }

            Button(action: triggerSearch) {
                Image(systemName: "arrow.forward.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.tint)
            }
            .disabled(searchQuery.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel("Search for destination")
        }
        .padding(.horizontal, isSearchCollapsed ? 12 : 14)
        .padding(.vertical, isSearchCollapsed ? 8 : 10)
        .frame(width: width)
        .background(.regularMaterial, in: Capsule(style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 6)
    }

    private func searchFieldWidth(for totalWidth: CGFloat) -> CGFloat {
        let maxWidth = min(440, totalWidth * 0.48)
        let collapsedWidth = min(220, totalWidth * 0.26)
        return (searchFieldFocused || !searchQuery.isEmpty) ? maxWidth : collapsedWidth
    }

    private var isSearchCollapsed: Bool {
        route == nil && searchQuery.isEmpty && !searchFieldFocused
    }

    private var routingStatusBadge: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Building route...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func navigationHeader(for route: MKRoute) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(formattedTravelTime(route.expectedTravelTime))
                    .font(.headline)
                Text("Arrive by \(formattedArrivalTime(route.expectedTravelTime))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .frame(height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(formattedDistance(route.distance))
                    .font(.headline)
                Text(selectedDestination?.name ?? "Destination")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: clearRoute) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .padding(10)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("End navigation")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule(style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }

    // MARK: - Helpers
    private func filteredSteps(_ steps: [MKRoute.Step]) -> [MKRoute.Step] {
        steps.filter { $0.distance > 0 }
    }

    private func formattedDistance(_ distance: CLLocationDistance) -> String {
        let measurement = Measurement(value: distance, unit: UnitLength.meters)
        return formatter.string(from: measurement)
    }

    private func formattedTravelTime(_ time: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        return formatter.string(from: time) ?? "--"
    }

    private func triggerSearch() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return
        }
        searchTask?.cancel()
        searchTask = Task { [trimmed] in
            await performSearch(for: trimmed)
            await MainActor.run { searchTask = nil }
        }
    }

    @MainActor
    private func performSearch(for query: String) async {
        guard let userCoordinate else {
            routeError = "Waiting for your current location"
            return
        }

        searchInFlight = true
        defer { searchInFlight = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: userCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )

        do {
            let response = try await MKLocalSearch(request: request).start()
            guard !Task.isCancelled else { return }
            routeError = nil
            if let destination = bestDestination(from: response.mapItems, relativeTo: userCoordinate) {
                selectDestination(destination)
            } else {
                routeError = "No parking found near you"
            }
        } catch is CancellationError {
            return
        } catch {
            routeError = "Search failed: \(error.localizedDescription)"
        }
    }

    private func selectDestination(_ item: MKMapItem) {
        selectedDestination = item
        searchQuery = item.name ?? item.placemark.name ?? searchQuery
        searchFieldFocused = false
        routeTask?.cancel()
        routeTask = Task {
            await calculateRoute(to: item)
            await MainActor.run { routeTask = nil }
        }
    }

    @MainActor
    private func calculateRoute(to destination: MKMapItem) async {
        guard let userCoordinate else {
            routeError = "Waiting for your current location"
            return
        }

        routingInFlight = true
        defer { routingInFlight = false }

        let sourcePlacemark = MKPlacemark(coordinate: userCoordinate)
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = destination
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        do {
            let response = try await MKDirections(request: request).calculate()
            guard !Task.isCancelled else { return }
            if let calculatedRoute = response.routes.first {
                routeError = nil
                route = calculatedRoute
                resetNavigationState()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                    cameraPosition = .rect(calculatedRoute.polyline.boundingMapRect.padded(by: 1200))
                }
            } else {
                routeError = "No routes available"
                route = nil
            }
        } catch is CancellationError {
            return
        } catch {
            routeError = "Navigation unavailable: \(error.localizedDescription)"
            route = nil
        }
    }

    private func clearRoute() {
        routeTask?.cancel()
        route = nil
        selectedDestination = nil
        routeError = nil
        resetNavigationState()
        if let coordinate = userCoordinate {
            recenterCamera(on: coordinate)
        }
    }

    private func recenterCamera(on coordinate: CLLocationCoordinate2D) {
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )
    }

    private func turnByTurnCard(for route: MKRoute, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if hasArrived {
                Label("You've arrived", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                Text("You're at \(selectedDestination?.name ?? "your destination").")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let context = currentNavigationContext(for: route) {
                Text(context.instructions)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("In \(formattedDistance(context.remainingDistance))")
                    .font(.headline)
                Text("Step \(context.index + 1) of \(context.total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Preparing guidance...")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(20)
        .frame(maxWidth: min(520, width - 40), alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
    }

    private func currentNavigationContext(for route: MKRoute) -> (instructions: String, remainingDistance: CLLocationDistance, index: Int, total: Int)? {
        let steps = filteredSteps(route.steps)
        guard !steps.isEmpty else { return nil }
        let index = min(currentStepIndex, steps.count - 1)
        let step = steps[index]
        let instructions = step.instructions.isEmpty ? "Continue straight" : step.instructions
        let remainingDistance = distanceToEnd(of: step)
        return (instructions, remainingDistance, index, steps.count)
    }

    private func updateNavigationProgress(for coordinate: CLLocationCoordinate2D) {
        guard let route, navigationStarted, !hasArrived else { return }
        let steps = filteredSteps(route.steps)
        guard !steps.isEmpty else { return }
        let index = min(currentStepIndex, steps.count - 1)
        let step = steps[index]
        guard let target = endCoordinate(for: step) else { return }
        let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let targetLocation = CLLocation(latitude: target.latitude, longitude: target.longitude)
        let distance = userLocation.distance(from: targetLocation)
        if distance < 18 {
            if index >= steps.count - 1 {
                hasArrived = true
            } else {
                currentStepIndex = index + 1
            }
        }
    }

    private func distanceToEnd(of step: MKRoute.Step) -> CLLocationDistance {
        guard let userCoordinate = userCoordinate else {
            return step.distance
        }
        guard let target = endCoordinate(for: step) else {
            return step.distance
        }
        let userLocation = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)
        let targetLocation = CLLocation(latitude: target.latitude, longitude: target.longitude)
        return max(userLocation.distance(from: targetLocation), 0)
    }

    private func endCoordinate(for step: MKRoute.Step) -> CLLocationCoordinate2D? {
        guard step.polyline.pointCount > 0 else { return nil }
        let lastPoint = step.polyline.points()[step.polyline.pointCount - 1]
        return lastPoint.coordinate
    }

    private func bestDestination(from items: [MKMapItem], relativeTo origin: CLLocationCoordinate2D) -> MKMapItem? {
        guard !items.isEmpty else { return nil }
        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        return items.min { lhs, rhs in
            let lhsLocation = CLLocation(latitude: lhs.placemark.coordinate.latitude, longitude: lhs.placemark.coordinate.longitude)
            let rhsLocation = CLLocation(latitude: rhs.placemark.coordinate.latitude, longitude: rhs.placemark.coordinate.longitude)
            return lhsLocation.distance(from: originLocation) < rhsLocation.distance(from: originLocation)
        }
    }

    private func resetNavigationState() {
        currentStepIndex = 0
        hasArrived = false
        navigationStarted = false
    }

    private func startNavigation() {
        guard route != nil else { return }
        currentStepIndex = 0
        hasArrived = false
        navigationStarted = true
        if let coordinate = userCoordinate {
            recenterCamera(on: coordinate)
        }
    }

    private func routePreviewSheet(for route: MKRoute, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(formattedTravelTime(route.expectedTravelTime))
                    .font(.largeTitle.weight(.semibold))
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formattedDistance(route.distance))
                        .font(.headline)
                    Text("Best route")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(selectedDestination?.name ?? selectedDestination?.placemark.name ?? "Destination")
                    .font(.title3.weight(.semibold))
                if !route.name.isEmpty {
                    Text("via \(route.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                Button(action: startNavigation) {
                    Text("Start")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor, in: Capsule())
                }

                Button(action: clearRoute) {
                    Text("Cancel")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.thinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(maxWidth: min(520, width - 40), alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 12)
    }

    private func formattedArrivalTime(_ travelTime: TimeInterval) -> String {
        let arrival = Date().addingTimeInterval(travelTime)
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: arrival)
    }

    // MARK: - Spot reporting

    @MainActor
    private func sendSpot(_ coordinate: CLLocationCoordinate2D) async {
        let urlString = "https://n7nrhon2c5.execute-api.us-east-2.amazonaws.com/dev/spots"
        guard let url = URL(string: urlString) else {
            spotMessage = "Invalid request URL"
            showSpotMessage = true
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Double] = ["latitude": coordinate.latitude, "longitude": coordinate.longitude]

        do {
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)
            var statusCode: Int? = nil
            if let http = response as? HTTPURLResponse {
                statusCode = http.statusCode
            }

            // Try to decode and pretty-print JSON response, otherwise fall back to raw text
            var responseText: String = ""
            if let jsonObj = try? JSONSerialization.jsonObject(with: data, options: []) {
                if JSONSerialization.isValidJSONObject(jsonObj),
                   let pretty = try? JSONSerialization.data(withJSONObject: jsonObj, options: [.prettyPrinted]),
                   let prettyString = String(data: pretty, encoding: .utf8) {
                    responseText = prettyString
                } else if let raw = String(data: data, encoding: .utf8) {
                    responseText = raw
                }
            } else if let raw = String(data: data, encoding: .utf8) {
                responseText = raw
            } else {
                responseText = "(no response body)"
            }

            if let code = statusCode, (200...299).contains(code) {
                spotMessage = "Status: \(code)\n\n\(responseText)"
            } else if let code = statusCode {
                spotMessage = "Status: \(code)\n\n\(responseText)"
            } else {
                spotMessage = responseText
            }

        } catch {
            spotMessage = "Network error: \(error.localizedDescription)"
        }

        showSpotMessage = true
    }

    private var spotPopup: some View {
        VStack(spacing: 16) {
            Text(spotMessage ?? "Unknown error")
                .font(.headline)
                .multilineTextAlignment(.center)

            Button(action: {
                showSpotMessage = false
            }) {
                Text("Close")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: Capsule())
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .frame(maxWidth: 400)
    }
}

private extension MKMapRect {
    func padded(by amount: Double) -> MKMapRect {
        MKMapRect(
            x: origin.x - amount,
            y: origin.y - amount,
            width: size.width + (amount * 2),
            height: size.height + (amount * 2)
        )
    }
}

#if canImport(UIKit)
enum OrientationLock {
    static func lock(_ mask: UIInterfaceOrientationMask) {
        updateOrientation(mask)
    }

    static func unlock() {
        updateOrientation(.allButUpsideDown)
    }

    private static func updateOrientation(_ mask: UIInterfaceOrientationMask) {
        guard
            let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first
        else { return }

        let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)
        do {
            try windowScene.requestGeometryUpdate(preferences)
        } catch {
            print("Failed to update orientation: \(error.localizedDescription)")
        }
    }
}
#endif
