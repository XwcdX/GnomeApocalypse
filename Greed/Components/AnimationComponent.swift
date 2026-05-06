import SpriteKit

final class AnimationComponent {
    private let atlas: SKTextureAtlas
    private let owner: SKSpriteNode
    private let canMirror: Bool
    
    private var animations: [String: [SKTexture]] = [:]
    private var currentAnimation: String?
    
    init(atlasName: String, owner: SKSpriteNode, canMirror: Bool = true) {
        self.atlas = SKTextureAtlas(named: atlasName)
        self.owner = owner
        self.canMirror = canMirror
    }
    
    func loadAnimation(name: String, frameCount: Int) {
        guard frameCount > 0 else {
            Log.warning("AnimationComponent: frameCount must be > 0 for animation '\(name)'")
            return
        }
        
        let frames = (0..<frameCount).compactMap { index -> SKTexture? in
            let frameName = "\(name)_\(String(format: "%03d", index))"
            let texture = atlas.textureNamed(frameName)
            texture.filteringMode = .nearest
            return texture
        }
        
        guard !frames.isEmpty else {
            Log.warning("AnimationComponent: no frames loaded for animation '\(name)'")
            return
        }
        
        animations[name] = frames
    }
    
    func loadAnimations(prefix: String, frameCount: Int, suffixes: [String]) {
        for suffix in suffixes {
            loadAnimation(name: "\(prefix)\(suffix)", frameCount: frameCount)
        }
    }
    
    func play(animation: String, timePerFrame: TimeInterval, repeat: Bool = true) {
        guard currentAnimation != animation,
              let frames = animations[animation] else { return }
        
        currentAnimation = animation
        owner.removeAction(forKey: "animate")
        
        let action = SKAction.animate(with: frames, timePerFrame: timePerFrame)
        let finalAction = `repeat` ? SKAction.repeatForever(action) : action
        owner.run(finalAction, withKey: "animate")
    }
    
    func stop() {
        owner.removeAction(forKey: "animate")
        currentAnimation = nil
    }
    
    func setDirection(dx: CGFloat, dy: CGFloat) -> String {
        let angle = atan2(dy, dx)
        let degrees = angle * 180 / .pi
        
        let direction: String
        if degrees >= -22.5 && degrees < 22.5 {
            direction = "right"
        } else if degrees >= 22.5 && degrees < 67.5 {
            direction = "right_up"
        } else if degrees >= 67.5 && degrees < 112.5 {
            direction = "up"
        } else if degrees >= 112.5 && degrees < 157.5 {
            direction = "up_left"
        } else if degrees >= 157.5 || degrees < -157.5 {
            direction = "left"
        } else if degrees >= -157.5 && degrees < -112.5 {
            direction = "down_left"
        } else if degrees >= -112.5 && degrees < -67.5 {
            direction = "down"
        } else {
            direction = "right_down"
        }
        
        if canMirror {
            if direction.contains("right") {
                owner.xScale = -1
                return direction.replacingOccurrences(of: "right", with: "left")
            } else {
                owner.xScale = 1
            }
        }
        
        return direction
    }
}
