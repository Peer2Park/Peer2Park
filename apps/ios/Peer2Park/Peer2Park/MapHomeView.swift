//
//  MapHomeView.swift
//  Peer2Park
//
//  Created by Trent S on 11/1/25.
//

import Foundation
import SwiftUI
import MapKit
import Speech
import AVFoundation
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
    @State private var voiceError: String?
    @State private var isNavigating = false
    @State private var currentStepIndex = 0
    @State private var voiceGuidanceMuted = false

    @State private var useSatelliteStyle = false

    @FocusState private var searchFieldFocused: Bool

    // Voice recognition helper
    @StateObject private var speechRecognizer = SpeechRecognizer()

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
    
    private let arrivalFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df
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
            .mapStyle(useSatelliteStyle ? .hybrid(elevation: .realistic) : .standard(elevation: .realistic))
            .mapScope(mapScope)
            .mapControls {
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
        if isNavigating {
                navigationChrome(for: geometry)
            } else {
                nonNavigationChrome(for: geometry)
            }
        }
    private func nonNavigationChrome(for geometry: GeometryProxy) -> some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                portraitSearchChrome(for: geometry)
                Spacer(minLength: 0)
                // only display when we have a route
                if route != nil {
                    bottomSheet(for: geometry)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    floatingControls
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, geometry.safeAreaInsets.bottom + 32)

        }
    }
    private func navigationChrome(for geometry: GeometryProxy) -> some View {
           ZStack(alignment: .topLeading) {
               VStack(spacing: 0) {
                   navigationInstructionBanner
                       .padding(.horizontal, 16)
                       .padding(.top, geometry.safeAreaInsets.top + 6)

                   Spacer(minLength: 0)

                   navigationBottomPanel
                       .padding(.horizontal, 16)
                       .padding(.bottom, geometry.safeAreaInsets.bottom + 12)
               }
               .frame(maxWidth: .infinity, maxHeight: .infinity)

               VStack {
                   Spacer()
                   HStack {
                       Spacer()
                       navigationFloatingControls
                   }
               }
               .padding(.trailing, 16)
               .padding(.bottom, geometry.safeAreaInsets.bottom + 32)
           }
       }
    private var navigationInstructionBanner: some View {
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(navigationDestinationLabel)
                        .font(.footnote.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)

                    Text(navigationPrimaryInstruction)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if let distance = navigationInstructionDistance {
                        Text(distance)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 58, height: 58)
                            .shadow(color: .black.opacity(0.2), radius: 10, y: 5)

                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Button(action: { voiceGuidanceMuted.toggle() }) {
                        Image(systemName: voiceGuidanceMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 52, height: 52)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(voiceGuidanceMuted ? "Unmute voice directions" : "Mute voice directions")
                }
            }
            .padding(22)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32))
            .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
        }

        private var navigationBottomPanel: some View {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(navigationETAString)
                        .font(.headline)

                    if let arrival = navigationArrivalString {
                        Text("Arrive around \(arrival)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button(action: endNavigation) {
                    Label("End", systemImage: "xmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 22))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
            .padding(22)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32))
            .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
        }

        private var navigationFloatingControls: some View {
            VStack(spacing: 12) {
                floatingCircleButton(systemName: "location.viewfinder") {
                    if let coord = userCoordinate {
                        recenterCamera(on: coord)
                    }
                }

                floatingCircleButton(systemName: useSatelliteStyle ? "globe.americas.fill" : "globe.americas") {
                    useSatelliteStyle.toggle()
                }
            }
        }

        private var navigationDestinationLabel: String {
            selectedDestination?.name ?? selectedDestination?.placemark.name ?? "On the way"
        }

        private var navigationPrimaryInstruction: String {
            guard let step = currentStep else {
                return "Head to start"
            }
            let trimmed = step.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Continue straight" : trimmed
        }

        private var navigationInstructionDistance: String? {
            guard let step = currentStep, step.distance > 0 else { return nil }
            return formattedDistance(step.distance)
        }

        private var navigationETAString: String {
            guard let route else { return "Calculating..." }
            let duration = formattedTravelTime(route.expectedTravelTime)
            let distance = formattedDistance(route.distance)
            return "\(duration) • \(distance)"
        }

        private var navigationArrivalString: String? {
            guard let route else { return nil }
            let arrivalDate = Date().addingTimeInterval(route.expectedTravelTime)
            return arrivalFormatter.string(from: arrivalDate)
        }

        private var currentStep: MKRoute.Step? {
            guard let route else { return nil }
            let steps = filteredSteps(route.steps)
            guard !steps.isEmpty else { return nil }
            let index = min(currentStepIndex, steps.count - 1)
            return steps[index]
        }
    private func portraitSearchChrome(for geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            searchField()
                .animation(.easeInOut(duration: 0.2), value: searchFieldFocused)
                .animation(.easeInOut(duration: 0.2), value: searchQuery)

            if let routeError {
                Text(routeError)
                    .font(.footnote)
                    .foregroundColor(.orange)
                    .transition(.opacity)
            }

            if let voiceError {
                Text(voiceError)
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
        .padding(.top, geometry.safeAreaInsets.top + 4)
    }

    // MARK: - Search + Filters

    private func searchField() -> some View {
        HStack(spacing: 12) {
            Menu {
                // placeholder menu
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search here", text: $searchQuery)
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
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }

                Divider()
                    .frame(height: 20)

                // Voice search button: tap to start/stop live recognition
                Button {
                    if speechRecognizer.isRecording {
                        // stop and use final transcript
                        speechRecognizer.stop()
                        searchQuery = speechRecognizer.transcript
                        triggerSearch()
                    } else {
                        Task {
                            voiceError = nil
                            let allowed = await speechRecognizer.requestAuthorization()
                            if allowed {
                                do {
                                    try speechRecognizer.start()
                                } catch {
                                    // If starting fails, show a more informative error to the user
                                    voiceError = "Voice recognition is not available on this device or is currently unavailable. Please check your microphone, ensure no other app is using it, and try again. (Error: \(error.localizedDescription))"
                                }
                            } else {
                                voiceError = "Speech recognition permission denied"
                            }
                        }
                    }
                } label: {
                    Image(systemName: speechRecognizer.isRecording ? "mic.circle.fill" : "mic.fill")
                        .foregroundStyle(speechRecognizer.isRecording ? .red : .secondary)
                        .accessibilityLabel(speechRecognizer.isRecording ? "Stop voice search" : "Start voice search")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.14), radius: 10, y: 6)

            Button {
                // Placeholder profile
            } label: {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(.secondary)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var shouldShowResultsPanel: Bool {
        route == nil && (!searchResults.isEmpty || searchInFlight)
    }

  
    private var floatingControls: some View {
        VStack(spacing: 12) {
            floatingCircleButton(systemName: "location.fill") {
                if let c = userCoordinate {
                    recenterCamera(on: c)
                }
            }

            floatingCircleButton(systemName: useSatelliteStyle ? "globe.americas.fill" : "globe.americas") {
                useSatelliteStyle.toggle()
            }
        }
    }

    private func floatingCircleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
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
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32))
        .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
        .padding(.horizontal, 16)
        .padding(.bottom, geometry.safeAreaInsets.bottom + 8)
    }

   
    private func routeSheet(for route: MKRoute, geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: startNavigation) {
                            Label("Start navigation", systemImage: "play.circle.fill")
                                .font(.headline)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 22))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                        }
            
            routeAtAGlance(route)
            Divider()
            directionsList(for: route, geometry: geometry)

            Button(role: .cancel) {
                clearRoute()
            } label: {
                Label("Clear Route", systemImage: "xmark.circle")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.12))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
    }
    private func startNavigation() {
           guard route != nil else { return }
           currentStepIndex = 0
           voiceGuidanceMuted = false
           withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
               isNavigating = true
           }
           if let coord = userCoordinate {
               recenterCamera(on: coord)
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
            routeError = "Search failed: \(error.localizedDescription)"
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
        searchResults = []
        routeError = nil
        buildRoute(for: item)
    }

    private func buildRoute(for item: MKMapItem) {
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
        currentStepIndex = 0
        isNavigating = false
    }

    private func endNavigation() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            isNavigating = false
        }
        clearRoute()
    }

    

    // MARK: - Send Spot

    private func sendSpot(_ coordinate: CLLocationCoordinate2D) async {
        struct SpotObservation: Codable {
            let latitude: Double
            let longitude: Double
        }

        do {
            // 💡 Plug in your real API URL here:
            let url = URL(string: "https://n7nrhon2c5.execute-api.us-east-2.amazonaws.com/dev/spots")!
            
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // Encode body using Codable (matches OpenAPI spec exactly)
            let body = SpotObservation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            req.httpBody = try JSONEncoder().encode(body)

            let (_, response) = try await URLSession.shared.data(for: req)

            if let http = response as? HTTPURLResponse {
                switch http.statusCode {
                case 200:
                    spotMessage = "Spot reported!"
                case 400:
                    spotMessage = "Invalid location coordinates provided."
                case 409:
                    spotMessage = "Spot already exists."
                default:
                    spotMessage = "Server error: \(http.statusCode)"
                }
            } else {
                spotMessage = "Unexpected response."
            }

        } catch {
            spotMessage = "Network error."
        }

        // UI message animation (unchanged)
        withAnimation { showSpotMessage = true }
        try? await Task.sleep(for: .seconds(2.2))
        withAnimation { showSpotMessage = false }
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



// MARK: - MKMapRect padding extension

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
        // Request geometry update. On iOS 16.0/16.1 this can throw, so we use try/catch for backward compatibility.
        do {
            try windowScene.requestGeometryUpdate(preferences)
        } catch {
            // Handle or log the error as needed. For now, we ignore it.
        }
}
#endif

// Custom error types for speech recognition

// Lightweight speech recognizer helper using Apple's Speech framework.
@MainActor
final class SpeechRecognizer: ObservableObject {
    enum SpeechRecognizerError: Error {
        case recognitionRequestFailed
        case recognizerUnavailable
    }
    
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false

    private let speechRecognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    func start() throws {
        transcript = ""

        // Prepare audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { throw SpeechRecognizerError.recognitionRequestFailed }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else {
                inputNode.removeTap(onBus: 0)
                audioEngine.stop()
                return
            }
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isRecording = true

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw SpeechRecognizerError.recognizerUnavailable
        }

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in @MainActor
            guard let self = self else { return }
            if let result = result {
                self.transcript = result.bestTranscription.formattedString
            }

            if error != nil || (result?.isFinal ?? false) {
                self.stop()
            }
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        isRecording = false
    }
}
