import SpriteKit

final class LuminousWisp: PlayerEntity {
    private var animator: AnimationComponent!
    private var currentState: AnimationState = .idle
    private var lastDirection: String = "down"
    
    private enum AnimationState {
        case idle, walking, shooting
    }
    
    init(inputIndex: Int) {
        let atlas = SKTextureAtlas(named: "LuminousWisp")
        let firstFrame = atlas.textureNamed("down_idle_000")
        
        super.init(texture: firstFrame, health: GameConfig.basePlayerHealth)
        self.controllerIndex = inputIndex == 0 ? nil : inputIndex
        self.name = "LuminousWisp"
        
        setupAnimations()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
    
    private func setupAnimations() {
        animator = AnimationComponent(atlasName: "LuminousWisp", owner: self, canMirror: false)
        
        let directions = ["up", "down", "left", "right", "up_left", "right_up", "down_left", "right_down"]
        let actions = ["idle", "walk", "shoot"]
        
        for direction in directions {
            for action in actions {
                animator.loadAnimation(name: "\(direction)_\(action)", frameCount: 6)
            }
        }
    }
    
    override func update(deltaTime: TimeInterval) {
        super.update(deltaTime: deltaTime)
        updateAnimation()
    }
    
    private func updateAnimation() {
        guard let scene = scene as? GameScene else { return }
        
        let movement = scene.inputSystem.movementVector(for: controllerIndex ?? 0)
        let isMoving = movement.dx != 0 || movement.dy != 0
        
        if isMoving {
            lastDirection = animator.setDirection(dx: movement.dx, dy: movement.dy)
        }
        
        let newState: AnimationState = isMoving ? .walking : .idle
        let animationName = "\(lastDirection)_\(newState == .walking ? "walk" : "idle")"
        
        animator.play(animation: animationName, timePerFrame: 0.1, repeat: true)
    }
}
