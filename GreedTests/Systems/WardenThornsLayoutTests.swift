import CoreGraphics
import Testing
@testable import Greed

@Suite("WardenThornsLayout")
struct WardenThornsLayoutTests {
    @Test("angles are evenly spaced around the player")
    func anglesAreEvenlySpaced() {
        for count in [1, 2, 4, 6] {
            let phase: CGFloat = 0.42
            let angles = WardenThornsLayout.angles(count: count, phase: phase)

            #expect(angles.count == count)
            assertEvenSpacing(angles, expectedGap: (CGFloat.pi * 2) / CGFloat(count))
            #expect(approximatelyEqual(angles[0], phase))
        }
    }

    @Test("upgrades redistribute thorns without losing rotation phase")
    func upgradesRedistributeThornsWithoutLosingPhase() {
        let phase: CGFloat = 0.75
        let twoThorns = WardenThornsLayout.angles(count: 2, phase: phase)
        let fourThorns = WardenThornsLayout.reconciledAngles(existing: twoThorns, desiredCount: 4)
        let sixThorns = WardenThornsLayout.reconciledAngles(existing: fourThorns, desiredCount: 6)

        #expect(approximatelyEqual(fourThorns[0], phase))
        #expect(approximatelyEqual(sixThorns[0], phase))
        assertEvenSpacing(fourThorns, expectedGap: (CGFloat.pi * 2) / 4)
        assertEvenSpacing(sixThorns, expectedGap: (CGFloat.pi * 2) / 6)
    }

    @Test("animated thorn source art follows counter-clockwise orbit tangent")
    func animatedThornSourceArtFollowsCounterClockwiseOrbitTangent() {
        for angle in [CGFloat.zero, .pi / 2, .pi, .pi * 1.5] {
            #expect(approximatelyEqual(
                WardenThornsLayout.spriteRotation(forThornAngle: angle),
                angle
            ))
        }
    }

    @Test("animated thorn visual footprint stays compact while gameplay values stay unchanged")
    func animatedThornVisualFootprintStaysCompactWhileGameplayValuesStayUnchanged() {
        #expect(approximatelyEqual(SkillConfig.wardenThornSize.width, 12))
        #expect(approximatelyEqual(SkillConfig.wardenThornSize.height, 38))
        #expect(approximatelyEqual(SkillConfig.wardenThornRadius, 90))
        #expect(approximatelyEqual(SkillConfig.wardenThornRotationSpeed, 3.0))
        #expect(approximatelyEqual(SkillConfig.wardenThornHitRadius, 10))
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
