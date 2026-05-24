import SpriteKit

/// Atlas-backed animation helper for SpriteKit nodes with optional horizontal mirroring.
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
    
    /// Loads frames named `<name>_000`, `<name>_001`, ... from the configured atlas.
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
    
    /// Loads several animations by appending each suffix to `prefix`.
    func loadAnimations(prefix: String, frameCount: Int, suffixes: [String]) {
        for suffix in suffixes {
            loadAnimation(name: "\(prefix)\(suffix)", frameCount: frameCount)
        }
    }
    
    /// Starts an animation unless it is already active on the owner.
    func play(animation: String, timePerFrame: TimeInterval, repeat: Bool = true) {
        guard currentAnimation != animation,
              let frames = animations[animation] else { return }
        
        currentAnimation = animation
        owner.removeAction(forKey: "animate")
        
        let action = SKAction.animate(with: frames, timePerFrame: timePerFrame)
        let finalAction = `repeat` ? SKAction.repeatForever(action) : action
        owner.run(finalAction, withKey: "animate")
    }
    
    /// Stops the owner animation and clears the active animation key.
    func stop() {
        owner.removeAction(forKey: "animate")
        currentAnimation = nil
    }
    
    /// Maps a movement or aim vector to an animation direction name.
    func setDirection(dx: CGFloat, dy: CGFloat) -> String {
        let angle = atan2(dy, dx)
        let degrees = angle * 180 / .pi

        let rightSide: String
        if degrees >= -22.5 && degrees < 22.5 {
            rightSide = "right"
        } else if degrees >= 22.5 && degrees < 67.5 {
            rightSide = "up_right"
        } else if degrees >= 67.5 && degrees < 112.5 {
            rightSide = "up"
        } else if degrees >= 112.5 && degrees < 157.5 {
            rightSide = "up_left"
        } else if degrees >= 157.5 || degrees < -157.5 {
            rightSide = "left"
        } else if degrees >= -157.5 && degrees < -112.5 {
            rightSide = "down_left"
        } else if degrees >= -112.5 && degrees < -67.5 {
            rightSide = "down"
        } else {
            rightSide = "down_right"
        }

        guard canMirror else { return rightSide }

        owner.yScale = abs(owner.yScale)
        switch rightSide {
        case "right":
            owner.xScale = 1
            return "right"
        case "up_right":
            owner.xScale = 1
            return "up_right"
        case "down_right":
            owner.xScale = 1
            return "down_right"
        case "left":
            owner.xScale = -1
            return "right"
        case "up_left":
            owner.xScale = -1
            return "up_right"
        case "down_left":
            owner.xScale = -1
            return "down_right"
        default:
            owner.xScale = 1
            return rightSide
        }
    }
}
