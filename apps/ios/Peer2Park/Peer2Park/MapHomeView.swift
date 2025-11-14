//
//  MapHomeView.swift
//  Peer2Park
//
//  Created by Trent S on 11/1/25.
//

import SwiftUI
import MapKit
import Foundation

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

    private let formatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .medium
        formatter.unitOptions = .naturalScale
        return formatter
    }()

    private var userCoordinate: CLLocationCoordinate2D? {
        locationManager.userLocation
    }

    private var isWorking: Bool { searchInFlight || routingInFlight }

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

                controlPanel(for: geometry)
            }
        }
        .onAppear {
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
            searchTask?.cancel()
            routeTask?.cancel()
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: route)
        .animation(.easeInOut(duration: 0.25), value: searchResults)
    }

    // MARK: - Map Layer

    private var mapLayer: some View {
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

    // MARK: - Control Panel

    @ViewBuilder
    private func controlPanel(for geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            statusHeader
            destinationField

            if isWorking {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Working on it...")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            if !searchResults.isEmpty {
                searchResultsList
            }

            if let route {
                routeSummary(route)
            } else {
                helperText
            }

            if let routeError {
                Text(routeError)
                    .font(.footnote)
                    .foregroundColor(.orange)
                    .transition(.opacity)
            }
        }
        .padding(20)
        .frame(
            width: min(440, geometry.size.width * 0.42),
            alignment: .leading
        )
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
        .padding(.horizontal, 28)
        .padding(.top, 32)
    }

    private var statusHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Navigate to parking")
                    .font(.title3.weight(.semibold))
                Text("Search for a destination and we’ll guide you while the dashcam looks for open spots along the way.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if route != nil {
                Button(role: .destructive) {
                    clearRoute()
                } label: {
                    Label("Clear", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Clear active route")
            }
        }
    }

    private var destinationField: some View {
        HStack(spacing: 12) {
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
                .accessibilityLabel("Clear search text")
            }

            Button(action: triggerSearch) {
                Image(systemName: "arrow.forward.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.tint)
            }
            .disabled(searchQuery.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel("Search for destination")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: Capsule(style: .continuous))
    }

    private var helperText: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("No active route", systemImage: "map")
                .font(.headline)
            Text("Use the search bar above to choose where you want to drive. We’ll pan the map, highlight the route, and keep the dashcam detecting spots along the way.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var searchResultsList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(Array(searchResults.enumerated()), id: \.offset) { index, item in
                    Button {
                        selectDestination(item)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name ?? "Unnamed location")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                            if let subtitle = subtitle(for: item) {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(index % 2 == 0
                                      ? Color(.secondarySystemBackground)
                                      : Color(.systemBackground))
                                .opacity(0.8)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxHeight: 220)
    }

    private func routeSummary(_ route: MKRoute) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimated drive")
                        .font(.headline)
                    HStack(spacing: 12) {
                        Label(formattedDistance(route.distance), systemImage: "road.lanes")
                        Label(formattedTravelTime(route.expectedTravelTime), systemImage: "clock")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if let destinationName = selectedDestination?.name ?? selectedDestination?.placemark.name {
                    Text(destinationName)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    let steps = filteredSteps(route.steps)
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(index == 0 ? Color.green : Color.accentColor)
                                .frame(width: 10, height: 10)
                                .padding(.top, 6)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(step.instructions.isEmpty ? "Continue" : step.instructions)
                                    .font(.subheadline)
                                Text(formattedDistance(step.distance))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 250)
        }
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
        routeTask = Task { [weak weakDest = item] in
            guard let destination = weakDest else { return }
            await calculateRoute(to: destination)
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
}

// MARK: - MapRect Padding

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
