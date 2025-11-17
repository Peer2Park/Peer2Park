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

    @Namespace private var mapScope

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var searchQuery: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedDestination: MKMapItem?
    @State private var route: MKRoute?
    @State private var routeError: String?

    @FocusState private var searchFieldFocused: Bool

    @State private var searchTask: Task<Void, Never>?
    @State private var routeTask: Task<Void, Never>?
    @State private var searchInFlight = false
    @State private var routingInFlight = false

    // Reporting spots
    @State private var spotPosting: Bool = false
    @State private var spotMessage: String? = nil
    @State private var showSpotMessage: Bool = false

    private let formatter: MeasurementFormatter = {
        let f = MeasurementFormatter()
        f.unitStyle = .medium
        f.unitOptions = .naturalScale
        return f
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
            OrientationLock.lock(.portrait)
            #endif

            if let c = userCoordinate {
                recenterCamera(on: c)
            }
        }
        .onReceive(locationManager.$userLocation.compactMap { $0 }) { newCoord in
            guard route == nil else { return }
            withAnimation(.easeInOut(duration: 0.45)) {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: newCoord,
                        span: MKCoordinateSpan(latitudeDelta: 0.012,
                                               longitudeDelta: 0.012)
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
                // User “blue dot”
                UserAnnotation()

                // Route polyline
                if let route {
                    MapPolyline(route.polyline)
                        .stroke(.blue.gradient, lineWidth: 8)
                        .mapOverlayLevel(level: .aboveRoads)
                }

                // Destination pin
                if let dest = selectedDestination?.placemark.coordinate {
                    Annotation("Destination", coordinate: dest) {
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

            // Post spot FAB
            Button(action: {
                guard let coord = userCoordinate else { return }
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
    }

    private var progressOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Locating you...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Overlay Controls

    @ViewBuilder
    private func overlayControls(for geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            portraitSearchChrome(for: geometry)
            Spacer(minLength: 0)
            bottomSheet(for: geometry)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func portraitSearchChrome(for geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            searchField()
                .animation(.easeInOut(duration: 0.2), value: searchFieldFocused)
                .animation(.easeInOut(duration: 0.2), value: searchQuery)

            quickFilterRow

            if let routeError {
                Text(routeError)
                    .font(.footnote)
                    .foregroundColor(.orange)
                    .transition(.opacity)
            }

            if shouldShowResultsPanel {
                searchResultsPanel(maxHeight: min(geometry.size.height * 0.35, 340))
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if routingInFlight {
                routingStatusBadge
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, geometry.safeAreaInsets.top + 12)
    }

    // MARK: - Search + Filters

    private func searchField() -> some View {
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
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 6)
    }

    private var shouldShowResultsPanel: Bool {
        route == nil && (!searchResults.isEmpty || searchInFlight)
    }

    private let quickFilterOptions = [
        "Parking near me",
        "Covered garages",
        "Street parking",
        "EV chargers"
    ]

    private var quickFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(quickFilterOptions, id: \.self) { option in
                    Button {
                        applyQuickSearch(option)
                    } label: {
                        Text(option)
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(.systemBackground).opacity(0.85))
                            .clipShape(Capsule())
                    }
                }

                Button {
                    if let c = userCoordinate {
                        recenterCamera(on: c)
                    }
                } label: {
                    Label("Current location", systemImage: "location.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())
                }
                .disabled(userCoordinate == nil)
            }
            .padding(.horizontal, 2)
        }
    }

    private func searchResultsPanel(maxHeight: CGFloat) -> some View {
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
                    VStack(spacing: 0) {
                        ForEach(Array(searchResults.enumerated()), id: \.offset) { index, item in
                            Button {
                                selectDestination(item)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.red)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.name ?? "Unnamed location")
                                            .font(.subheadline.weight(.semibold))
                                            .lineLimit(1)

                                        if let sub = subtitle(for: item) {
                                            Text(sub)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 8)
                            }
                            .buttonStyle(.plain)

                            if index < searchResults.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxHeight: maxHeight)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
    }

    // MARK: - Bottom Sheet

    @ViewBuilder
    private func bottomSheet(for geometry: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 44, height: 5)

            if let route {
                routeSheet(for: route, geometry: geometry)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                idleSheet
                    .transition(.opacity)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
        .padding(.horizontal, 16)
        .padding(.bottom, geometry.safeAreaInsets.bottom + 8)
    }

    private var idleSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Navigate to parking")
                .font(.headline)

            Text("Search above to plot your route while the dashcam keeps scanning in the background.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                actionPill(
                    title: "Current location",
                    systemImage: "location.fill",
                    disabled: userCoordinate == nil
                ) {
                    if let c = userCoordinate {
                        recenterCamera(on: c)
                    }
                }

                actionPill(
                    title: "Clear search",
                    systemImage: "xmark.circle",
                    tint: .secondary
                ) {
                    searchQuery = ""
                    searchResults.removeAll()
                    routeError = nil
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func routeSheet(for route: MKRoute, geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            routeAtAGlance(route)
            Divider()
            directionsList(for: route, geometry: geometry)

            Button(role: .cancel) {
                clearRoute()
            } label: {
                Label("End navigation", systemImage: "xmark.circle")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.12))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
        }
    }

    private func routeAtAGlance(_ route: MKRoute) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedDestination?.name ??
                     selectedDestination?.placemark.name ??
                     "On the way")
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
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 26))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
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

    private func directionsList(for route: MKRoute, geometry: GeometryProxy) -> some View {
        let steps = filteredSteps(route.steps)
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption2.weight(.bold))
                            .frame(width: 26, height: 26)
                            .background(index == 0 ? Color.green.opacity(0.85)
                                                  : Color.accentColor.opacity(0.85))
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

                    if index < steps.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: min(geometry.size.height * 0.35, 280))
    }

    private func actionPill(
        title: String,
        systemImage: String,
        disabled: Bool = false,
        tint: Color = .accentColor,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(tint.opacity(0.15))
                .foregroundStyle(tint)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
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
        let df = DateComponentsFormatter()
        df.unitsStyle = .abbreviated
        df.allowedUnits = [.hour, .minute]
        return df.string(from: time) ?? "--"
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

    private func applyQuickSearch(_ option: String) {
        searchQuery = option
        searchFieldFocused = false
        triggerSearch()
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
            routeError = "Search error: \(error.localizedDescription)"
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

    private func selectDestination(_ item: MKMapItem) {
        selectedDestination = item
        searchFieldFocused = false
        buildRoute(to: item)
    }

    private func buildRoute(to item: MKMapItem) {
        routingInFlight = true
        routeTask?.cancel()
        routeTask = Task {
            await performRoute(to: item)
            await MainActor.run { routingInFlight = false }
        }
    }

    @MainActor
    private func performRoute(to item: MKMapItem) async {
        guard let userCoordinate else {
            routeError = "Waiting for your location"
            return
        }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userCoordinate))
        request.destination = item
        request.transportType = .automobile

        do {
            let response = try await MKDirections(request: request).calculate()
            guard let first = response.routes.first else {
                routeError = "No routes found"
                return
            }

            route = first

            let padded = first.polyline.boundingMapRect.padded(by: 600)
            cameraPosition = .rect(padded)
        } catch is CancellationError {
            return
        } catch {
            routeError = "Routing failed: \(error.localizedDescription)"
        }
    }

    private func clearRoute() {
        route = nil
        selectedDestination = nil
    }

    // MARK: - Send Spot

    private func sendSpot(_ coordinate: CLLocationCoordinate2D) async {
        do {
            let url = URL(string: "https://peer2park.com/post")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "latitude": coordinate.latitude,
                "longitude": coordinate.longitude
            ]

            req.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (_, response) = try await URLSession.shared.data(for: req)

            if let http = response as? HTTPURLResponse,
               http.statusCode == 200 {
                spotMessage = "Spot reported!"
            } else {
                spotMessage = "Server error reporting spot."
            }
        } catch {
            spotMessage = "Network error reporting spot."
        }

        withAnimation {
            showSpotMessage = true
        }

        try? await Task.sleep(for: .seconds(2.2))

        withAnimation {
            showSpotMessage = false
        }
    }

    private var spotPopup: some View {
        VStack(spacing: 12) {
            Text(spotMessage ?? "Done")
                .font(.headline)
                .foregroundColor(.white)

            Button("OK") {
                withAnimation { showSpotMessage = false }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.accentColor)
            .clipShape(Capsule())
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .frame(maxWidth: 400)
    }
}

// MARK: - MKMapRect padding

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
    static func lock(_ mask: UIInterfaceOrientationMask = .portrait) {
        updateOrientation(mask)
    }

    static func unlock() {
        updateOrientation(.portrait)
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
