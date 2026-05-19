import SpriteKit

final class LuminousWisp: PlayerEntity {
    private var animator: AnimationComponent!
    private var lastDirection: String = "down"
    
    init(inputIndex: Int) {
        let atlas = SKTextureAtlas(named: "luminous_wisp")
        let firstFrame = atlas.textureNamed("luminous_wisp_down_idle_000")
        
        super.init(texture: firstFrame, health: GameConfig.basePlayerHealth)
        self.controllerIndex = inputIndex == 0 ? nil : inputIndex
        self.name = "LuminousWisp"
        
        setupAnimations()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
    
    private func setupAnimations() {
        animator = AnimationComponent(atlasName: "luminous_wisp", owner: self, canMirror: false)
        
        let directions = ["up", "down", "left", "right", "up_left", "up_right", "down_left", "down_right"]
        let actions = ["idle", "walk", "shoot"]
        
        for direction in directions {
            for action in actions {
                animator.loadAnimation(name: "luminous_wisp_\(direction)_\(action)", frameCount: 6)
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
        let isShooting = attack?.isShooting ?? false
        let hasAim = aimDirection != .zero
        
        if hasAim {
            lastDirection = animator.setDirection(dx: aimDirection.dx, dy: aimDirection.dy)
        } else if isMoving {
            lastDirection = animator.setDirection(dx: movement.dx, dy: movement.dy)
        }

        let action: String
        if isShooting {
            action = "shoot"
        } else if isMoving {
            action = "walk"
        } else {
            action = "idle"
        }

        animator.play(animation: "luminous_wisp_\(lastDirection)_\(action)", timePerFrame: 0.1, repeat: true)
    }
}
