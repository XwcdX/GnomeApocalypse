import AppKit
import SpriteKit

private let levelUpOverlayDelay: TimeInterval = 0.35

/// Coordinates gameplay overlays, their input routing, and their viewport lifecycle.
final class OverlayFlowController {
    enum UpdateResult {
        case none
        case blocked
        case resetGameplayClock
    }

    var onReplayRequested: (() -> Void)?
    var onAimModeChanged: ((InputSystem.AimMode) -> Void)?
    var onGameOverPresented: (() -> Void)?

    private let skillSystem: SkillSystem
    private let inputSystem: InputSystem
    private let audioManager: AudioManager

    private var skillCardOverlay: SkillCardOverlay?
    private var gameOverOverlay: GameOverOverlay?
    private var startCountdownOverlay: StartCountdownOverlay?
    private weak var skillSelectionPlayer: PlayerEntity?
    private weak var pendingSkillSelectionPlayer: PlayerEntity?
    private var pendingSkillSelectionDelay: TimeInterval = 0
    private var wasSkillConfirmPressed = false
    private var lastReportedAimMode: InputSystem.AimMode?
    private var needsGameplayClockReset = false

    init(
        skillSystem: SkillSystem = SkillSystem(),
        inputSystem: InputSystem = .shared,
        audioManager: AudioManager = .shared
    ) {
        self.skillSystem = skillSystem
        self.inputSystem = inputSystem
        self.audioManager = audioManager
    }

    func updateBeforeGameplay(
        deltaTime: TimeInterval,
        screenSize: CGSize,
        elapsedRunTime: TimeInterval,
        hud: HUD,
        players: [PlayerEntity],
        refreshWorldRenderers: () -> Void,
        updateYSort: () -> Void
    ) -> UpdateResult {
        if skillCardOverlay != nil {
            updateSkillSelectionInput()
            return consumeClockResetResult(fallback: .blocked)
        }

        if gameOverOverlay != nil {
            updateGameOverInput(players: players)
            return .blocked
        }

        if let startCountdownOverlay {
            hud.updateViewport(screenSize)
            hud.update(elapsedTime: elapsedRunTime)
            refreshWorldRenderers()
            updateYSort()

            if startCountdownOverlay.update(deltaTime: deltaTime) {
                self.startCountdownOverlay = nil
                return .resetGameplayClock
            }
            return .blocked
        }

        return .none
    }

    func updatePendingSkillSelection(deltaTime: TimeInterval, screenSize: CGSize, cameraNode: SKNode) {
        guard skillCardOverlay == nil, gameOverOverlay == nil, let player = pendingSkillSelectionPlayer else { return }
        pendingSkillSelectionDelay = max(0, pendingSkillSelectionDelay - deltaTime)
        guard pendingSkillSelectionDelay == 0 else { return }

        pendingSkillSelectionPlayer = nil
        skillSelectionPlayer = player
        presentSkillCardOverlay(screenSize: screenSize, cameraNode: cameraNode)
    }

    func presentStartCountdown(screenSize: CGSize, cameraNode: SKNode) {
        let overlay = StartCountdownOverlay(screenSize: screenSize)
        cameraNode.addChild(overlay)
        startCountdownOverlay = overlay
    }

    func updateViewport(_ screenSize: CGSize) {
        skillCardOverlay?.updateViewport(screenSize)
        gameOverOverlay?.updateViewport(screenSize)
        startCountdownOverlay?.updateViewport(screenSize)
    }

    func handleLevelUp(for player: PlayerEntity, hud: HUD) {
        Log.debug("GameScene: player leveled up to \(player.level.currentLevel)")
        guard skillCardOverlay == nil, pendingSkillSelectionPlayer == nil else { return }
        audioManager.play(.levelUp)
        hud.showFullEssenceBriefly(duration: levelUpOverlayDelay)
        pendingSkillSelectionPlayer = player
        pendingSkillSelectionDelay = levelUpOverlayDelay
    }

    func presentGameOver(
        for player: PlayerEntity,
        players: [PlayerEntity],
        physicsWorld: SKPhysicsWorld,
        elapsedRunTime: TimeInterval,
        screenSize: CGSize,
        cameraNode: SKNode,
        stats: GameOverStats
    ) {
        guard gameOverOverlay == nil else { return }
        skillCardOverlay?.removeFromParent()
        skillCardOverlay = nil
        skillSelectionPlayer = nil
        pendingSkillSelectionPlayer = nil
        pendingSkillSelectionDelay = 0
        players.forEach { $0.hideAimGuide() }
        physicsWorld.speed = 0
        onGameOverPresented?()

        let overlay = GameOverOverlay(
            survivedTime: elapsedRunTime,
            screenSize: screenSize,
            stats: stats,
            usesControllerPrompt: inputSystem.hasConnectedController
        ) { [weak self] in
            self?.onReplayRequested?()
        }
        cameraNode.addChild(overlay)
        gameOverOverlay = overlay
    }

    @discardableResult
    func handleMouseDown(atViewPosition viewPosition: CGPoint, viewSize: CGSize, screenSize: CGSize) -> Bool {
        guard viewSize.width > 0, viewSize.height > 0 else { return true }
        let overlayPoint = overlayPoint(from: viewPosition, viewSize: viewSize, screenSize: screenSize)

        if let gameOverOverlay {
            return gameOverOverlay.handleMouseDown(at: overlayPoint)
        }

        guard let skillCardOverlay else { return false }
        let handled = skillCardOverlay.handleMouseDown(at: overlayPoint)
        return handled
    }

    @discardableResult
    func handleMouseMoved(atViewPosition viewPosition: CGPoint, viewSize: CGSize, screenSize: CGSize) -> Bool {
        guard viewSize.width > 0, viewSize.height > 0 else { return true }
        let overlayPoint = overlayPoint(from: viewPosition, viewSize: viewSize, screenSize: screenSize)

        if let gameOverOverlay {
            return gameOverOverlay.handleMouseMoved(at: overlayPoint)
        }

        guard let skillCardOverlay else { return false }
        return skillCardOverlay.handleMouseMoved(at: overlayPoint)
    }

    @discardableResult
    func handleKeyDown(_ event: NSEvent) -> Bool {
        if gameOverOverlay != nil {
            return true
        }
        guard let skillCardOverlay else { return false }

        let shortcutModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        guard event.modifierFlags.intersection(shortcutModifiers).isEmpty else { return true }

        switch event.keyCode {
        case 0:
            skillCardOverlay.moveSelection(.left)
        case 2:
            skillCardOverlay.moveSelection(.right)
        case 36, 49:
            skillCardOverlay.selectHighlightedCard()
        default:
            break
        }
        return true
    }

    func consumeNeedsGameplayClockReset() -> Bool {
        guard needsGameplayClockReset else { return false }
        needsGameplayClockReset = false
        return true
    }

    func updateAimCursorMode(players: [PlayerEntity]) {
        let mode = inputSystem.aimMode(for: players.first?.controllerIndex ?? 0)
        guard mode != lastReportedAimMode else { return }
        lastReportedAimMode = mode
        onAimModeChanged?(mode)
    }

    private func presentSkillCardOverlay(screenSize: CGSize, cameraNode: SKNode) {
        guard let player = skillSelectionPlayer else { return }
        player.hideAimGuide()

        let skills = skillSystem.draw(for: player.skillState)
        guard !skills.isEmpty else {
            skillSelectionPlayer = nil
            return
        }

        let skillLevels = Dictionary(uniqueKeysWithValues: skills.map { skill in
            (skill.id, player.skillState.level(of: skill.id, type: skill.type))
        })

        let overlay = SkillCardOverlay(skills: skills, skillLevels: skillLevels, screenSize: screenSize) { [weak self, weak player] skill in
            guard let self, let player else { return }
            self.completeSkillSelection(skill, for: player)
        }
        cameraNode.addChild(overlay)
        skillCardOverlay = overlay
        wasSkillConfirmPressed = inputSystem.confirmPressed(for: player.controllerIndex ?? 0)
        lastReportedAimMode = .manual
        onAimModeChanged?(.manual)
    }

    private func completeSkillSelection(_ skill: Skill, for player: PlayerEntity) {
        player.applySkill(skill)
        audioManager.play(.pickPower)
        skillCardOverlay?.removeFromParent()
        skillCardOverlay = nil
        skillSelectionPlayer = nil
        wasSkillConfirmPressed = false
        needsGameplayClockReset = true
        lastReportedAimMode = nil
    }

    private func updateSkillSelectionInput() {
        guard let player = skillSelectionPlayer else { return }
        if let direction = inputSystem.consumeMenuDirection(for: player.controllerIndex ?? 0) {
            skillCardOverlay?.moveSelection(direction)
        }
        if inputSystem.consumeMenuConfirm(for: player.controllerIndex ?? 0) {
            skillCardOverlay?.selectHighlightedCard()
            return
        }

        let isConfirmPressed = inputSystem.confirmPressed(for: player.controllerIndex ?? 0)
        if isConfirmPressed && !wasSkillConfirmPressed {
            skillCardOverlay?.selectHighlightedCard()
        }
        wasSkillConfirmPressed = isConfirmPressed
    }

    private func updateGameOverInput(players: [PlayerEntity]) {
        let playerIndex = players.first?.controllerIndex ?? 0
        if inputSystem.consumeAnyMenuButton(for: playerIndex) {
            gameOverOverlay?.replay()
        }
    }

    private func overlayPoint(from viewPosition: CGPoint, viewSize: CGSize, screenSize: CGSize) -> CGPoint {
        CGPoint(
            x: (viewPosition.x / viewSize.width) * screenSize.width - screenSize.width / 2,
            y: (viewPosition.y / viewSize.height) * screenSize.height - screenSize.height / 2
        )
    }

    private func consumeClockResetResult(fallback defaultResult: UpdateResult) -> UpdateResult {
        guard needsGameplayClockReset else { return defaultResult }
        needsGameplayClockReset = false
        return .resetGameplayClock
    }
}
