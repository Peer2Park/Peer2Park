//
//  MapHomeView.swift
//  Peer2Park
//
//  Created by Trent S on 11/1/25.
//

import Foundation
import SwiftUI
import MapKit
#if canImport(UIKit)
import UIKit
#endif

struct MapHomeView: View {
    @ObservedObject var locationManager: LocationManager
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var searchQuery: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedDestination: MKMapItem?
    @State private var route: MKRoute?
    @State private var routeError: String?
    @FocusState private var searchFieldFocused: Bool
    @Namespace private var mapScope
    @State private var searchTask: Task<Void, Never>?
    @State private var routeTask: Task<Void, Never>?
    @State private var searchInFlight = false
    @State private var routingInFlight = false

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
            guard route == nil else { return }
            withAnimation(.easeInOut(duration: 0.45)) {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: newCoord,
                        span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                    )
                )
            }
        }
        .onChange(of: searchQuery) { newValue in
            if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                searchResults.removeAll()
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
        .animation(.easeInOut(duration: 0.25), value: searchResults)
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
        VStack(spacing: 0) {
            topOverlay(for: geometry)

            if let routeError {
                Text(routeError)
                    .font(.footnote)
                    .foregroundColor(.orange)
                    .padding(.top, 6)
                    .transition(.opacity)
            }

            Spacer()

            bottomOverlay(for: geometry)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func topOverlay(for geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Group {
                if let route {
                    routeControlStrip(route, width: geometry.size.width)
                } else {
                    searchStrip(for: geometry)
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func bottomOverlay(for geometry: GeometryProxy) -> some View {
        Group {
            if let route {
                directionsPanel(for: route, in: geometry)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                helperBadge
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.bottom, 8)
    }

    // MARK: - Search Strip
    private func searchStrip(for geometry: GeometryProxy) -> some View {
        HStack(alignment: .top, spacing: 16) {
            searchField(width: searchFieldWidth(for: geometry.size.width))
                .animation(.easeInOut(duration: 0.2), value: searchFieldFocused)
                .animation(.easeInOut(duration: 0.2), value: searchQuery)

            if shouldShowResultsPanel {
                searchResultsPanel
                    .frame(
                        width: min(340, geometry.size.width * 0.3),
                        height: min(320, geometry.size.height * 0.55)
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            if routingInFlight {
                routingStatusBadge
            }
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
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    searchResults.removeAll()
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

    private var shouldShowResultsPanel: Bool {
        route == nil && (!searchResults.isEmpty || searchInFlight)
    }

    private var isSearchCollapsed: Bool {
        route == nil && searchQuery.isEmpty && !searchFieldFocused
    }

    private var searchResultsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(searchInFlight ? "Searching..." : "Results")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if searchInFlight {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if searchResults.isEmpty {
                Text("Keep typing to see matches near you.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(Array(searchResults.enumerated()), id: \.offset) { index, item in
                            Button {
                                selectDestination(item)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name ?? "Unnamed location")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    if let subtitle = subtitle(for: item) {
                                        Text(subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(index % 2 == 0 ? Color(.secondarySystemBackground) : Color(.systemBackground))
                            )
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
    }

    // MARK: - Route Controls
    private func routeControlStrip(_ route: MKRoute, width: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Button(role: .cancel) {
                clearRoute()
            } label: {
                Label("Cancel", systemImage: "xmark")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)

            routeAtAGlance(route)
                .frame(maxWidth: min(420, width * 0.45))

            if routingInFlight {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 18)
    }

    private func routeAtAGlance(_ route: MKRoute) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedDestination?.name ?? selectedDestination?.placemark.name ?? "On the way")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 16) {
                    Label(formattedDistance(route.distance), systemImage: "road.lanes")
                    Label(formattedTravelTime(route.expectedTravelTime), systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.forward")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
    }

    private var helperBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "map")
                .font(.headline)
            VStack(alignment: .leading, spacing: 2) {
                Text("Navigate to parking")
                    .font(.subheadline.weight(.semibold))
                Text("Search above to plot your route while the dashcam keeps scanning.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .frame(maxWidth: 360, alignment: .leading)
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

    // MARK: - Directions Panel
    private func directionsPanel(for route: MKRoute, in geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Turn-by-turn")
                .font(.subheadline.weight(.semibold))
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(filteredSteps(route.steps).enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption2.weight(.bold))
                                .frame(width: 24, height: 24)
                                .background(index == 0 ? Color.green.opacity(0.8) : Color.accentColor.opacity(0.8))
                                .clipShape(Circle())
                                .foregroundStyle(.white)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(step.instructions.isEmpty ? "Continue" : step.instructions)
                                    .font(.footnote)
                                Text(formattedDistance(step.distance))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Divider()
                    }
                }
            }
            .frame(height: min(200, geometry.size.height * 0.32))
        }
        .padding(16)
        .frame(maxWidth: min(360, geometry.size.width * 0.32))
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 14, y: 8)
        .padding(.horizontal, 8)
    }

    // MARK: - Helpers
    private func subtitle(for item: MKMapItem) -> String? {
        if let subtitle = item.placemark.title {
            return subtitle
        }
        var components: [String] = []
        if let locality = item.placemark.locality {
            components.append(locality)
        }
        if let state = item.placemark.administrativeArea {
            components.append(state)
        }
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }

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
            searchResults.removeAll()
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
            searchResults = response.mapItems
            routeError = nil
        } catch is CancellationError {
            return
        } catch {
            routeError = error.localizedDescription
            searchResults = []
        }
    }

    private func selectDestination(_ item: MKMapItem) {
        selectedDestination = item
        searchQuery = item.name ?? item.placemark.name ?? searchQuery
        searchResults.removeAll()
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
