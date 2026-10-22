import CoreGraphics
import SwiftUI

struct WorldMinimap: View {
    let coordinate: PhotoCoordinate
    let duration: TimeInterval
    var size = CGSize(width: 220, height: 110)
    var animateZoom = true

    // Silhouette derived from Natural Earth 1:110m land data (public domain).
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var zoomProgress: CGFloat = 0

    private let maximumZoom: CGFloat = 14

    var body: some View {
        if let mapPage = WorldMapAsset.page {
            ZStack {
                VectorWorldMap(
                    page: mapPage,
                    zoom: zoom,
                    offset: mapOffset
                )

                Image(systemName: "mappin")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.red)
                    .frame(width: 24, height: 28, alignment: .bottom)
                    .position(x: pinPoint.x, y: pinPoint.y - 14)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onAppear {
                guard animateZoom, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: duration)) {
                    zoomProgress = 1
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("World map showing the photo location")
        }
    }

    private var displayedZoomProgress: CGFloat {
        animateZoom && !reduceMotion ? zoomProgress : 1
    }

    private var zoom: CGFloat {
        1 + (maximumZoom - 1) * displayedZoomProgress
    }

    private var mapPoint: CGPoint {
        WorldMapProjection.point(for: coordinate, in: size)
    }

    private var mapOffset: CGSize {
        let x = (size.width / 2 - mapPoint.x * maximumZoom) * displayedZoomProgress
        let y = (size.height / 2 - mapPoint.y * maximumZoom) * displayedZoomProgress
        return CGSize(
            width: min(0, max(size.width * (1 - zoom), x)),
            height: min(0, max(size.height * (1 - zoom), y))
        )
    }

    private var pinPoint: CGPoint {
        CGPoint(
            x: mapPoint.x * zoom + mapOffset.width,
            y: mapPoint.y * zoom + mapOffset.height
        )
    }
}

enum WorldMapAsset {
    static let page = Bundle.main.url(forResource: "WorldMap", withExtension: "pdf")
        .flatMap { CGPDFDocument($0 as CFURL)?.page(at: 1) }
}

struct VectorWorldMap: View, Animatable {
    let page: CGPDFPage
    var zoom: CGFloat
    var offset: CGSize

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(zoom, AnimatablePair(offset.width, offset.height)) }
        set {
            zoom = newValue.first
            offset = CGSize(width: newValue.second.first, height: newValue.second.second)
        }
    }

    var body: some View {
        Canvas { context, canvasSize in
            context.withCGContext { drawingContext in
                let pageSize = page.getBoxRect(.mediaBox).size
                drawingContext.translateBy(
                    x: offset.width,
                    y: offset.height + canvasSize.height * zoom
                )
                drawingContext.scaleBy(
                    x: canvasSize.width / pageSize.width * zoom,
                    y: -canvasSize.height / pageSize.height * zoom
                )
                drawingContext.drawPDFPage(page)
            }
        }
    }
}

enum WorldMapProjection {
    static func point(for coordinate: PhotoCoordinate, in size: CGSize) -> CGPoint {
        let latitude = min(90, max(-90, coordinate.latitude))
        let longitude = min(180, max(-180, coordinate.longitude))
        return CGPoint(
            x: (longitude + 180) / 360 * size.width,
            y: (90 - latitude) / 180 * size.height
        )
    }

    static func coordinate(for point: CGPoint, in size: CGSize) -> PhotoCoordinate {
        PhotoCoordinate(
            latitude: 90 - min(size.height, max(0, point.y)) / size.height * 180,
            longitude: min(size.width, max(0, point.x)) / size.width * 360 - 180
        )
    }

    static func offset(
        centeredAt center: PhotoCoordinate,
        zoom: CGFloat,
        in size: CGSize
    ) -> CGSize {
        let zoom = max(1, zoom)
        let centerPoint = point(for: center, in: size)
        return CGSize(
            width: min(0, max(size.width * (1 - zoom), size.width / 2 - centerPoint.x * zoom)),
            height: min(0, max(size.height * (1 - zoom), size.height / 2 - centerPoint.y * zoom))
        )
    }

    static func displayedPoint(
        for coordinate: PhotoCoordinate,
        centeredAt center: PhotoCoordinate,
        zoom: CGFloat,
        in size: CGSize
    ) -> CGPoint {
        let zoom = max(1, zoom)
        let mapOffset = offset(centeredAt: center, zoom: zoom, in: size)
        let mapPoint = point(for: coordinate, in: size)
        return CGPoint(
            x: mapPoint.x * zoom + mapOffset.width,
            y: mapPoint.y * zoom + mapOffset.height
        )
    }

    static func coordinate(
        forDisplayedPoint point: CGPoint,
        centeredAt center: PhotoCoordinate,
        zoom: CGFloat,
        in size: CGSize
    ) -> PhotoCoordinate {
        let zoom = max(1, zoom)
        let mapOffset = offset(centeredAt: center, zoom: zoom, in: size)
        return coordinate(
            for: CGPoint(
                x: (point.x - mapOffset.width) / zoom,
                y: (point.y - mapOffset.height) / zoom
            ),
            in: size
        )
    }

    static func radiusSize(
        kilometers: Double,
        at coordinate: PhotoCoordinate,
        zoom: CGFloat,
        in size: CGSize
    ) -> CGSize {
        let latitudeRadians = coordinate.latitude * .pi / 180
        let kilometersPerLongitudeDegree = 111.32 * max(0.01, cos(latitudeRadians))
        let diameter = max(0, kilometers) * 2
        return CGSize(
            width: CGFloat(diameter / kilometersPerLongitudeDegree / 360) * size.width * max(1, zoom),
            height: CGFloat(diameter / 111.32 / 180) * size.height * max(1, zoom)
        )
    }
}
