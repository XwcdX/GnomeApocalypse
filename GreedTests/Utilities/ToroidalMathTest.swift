import CoreGraphics
import Testing

@testable import Greed

private let map = CGSize(width: 1000, height: 1000)

// MARK: - toroidalWrap
@Suite("toroidalWrap")
struct ToroidalWrapTests {
    @Test("centre position unchanged")
    func centreUnchanged() {
        let result = toroidalWrap(CGPoint(x: 500, y: 500), mapSize: map)
        #expect(result.x == 500)
        #expect(result.y == 500)
    }

    @Test("origin position unchanged")
    func originUnchanged() {
        let result = toroidalWrap(CGPoint(x: 0, y: 0), mapSize: map)
        #expect(result.x == 0)
        #expect(result.y == 0)
    }

    @Test("wrap east boundary - exactly at width")
    func wrapEastExact() {
        let result = toroidalWrap(CGPoint(x: 1000, y: 0), mapSize: map)
        #expect(result.x == 0)
    }

    @Test("wrap east boundary - slightly past width")
    func wrapEastSlightlyPast() {
        let result = toroidalWrap(CGPoint(x: 1100, y: 0), mapSize: map)
        #expect(result.x == 100)
    }

    @Test("wrap west boundary - negative x")
    func wrapWestNegative() {
        let result = toroidalWrap(CGPoint(x: -100, y: 0), mapSize: map)
        #expect(result.x == 900)
    }

    @Test("wrap west boundary - exactly at -width")
    func wrapWestExact() {
        let result = toroidalWrap(CGPoint(x: -1000, y: 0), mapSize: map)
        #expect(result.x == 0)
    }

    @Test("wrap north boundary - past height")
    func wrapNorthPast() {
        let result = toroidalWrap(CGPoint(x: 0, y: 1050), mapSize: map)
        #expect(result.y == 50)
    }

    @Test("wrap south boundary - negative y")
    func wrapSouthNegative() {
        let result = toroidalWrap(CGPoint(x: 0, y: -200), mapSize: map)
        #expect(result.y == 800)
    }

    @Test("wrap north-east corner")
    func wrapNorthEastCorner() {
        let result = toroidalWrap(CGPoint(x: 1100, y: 1100), mapSize: map)
        #expect(result.x == 100)
        #expect(result.y == 100)
    }

    @Test("wrap south-west corner - negative both axes")
    func wrapSouthWestCorner() {
        let result = toroidalWrap(CGPoint(x: -50, y: -50), mapSize: map)
        #expect(result.x == 950)
        #expect(result.y == 950)
    }

    @Test("multi-wrap east - 2.5× width")
    func multiWrapEast() {
        let result = toroidalWrap(CGPoint(x: 2500, y: 0), mapSize: map)
        #expect(result.x == 500)
    }

    @Test("multi-wrap south - negative 2× height")
    func multiWrapSouth() {
        let result = toroidalWrap(CGPoint(x: 0, y: -2000), mapSize: map)
        #expect(result.y == 0)
    }

    @Test(
        "wrap produces value in [0, width)",
        arguments: [-1.0, 0.0, 999.0, 1000.0, 1500.0, -500.0]
    )
    func wrapInBounds(x: CGFloat) {
        let result = toroidalWrap(CGPoint(x: x, y: 0), mapSize: map)
        #expect(result.x >= 0)
        #expect(result.x < map.width)
    }
}

// MARK: - toroidalOffset
@Suite("toroidalOffset")
struct ToroidalOffsetTests {
    @Test("offset between two points in same half - direct path")
    func directPath() {
        let offset = toroidalOffset(
            from: CGPoint(x: 200, y: 200),
            to: CGPoint(x: 400, y: 400),
            mapSize: map
        )
        #expect(offset.dx == 200)
        #expect(offset.dy == 200)
    }

    @Test("zero offset for identical points")
    func zeroOffset() {
        let offset = toroidalOffset(
            from: CGPoint(x: 300, y: 300),
            to: CGPoint(x: 300, y: 300),
            mapSize: map
        )
        #expect(offset.dx == 0)
        #expect(offset.dy == 0)
    }

    @Test("east boundary wrap is shorter than direct path")
    func eastWrapShorter() {
        let offset = toroidalOffset(
            from: CGPoint(x: 900, y: 500),
            to: CGPoint(x: 50, y: 500),
            mapSize: map
        )
        #expect(offset.dx == 150)
    }

    @Test("west boundary wrap is shorter than direct path")
    func westWrapShorter() {
        let offset = toroidalOffset(
            from: CGPoint(x: 50, y: 500),
            to: CGPoint(x: 950, y: 500),
            mapSize: map
        )
        #expect(offset.dx == -100)
    }

    @Test("north boundary wrap is shorter than direct path")
    func northWrapShorter() {
        let offset = toroidalOffset(
            from: CGPoint(x: 500, y: 900),
            to: CGPoint(x: 500, y: 50),
            mapSize: map
        )
        #expect(offset.dy == 150)
    }

    @Test("south boundary wrap is shorter than direct path")
    func southWrapShorter() {
        let offset = toroidalOffset(
            from: CGPoint(x: 500, y: 50),
            to: CGPoint(x: 500, y: 950),
            mapSize: map
        )
        #expect(offset.dy == -100)
    }

    @Test("diagonal wrap - both axes wrap")
    func diagonalWrap() {
        let offset = toroidalOffset(
            from: CGPoint(x: 900, y: 900),
            to: CGPoint(x: 50, y: 50),
            mapSize: map
        )
        #expect(offset.dx == 150)
        #expect(offset.dy == 150)
    }

    @Test("offset magnitude never exceeds half map size on either axis")
    func magnitudeHalfMapMax() {
        let offset = toroidalOffset(
            from: CGPoint(x: 0, y: 0),
            to: CGPoint(x: 500, y: 500),
            mapSize: map
        )
        #expect(abs(offset.dx) <= map.width / 2)
        #expect(abs(offset.dy) <= map.height / 2)
    }
}

// MARK: - nearestToroidalTarget
@Suite("nearestToroidalTarget")
struct NearestToroidalTargetTests {
    @Test("same-sector target returned unchanged")
    func sameSector() {
        let result = nearestToroidalTarget(
            from: CGPoint(x: 300, y: 300),
            to: CGPoint(x: 400, y: 400),
            mapSize: map
        )
        #expect(result.x == 400)
        #expect(result.y == 400)
    }

    @Test("target across east boundary is returned in offset sector")
    func targetAcrossEast() {
        let result = nearestToroidalTarget(
            from: CGPoint(x: 950, y: 500),
            to: CGPoint(x: 50, y: 500),
            mapSize: map
        )
        #expect(result.x == 1050)
        #expect(result.y == 500)
    }

    @Test("target across west boundary is returned in offset sector")
    func targetAcrossWest() {
        let result = nearestToroidalTarget(
            from: CGPoint(x: 50, y: 500),
            to: CGPoint(x: 950, y: 500),
            mapSize: map
        )
        #expect(result.x == -50)
        #expect(result.y == 500)
    }

    @Test("target across north boundary is returned in offset sector")
    func targetAcrossNorth() {
        let result = nearestToroidalTarget(
            from: CGPoint(x: 500, y: 950),
            to: CGPoint(x: 500, y: 50),
            mapSize: map
        )
        #expect(result.y == 1050)
    }

    @Test("target across south boundary is returned in offset sector")
    func targetAcrossSouth() {
        let result = nearestToroidalTarget(
            from: CGPoint(x: 500, y: 50),
            to: CGPoint(x: 500, y: 950),
            mapSize: map
        )
        #expect(result.y == -50)
    }

    @Test("corner origin - nearest sector diagonal wrap")
    func cornerOriginDiagonalWrap() {
        let result = nearestToroidalTarget(
            from: CGPoint(x: 990, y: 990),
            to: CGPoint(x: 10, y: 10),
            mapSize: map
        )
        #expect(result.x == 1010)
        #expect(result.y == 1010)
    }

    @Test(
        "equidistant target - function returns a valid sector (deterministic)"
    )
    func equidistantDeterministic() {
        let origin = CGPoint(x: 500, y: 500)
        let target = CGPoint(x: 0, y: 500)
        let result = nearestToroidalTarget(
            from: origin,
            to: target,
            mapSize: map
        )
        let dist = sqrt(
            pow(result.x - origin.x, 2) + pow(result.y - origin.y, 2)
        )
        #expect(dist == 500)
    }

    @Test("result is always within one map-width of origin on each axis")
    func resultWithinOneMapWidth() {
        let cases: [(origin: CGPoint, target: CGPoint)] = [
            (CGPoint(x: 100, y: 100), CGPoint(x: 900, y: 900)),
            (CGPoint(x: 0, y: 0), CGPoint(x: 999, y: 999)),
            (CGPoint(x: 500, y: 0), CGPoint(x: 500, y: 999)),
        ]
        for c in cases {
            let result = nearestToroidalTarget(
                from: c.origin,
                to: c.target,
                mapSize: map
            )
            #expect(abs(result.x - c.origin.x) <= map.width)
            #expect(abs(result.y - c.origin.y) <= map.height)
        }
    }
}

// MARK: - toroidalDistance (convenience wrapper)
@Suite("toroidalDistance")
struct ToroidalDistanceTests {
    @Test("distance between identical points is zero")
    func zeroDistance() {
        let d = toroidalDistance(
            from: CGPoint(x: 300, y: 300),
            to: CGPoint(x: 300, y: 300),
            mapSize: map
        )
        #expect(d == 0)
    }

    @Test("distance is shorter across boundary than across map")
    func shorterAcrossBoundary() {
        let d = toroidalDistance(
            from: CGPoint(x: 900, y: 500),
            to: CGPoint(x: 50, y: 500),
            mapSize: map
        )
        #expect(d < 200)
    }

    @Test("distance is symmetric")
    func symmetry() {
        let a = CGPoint(x: 100, y: 200)
        let b = CGPoint(x: 800, y: 700)
        let ab = toroidalDistance(from: a, to: b, mapSize: map)
        let ba = toroidalDistance(from: b, to: a, mapSize: map)
        #expect(abs(ab - ba) < 0.001)
    }
}
