import CoreGraphics
import Testing

@testable import Greed

private let map = CGSize(width: 1000, height: 1000)

// MARK: - toroidalOffset
@Suite("toroidalOffset")
struct ToroidalOffsetTests {
    @Test("offset between two nearby points - direct path")
    func directPath() {
        let offset = toroidalOffset(
            from: CGPoint(x: -100, y: -100),
            to: CGPoint(x: 100, y: 100),
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
            from: CGPoint(x: 400, y: 0),
            to: CGPoint(x: -450, y: 0),
            mapSize: map
        )
        #expect(offset.dx == 150)
    }

    @Test("west boundary wrap is shorter than direct path")
    func westWrapShorter() {
        let offset = toroidalOffset(
            from: CGPoint(x: -450, y: 0),
            to: CGPoint(x: 400, y: 0),
            mapSize: map
        )
        #expect(offset.dx == -150)
    }

    @Test("north boundary wrap is shorter than direct path")
    func northWrapShorter() {
        let offset = toroidalOffset(
            from: CGPoint(x: 0, y: 400),
            to: CGPoint(x: 0, y: -450),
            mapSize: map
        )
        #expect(offset.dy == 150)
    }

    @Test("south boundary wrap is shorter than direct path")
    func southWrapShorter() {
        let offset = toroidalOffset(
            from: CGPoint(x: 0, y: -450),
            to: CGPoint(x: 0, y: 400),
            mapSize: map
        )
        #expect(offset.dy == -150)
    }

    @Test("diagonal wrap - both axes wrap")
    func diagonalWrap() {
        let offset = toroidalOffset(
            from: CGPoint(x: 400, y: 400),
            to: CGPoint(x: -450, y: -450),
            mapSize: map
        )
        #expect(offset.dx == 150)
        #expect(offset.dy == 150)
    }

    @Test("offset magnitude never exceeds half map size on either axis")
    func magnitudeHalfMapMax() {
        let offset = toroidalOffset(
            from: CGPoint(x: 0, y: 0),
            to: CGPoint(x: 250, y: 250),
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
            from: CGPoint(x: -100, y: -100),
            to: CGPoint(x: 100, y: 100),
            mapSize: map
        )
        #expect(result.x == 100)
        #expect(result.y == 100)
    }

    @Test("target across east boundary returned in offset sector")
    func targetAcrossEast() {
        let result = nearestToroidalTarget(
            from: CGPoint(x: 450, y: 0),
            to: CGPoint(x: -450, y: 0),
            mapSize: map
        )
        #expect(result.x == 550)
        #expect(result.y == 0)
    }

    @Test("target across west boundary returned in offset sector")
    func targetAcrossWest() {
        let result = nearestToroidalTarget(
            from: CGPoint(x: -450, y: 0),
            to: CGPoint(x: 450, y: 0),
            mapSize: map
        )
        #expect(result.x == -550)
        #expect(result.y == 0)
    }

    @Test("target across north boundary returned in offset sector")
    func targetAcrossNorth() {
        let result = nearestToroidalTarget(
            from: CGPoint(x: 0, y: 450),
            to: CGPoint(x: 0, y: -450),
            mapSize: map
        )
        #expect(result.y == 550)
    }

    @Test("target across south boundary returned in offset sector")
    func targetAcrossSouth() {
        let result = nearestToroidalTarget(
            from: CGPoint(x: 0, y: -450),
            to: CGPoint(x: 0, y: 450),
            mapSize: map
        )
        #expect(result.y == -550)
    }

    @Test("corner origin - nearest sector diagonal wrap")
    func cornerOriginDiagonalWrap() {
        let result = nearestToroidalTarget(
            from: CGPoint(x: 490, y: 490),
            to: CGPoint(x: -490, y: -490),
            mapSize: map
        )
        #expect(result.x == 510)
        #expect(result.y == 510)
    }

    @Test("result is always within one map-width of origin on each axis")
    func resultWithinOneMapWidth() {
        let cases: [(origin: CGPoint, target: CGPoint)] = [
            (CGPoint(x: -400, y: -400), CGPoint(x: 400, y: 400)),
            (CGPoint(x: 0, y: 0), CGPoint(x: 499, y: 499)),
            (CGPoint(x: 250, y: 0), CGPoint(x: 250, y: 499)),
        ]
        for c in cases {
            let result = nearestToroidalTarget(from: c.origin, to: c.target, mapSize: map)
            #expect(abs(result.x - c.origin.x) <= map.width)
            #expect(abs(result.y - c.origin.y) <= map.height)
        }
    }
}

// MARK: - toroidalDistance
@Suite("toroidalDistance")
struct ToroidalDistanceTests {
    @Test("distance between identical points is zero")
    func zeroDistance() {
        let d = toroidalDistance(
            from: CGPoint(x: 100, y: 100),
            to: CGPoint(x: 100, y: 100),
            mapSize: map
        )
        #expect(d == 0)
    }

    @Test("distance is shorter across boundary than across map")
    func shorterAcrossBoundary() {
        let d = toroidalDistance(
            from: CGPoint(x: 400, y: 0),
            to: CGPoint(x: -450, y: 0),
            mapSize: map
        )
        #expect(d < 200)
    }

    @Test("distance is symmetric")
    func symmetry() {
        let a = CGPoint(x: -200, y: 100)
        let b = CGPoint(x: 300, y: -200)
        let ab = toroidalDistance(from: a, to: b, mapSize: map)
        let ba = toroidalDistance(from: b, to: a, mapSize: map)
        #expect(abs(ab - ba) < 0.001)
    }
}
