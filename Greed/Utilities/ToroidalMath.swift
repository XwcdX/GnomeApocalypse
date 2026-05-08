import CoreGraphics

func toroidalOffset(from a: CGPoint, to b: CGPoint, mapSize: CGSize) -> CGVector {
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

func toroidalDistance(from a: CGPoint, to b: CGPoint, mapSize: CGSize) -> CGFloat {
    let offset = toroidalOffset(from: a, to: b, mapSize: mapSize)
    return sqrt(offset.dx * offset.dx + offset.dy * offset.dy)
}
