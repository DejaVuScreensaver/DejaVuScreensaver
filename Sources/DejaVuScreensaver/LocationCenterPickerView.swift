import SwiftUI

struct LocationCenterPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var coordinate: PhotoCoordinate
    @State private var radiusKilometers: Double
    @State private var distanceUnit: DistanceUnit
    @State private var citySearch = ""
    @State private var selectedCity: String?
    let onSave: (PhotoCoordinate, Double, DistanceUnit) -> Void

    init(
        initialCoordinate: PhotoCoordinate,
        initialRadiusKilometers: Double,
        initialDistanceUnit: DistanceUnit,
        onSave: @escaping (PhotoCoordinate, Double, DistanceUnit) -> Void
    ) {
        _coordinate = State(initialValue: initialCoordinate)
        _radiusKilometers = State(initialValue: initialRadiusKilometers)
        _distanceUnit = State(initialValue: initialDistanceUnit)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Choose Radius Center")
                    .font(.title2.bold())
                Text("Search for a city, move the pin, zoom, or enter coordinates.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                TextField("Search cities", text: $citySearch)
                    .textFieldStyle(.roundedBorder)

                if !cityResults.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(cityResults) { city in
                                Button {
                                    coordinate = city.coordinate
                                    selectedCity = [city.name, city.country]
                                        .compactMap { $0 }
                                        .joined(separator: ", ")
                                    citySearch = ""
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(city.name)
                                                .foregroundStyle(.primary)
                                            Text(city.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.left")
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Divider()
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            CoordinateWorldMap(coordinate: $coordinate, radiusKilometers: radiusKilometers) {
                selectedCity = nil
            }
            .frame(height: 270)

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    LabeledContent("Radius") {
                        TextField(
                            "Radius",
                            value: radiusBinding,
                            format: .number.precision(.fractionLength(0...2))
                        )
                        .frame(width: 110)
                    }
                    Picker("Distance unit", selection: $distanceUnit) {
                        ForEach(DistanceUnit.allCases) { unit in
                            Text(unit.symbol).tag(unit)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 96)
                    Spacer()
                    if let selectedCity {
                        Label(selectedCity, systemImage: "building.2")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 14) {
                    LabeledContent("Latitude") {
                        TextField(
                            "Latitude",
                            value: latitudeBinding,
                            format: .number.precision(.fractionLength(0...6))
                        )
                        .frame(width: 110)
                    }
                    LabeledContent("Longitude") {
                        TextField(
                            "Longitude",
                            value: longitudeBinding,
                            format: .number.precision(.fractionLength(0...6))
                        )
                        .frame(width: 110)
                    }
                    Spacer()
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Use This Area") {
                    onSave(coordinate, radiusKilometers, distanceUnit)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 650, idealWidth: 700, minHeight: 600)
    }

    private var cityResults: [OfflineCitySearchResult] {
        OfflinePlaceResolver.shared.cities(matching: citySearch)
    }

    private var latitudeBinding: Binding<Double> {
        Binding(
            get: { coordinate.latitude },
            set: {
                coordinate = PhotoCoordinate(
                    latitude: min(90, max(-90, $0)),
                    longitude: coordinate.longitude
                )
                selectedCity = nil
            }
        )
    }

    private var longitudeBinding: Binding<Double> {
        Binding(
            get: { coordinate.longitude },
            set: {
                coordinate = PhotoCoordinate(
                    latitude: coordinate.latitude,
                    longitude: min(180, max(-180, $0))
                )
                selectedCity = nil
            }
        )
    }

    private var radiusBinding: Binding<Double> {
        Binding(
            get: { distanceUnit.displayedDistance(forKilometers: radiusKilometers) },
            set: {
                radiusKilometers = min(
                    20_000,
                    max(1, distanceUnit.kilometers(forDisplayedDistance: $0))
                )
            }
        )
    }
}

private struct CoordinateWorldMap: View {
    @Binding var coordinate: PhotoCoordinate
    @State private var zoom: CGFloat = 1
    @State private var viewportCenter: PhotoCoordinate
    @State private var isSelecting = false
    let radiusKilometers: Double
    let onManualSelection: () -> Void

    private let zoomLevels: [CGFloat] = [1, 2, 4, 8]

    init(
        coordinate: Binding<PhotoCoordinate>,
        radiusKilometers: Double,
        onManualSelection: @escaping () -> Void
    ) {
        _coordinate = coordinate
        _viewportCenter = State(initialValue: coordinate.wrappedValue)
        self.radiusKilometers = radiusKilometers
        self.onManualSelection = onManualSelection
    }

    var body: some View {
        GeometryReader { geometry in
            if let page = WorldMapAsset.page {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        VectorWorldMap(
                            page: page,
                            zoom: zoom,
                            offset: WorldMapProjection.offset(
                                centeredAt: viewportCenter,
                                zoom: zoom,
                                in: geometry.size
                            )
                        )

                        Canvas { context, size in
                            let circleSize = WorldMapProjection.radiusSize(
                                kilometers: radiusKilometers,
                                at: coordinate,
                                zoom: zoom,
                                in: size
                            )
                            let center = pinPoint(in: size)
                            let circle = Path(ellipseIn: CGRect(
                                x: center.x - circleSize.width / 2,
                                y: center.y - circleSize.height / 2,
                                width: circleSize.width,
                                height: circleSize.height
                            ))
                            context.fill(circle, with: .color(.red.opacity(0.12)))
                            context.stroke(circle, with: .color(.red.opacity(0.8)), lineWidth: 1.5)
                        }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .allowsHitTesting(false)

                        Image(systemName: "mappin")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.red)
                            .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                            .frame(width: 24, height: 28, alignment: .bottom)
                            .position(
                                x: pinPoint(in: geometry.size).x,
                                y: pinPoint(in: geometry.size).y - 14
                            )
                            .allowsHitTesting(false)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isSelecting = true
                                coordinate = WorldMapProjection.coordinate(
                                    forDisplayedPoint: value.location,
                                    centeredAt: viewportCenter,
                                    zoom: zoom,
                                    in: geometry.size
                                )
                                onManualSelection()
                            }
                            .onEnded { _ in isSelecting = false }
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("World map coordinate picker")
                    .accessibilityValue(
                        String(
                            format: "Latitude %.4f, longitude %.4f, radius %.2f kilometers",
                            coordinate.latitude,
                            coordinate.longitude,
                            radiusKilometers
                        )
                    )

                    zoomControls
                        .padding(10)
                }
                .onChange(of: coordinate) { _, newCoordinate in
                    if !isSelecting {
                        viewportCenter = newCoordinate
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.3))
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 0) {
            Button {
                changeZoom(by: -1)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 24, height: 22)
            }
            .disabled(zoom == zoomLevels.first)
            .accessibilityLabel("Zoom out")

            Divider().frame(height: 16)

            Text("\(Int(zoom))×")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 34)

            Divider().frame(height: 16)

            Button {
                changeZoom(by: 1)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 24, height: 22)
            }
            .disabled(zoom == zoomLevels.last)
            .accessibilityLabel("Zoom in")
        }
        .buttonStyle(.plain)
        .padding(4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.25))
        }
    }

    private func pinPoint(in size: CGSize) -> CGPoint {
        WorldMapProjection.displayedPoint(
            for: coordinate,
            centeredAt: viewportCenter,
            zoom: zoom,
            in: size
        )
    }

    private func changeZoom(by step: Int) {
        guard let index = zoomLevels.firstIndex(of: zoom) else { return }
        viewportCenter = coordinate
        zoom = zoomLevels[min(zoomLevels.count - 1, max(0, index + step))]
    }
}
