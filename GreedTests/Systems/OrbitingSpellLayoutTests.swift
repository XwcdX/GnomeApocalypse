import CoreGraphics
import Testing
@testable import Greed

@Suite("OrbitingSpellLayout")
struct OrbitingSpellLayoutTests {
    @Test("angles are evenly spaced around the player")
    func anglesAreEvenlySpaced() {
        for count in [1, 2, 4, 6] {
            let phase: CGFloat = 0.42
            let angles = OrbitingSpellLayout.angles(count: count, phase: phase)

            #expect(angles.count == count)
            assertEvenSpacing(angles, expectedGap: (CGFloat.pi * 2) / CGFloat(count))
            #expect(approximatelyEqual(angles[0], phase))
        }
    }

    @Test("upgrades redistribute knives without losing orbit phase")
    func upgradesRedistributeKnivesWithoutLosingPhase() {
        let phase: CGFloat = 0.75
        let twoKnives = OrbitingSpellLayout.angles(count: 2, phase: phase)
        let fourKnives = OrbitingSpellLayout.reconciledAngles(existing: twoKnives, desiredCount: 4)
        let sixKnives = OrbitingSpellLayout.reconciledAngles(existing: fourKnives, desiredCount: 6)

        #expect(approximatelyEqual(fourKnives[0], phase))
        #expect(approximatelyEqual(sixKnives[0], phase))
        assertEvenSpacing(fourKnives, expectedGap: (CGFloat.pi * 2) / 4)
        assertEvenSpacing(sixKnives, expectedGap: (CGFloat.pi * 2) / 6)
    }

    @Test("knife tip follows counter-clockwise travel direction")
    func knifeTipFollowsCounterClockwiseTravelDirection() {
        #expect(approximatelyEqual(
            OrbitingSpellLayout.spriteRotation(forOrbitAngle: 0),
            CGFloat.pi / 2
        ))
    }

    private func assertEvenSpacing(_ angles: [CGFloat], expectedGap: CGFloat) {
        guard !angles.isEmpty else {
            Issue.record("expected at least one angle")
            return
        }

        let normalized = angles.map(normalizeAngle).sorted()
        for index in normalized.indices {
            let nextIndex = normalized.index(after: index)
            let next = nextIndex == normalized.endIndex ? normalized[0] + CGFloat.pi * 2 : normalized[nextIndex]
            #expect(approximatelyEqual(next - normalized[index], expectedGap))
        }
    }

    private func normalizeAngle(_ angle: CGFloat) -> CGFloat {
        let fullTurn = CGFloat.pi * 2
        let remainder = angle.truncatingRemainder(dividingBy: fullTurn)
        return remainder >= 0 ? remainder : remainder + fullTurn
    }

    private func approximatelyEqual(_ lhs: CGFloat, _ rhs: CGFloat, tolerance: CGFloat = 0.0001) -> Bool {
        abs(lhs - rhs) <= tolerance
    }
}
