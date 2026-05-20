import CoreGraphics

enum WardenThornsLayout {
    private static let fullTurn = CGFloat.pi * 2

    static func angles(count: Int, phase: CGFloat) -> [CGFloat] {
        guard count > 0 else { return [] }

        let step = fullTurn / CGFloat(count)
        return (0..<count).map { phase + CGFloat($0) * step }
    }

    static func reconciledAngles(existing: [CGFloat], desiredCount: Int) -> [CGFloat] {
        angles(count: desiredCount, phase: existing.first ?? 0)
    }

    static func spriteRotation(forThornAngle angle: CGFloat) -> CGFloat {
        angle + CGFloat.pi / 2
    }
}
