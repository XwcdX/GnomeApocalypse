// All spatial calculations involving the wrapping map must go through here.
// Never compute wrapped positions or toroidal distances inline in entity or scene code.
//
// Used by: EnemyAI, ToroidalPositionComponent, CameraSystem, FloorTileRenderer

import CoreGraphics

// MARK: - Wrap
/// Wraps `position` into map bounds using modulo on both axes.
/// Handles positions that crossed multiple boundaries in a single frame.
func toroidalWrap(_ position: CGPoint, mapSize: CGSize) -> CGPoint {
    let w = mapSize.width
    let h = mapSize.height

    var x = position.x.truncatingRemainder(dividingBy: w)
    if x < 0 { x += w }

    var y = position.y.truncatingRemainder(dividingBy: h)
    if y < 0 { y += h }

    return CGPoint(x: x, y: y)
}

// MARK: - Shortest Offset
/// Returns the shortest-path vector from `a` to `b`, accounting for boundary crossing.
/// The result may point outside `[0, mapSize)` if wrapping is the shorter route.
func toroidalOffset(from a: CGPoint, to b: CGPoint, mapSize: CGSize) -> CGVector
{
    let w = mapSize.width
    let h = mapSize.height

    var dx = b.x - a.x
    if dx > w / 2 { dx -= w }
    if dx < -w / 2 { dx += w }

    var dy = b.y - a.y
    if dy > h / 2 { dy -= h }
    if dy < -h / 2 { dy += h }

    return CGVector(dx: dx, dy: dy)
}

// MARK: - Nearest Target (9-Sector Evaluation)
/// Returns the position of `target` in whichever of the 9 toroidal sectors is closest to `origin`.
///
/// The result may lie outside map bounds - treat it as a directional reference only, never store
/// it as a world position. EnemyAI calls this once per frame and discards the result after use.
func nearestToroidalTarget(
    from origin: CGPoint,
    to target: CGPoint,
    mapSize: CGSize
) -> CGPoint {
    let w = mapSize.width
    let h = mapSize.height

    var bestPosition = target
    var bestDistanceSq = CGFloat.greatestFiniteMagnitude

    for dx: CGFloat in [-w, 0, w] {
        for dy: CGFloat in [-h, 0, h] {
            let candidate = CGPoint(x: target.x + dx, y: target.y + dy)
            let distSq =
                pow(candidate.x - origin.x, 2) + pow(candidate.y - origin.y, 2)
            if distSq < bestDistanceSq {
                bestDistanceSq = distSq
                bestPosition = candidate
            }
        }
    }

    return bestPosition
}

// MARK: - Convenience
/// Scalar toroidal distance between two points. Convenience wrapper around `toroidalOffset`.
/// Use when you need a magnitude rather than a direction - e.g. auto-aim target ranking.
func toroidalDistance(from a: CGPoint, to b: CGPoint, mapSize: CGSize)
    -> CGFloat
{
    let offset = toroidalOffset(from: a, to: b, mapSize: mapSize)
    return sqrt(offset.dx * offset.dx + offset.dy * offset.dy)
}
