import CoreGraphics

/// Returns the shortest wrapped vector from `a` to `b` in the toroidal world.
func toroidalOffset(from a: CGPoint, to b: CGPoint, mapSize: CGSize) -> CGVector {
    let w = mapSize.width
    let h = mapSize.height

    var dx = (b.x - a.x).truncatingRemainder(dividingBy: w)
    if dx > w / 2  { dx -= w }
    if dx < -w / 2 { dx += w }

    var dy = (b.y - a.y).truncatingRemainder(dividingBy: h)
    if dy > h / 2  { dy -= h }
    if dy < -h / 2 { dy += h }

    return CGVector(dx: dx, dy: dy)
}

/// Returns the sector copy of `target` that is nearest to `origin`.
func nearestToroidalTarget(from origin: CGPoint, to target: CGPoint, mapSize: CGSize) -> CGPoint {
    let w = mapSize.width
    let h = mapSize.height
    
    var bestPosition = target
    var bestDistanceSq = CGFloat.greatestFiniteMagnitude
    
    for dx: CGFloat in [-w, 0, w] {
        for dy: CGFloat in [-h, 0, h] {
            let candidate = CGPoint(x: target.x + dx, y: target.y + dy)
            let distSq = pow(candidate.x - origin.x, 2) + pow(candidate.y - origin.y, 2)
            if distSq < bestDistanceSq {
                bestDistanceSq = distSq
                bestPosition = candidate
            }
        }
    }
    
    return bestPosition
}

/// Returns the shortest wrapped distance between two world positions.
func toroidalDistance(from a: CGPoint, to b: CGPoint, mapSize: CGSize) -> CGFloat {
    let offset = toroidalOffset(from: a, to: b, mapSize: mapSize)
    return sqrt(offset.dx * offset.dx + offset.dy * offset.dy)
}
