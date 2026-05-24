import CoreGraphics

/// Pure layout helper for Warden Thorns orbit angles and sprite orientation.
enum WardenThornsLayout {
    private static let fullTurn = CGFloat.pi * 2

    /// Returns evenly spaced orbit angles, preserving the supplied phase as the first angle.
    static func angles(count: Int, phase: CGFloat) -> [CGFloat] {
        guard count > 0 else { return [] }

        let step = fullTurn / CGFloat(count)
        return (0..<count).map { phase + CGFloat($0) * step }
    }

    /// Rebuilds an orbit while preserving the first existing thorn phase.
    static func reconciledAngles(existing: [CGFloat], desiredCount: Int) -> [CGFloat] {
        angles(count: desiredCount, phase: existing.first ?? 0)
    }

    /// Converts an orbit angle into the sprite rotation used by the thorn art.
    static func spriteRotation(forThornAngle angle: CGFloat) -> CGFloat {
        angle
    }
}
