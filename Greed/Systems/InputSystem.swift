import GameController
import SpriteKit

final class InputSystem {
    enum AimMode {
        case auto
        case manual
    }

    enum MenuDirection {
        case left
        case right
        case up
        case down
    }

    static let shared = InputSystem()

    private struct MenuInputState {
        var heldDirection: MenuDirection?
        var nextDirectionRepeatTime: TimeInterval = 0
        var isConfirmHeld = false
        var isAnyButtonHeld = false
    }
    
    private var controllers: [GCController] = []
    private var isSetup = false
    private var menuInputStates: [Int: MenuInputState] = [:]

    private var keysDown: Set<KeyCode> = []
    private var mouseWorldPosition: CGPoint = .zero
    private var lastMouseMoveTime: TimeInterval = -GameConfig.autoAimIdleThreshold - 1
    private var hasMouseMovedSinceGuideReset = false
    private var ignoreControlGuideInputUntil: TimeInterval = 0

    private let menuDeadzone: Float = 0.55
    private let menuInitialRepeatDelay: TimeInterval = 0.32
    private let menuRepeatInterval: TimeInterval = 0.14

    var hasConnectedController: Bool {
        !controllers.isEmpty
    }

    func setup() {
        guard !isSetup else { return }
        isSetup = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerConnected(_:)),
            name: .GCControllerDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDisconnected(_:)),
            name: .GCControllerDidDisconnect,
            object: nil
        )

        for controller in GCController.controllers() {
            register(controller)
        }
    }

    func movementVector(for playerIndex: Int) -> CGVector {
        if playerIndex == 0, controllers.isEmpty {
            return keyboardMovementVector()
        }
        guard let controller = controller(for: playerIndex),
            let stick = controller.extendedGamepad?.leftThumbstick
        else { return .zero }

        let v = CGVector(
            dx: CGFloat(stick.xAxis.value),
            dy: CGFloat(stick.yAxis.value)
        )
        return magnitude(v) > GameConfig.stickDeadzone ? normalised(v) : .zero
    }

    func aimVector(
        for playerIndex: Int,
        playerWorldPos: CGPoint,
        gnomes: [EnemyEntity]
    ) -> CGVector {
        if playerIndex == 0, controllers.isEmpty {
            return mouseAimVector(
                playerWorldPos: playerWorldPos,
                gnomes: gnomes
            )
        }
        guard let controller = controller(for: playerIndex),
            let stick = controller.extendedGamepad?.rightThumbstick
        else { return .zero }

        let v = CGVector(
            dx: CGFloat(stick.xAxis.value),
            dy: CGFloat(stick.yAxis.value)
        )
        if magnitude(v) >= GameConfig.stickDeadzone {
            return normalised(v)
        }
        return autoAimVector(from: playerWorldPos, gnomes: gnomes)
    }

    func aimMode(for playerIndex: Int) -> AimMode {
        if playerIndex == 0, controllers.isEmpty {
            let hasMoved = lastMouseMoveTime > 0
            let idle = !hasMoved || CACurrentMediaTime() - lastMouseMoveTime > GameConfig.autoAimIdleThreshold
            return idle ? .auto : .manual
        }

        guard let controller = controller(for: playerIndex),
              let stick = controller.extendedGamepad?.rightThumbstick
        else { return .auto }

        let v = CGVector(
            dx: CGFloat(stick.xAxis.value),
            dy: CGFloat(stick.yAxis.value)
        )
        return magnitude(v) >= GameConfig.stickDeadzone ? .manual : .auto
    }

    func confirmPressed(for playerIndex: Int) -> Bool {
        if playerIndex == 0, controllers.isEmpty {
            return false
        }
        guard let controller = controller(for: playerIndex),
              let gamepad = controller.extendedGamepad
        else {
            return false
        }
        return confirmButton(on: gamepad, controller: controller).isPressed
    }

    func consumeMenuDirection(for playerIndex: Int) -> MenuDirection? {
        guard let controller = controller(for: playerIndex),
              let gamepad = controller.extendedGamepad
        else { return nil }

        let direction = menuDirection(from: gamepad)
        var state = menuInputStates[playerIndex] ?? MenuInputState()
        let now = CACurrentMediaTime()

        guard let direction else {
            state.heldDirection = nil
            state.nextDirectionRepeatTime = 0
            menuInputStates[playerIndex] = state
            return nil
        }

        if state.heldDirection == direction {
            guard now >= state.nextDirectionRepeatTime else {
                menuInputStates[playerIndex] = state
                return nil
            }
            state.nextDirectionRepeatTime = now + menuRepeatInterval
            menuInputStates[playerIndex] = state
            return direction
        }

        state.heldDirection = direction
        state.nextDirectionRepeatTime = now + menuInitialRepeatDelay
        menuInputStates[playerIndex] = state
        return direction
    }

    func consumeMenuConfirm(for playerIndex: Int) -> Bool {
        guard let controller = controller(for: playerIndex),
              let gamepad = controller.extendedGamepad
        else { return false }

        var state = menuInputStates[playerIndex] ?? MenuInputState()
        let isPressed = confirmButton(on: gamepad, controller: controller).isPressed
        defer {
            state.isConfirmHeld = isPressed
            menuInputStates[playerIndex] = state
        }

        return isPressed && !state.isConfirmHeld
    }

    func consumeAnyMenuButton(for playerIndex: Int) -> Bool {
        guard let controller = controller(for: playerIndex),
              let gamepad = controller.extendedGamepad
        else { return false }

        var state = menuInputStates[playerIndex] ?? MenuInputState()
        let isPressed = anyButtonPressed(on: gamepad)
        defer {
            state.isAnyButtonHeld = isPressed
            menuInputStates[playerIndex] = state
        }

        return isPressed && !state.isAnyButtonHeld
    }

    func resetControlGuideTracking() {
        hasMouseMovedSinceGuideReset = false
        ignoreControlGuideInputUntil = CACurrentMediaTime() + 0.35
    }

    func hasControlGuideDismissInput(for playerIndex: Int) -> Bool {
        guard CACurrentMediaTime() >= ignoreControlGuideInputUntil else {
            return false
        }

        if playerIndex == 0, controllers.isEmpty {
            return hasKeyboardMovementInput || hasMouseMovedSinceGuideReset
        }

        guard let controller = controller(for: playerIndex),
              let gamepad = controller.extendedGamepad
        else { return false }

        let leftStick = CGVector(
            dx: CGFloat(gamepad.leftThumbstick.xAxis.value),
            dy: CGFloat(gamepad.leftThumbstick.yAxis.value)
        )
        let rightStick = CGVector(
            dx: CGFloat(gamepad.rightThumbstick.xAxis.value),
            dy: CGFloat(gamepad.rightThumbstick.yAxis.value)
        )
        return magnitude(leftStick) >= GameConfig.stickDeadzone
            || magnitude(rightStick) >= GameConfig.stickDeadzone
    }

    func keyDown(with event: NSEvent) {
        guard let key = KeyCode(rawValue: event.keyCode) else { return }
        keysDown.insert(key)
    }

    func keyUp(with event: NSEvent) {
        guard let key = KeyCode(rawValue: event.keyCode) else { return }
        keysDown.remove(key)
    }

    func mouseMoved(to worldPosition: CGPoint) {
        mouseWorldPosition = worldPosition
        lastMouseMoveTime = CACurrentMediaTime()
        if lastMouseMoveTime >= ignoreControlGuideInputUntil {
            hasMouseMovedSinceGuideReset = true
        }
    }

    private var hasKeyboardMovementInput: Bool {
        keysDown.contains(.w)
            || keysDown.contains(.a)
            || keysDown.contains(.s)
            || keysDown.contains(.d)
    }

    private func keyboardMovementVector() -> CGVector {
        var dx: CGFloat = 0
        var dy: CGFloat = 0
        if keysDown.contains(.a) { dx -= 1 }
        if keysDown.contains(.d) { dx += 1 }
        if keysDown.contains(.s) { dy -= 1 }
        if keysDown.contains(.w) { dy += 1 }
        let v = CGVector(dx: dx, dy: dy)
        return magnitude(v) > 0 ? normalised(v) : .zero
    }

    private func mouseAimVector(playerWorldPos: CGPoint, gnomes: [EnemyEntity]) -> CGVector {
        let hasMoved = lastMouseMoveTime > 0
        let idle = !hasMoved || CACurrentMediaTime() - lastMouseMoveTime > GameConfig.autoAimIdleThreshold

        if idle {
            return autoAimVector(from: playerWorldPos, gnomes: gnomes)
        }
        let diff = CGVector(
            dx: mouseWorldPosition.x - playerWorldPos.x,
            dy: mouseWorldPosition.y - playerWorldPos.y
        )
        return magnitude(diff) > 1 ? normalised(diff) : .zero
    }

    private func autoAimVector(from origin: CGPoint, gnomes: [EnemyEntity]) -> CGVector {
        guard !gnomes.isEmpty else { return .zero }

        let nearest = gnomes
            .filter { toroidalDistance(from: origin, to: $0.position, mapSize: GameConfig.mapSize) <= GameConfig.autoAimMaxRange }
            .min { toroidalDistance(from: origin, to: $0.position, mapSize: GameConfig.mapSize) < toroidalDistance(from: origin, to: $1.position, mapSize: GameConfig.mapSize) }

        guard let target = nearest else { return .zero }
        let offset = toroidalOffset(from: origin, to: target.position, mapSize: GameConfig.mapSize)
        return magnitude(offset) > 0 ? normalised(offset) : .zero
    }

    private func register(_ controller: GCController) {
        guard !controllers.contains(where: { $0 === controller }) else {
            return
        }
        controllers.append(controller)
        menuInputStates[controllers.count - 1] = MenuInputState()
        let faceButtonNames = controller.extendedGamepad.map { gamepad in
            "buttonA=\(buttonDebugName(gamepad.buttonA)), buttonB=\(buttonDebugName(gamepad.buttonB))"
        } ?? "no extended gamepad"
        let confirmButtonName = usesNintendoPhysicalFaceLayout(controller) ? "buttonB" : "buttonA"
        Log.debug(
            "InputSystem: controller connected — \(controller.vendorName ?? "unknown"), product=\(controller.productCategory), confirm=\(confirmButtonName), \(faceButtonNames)"
        )
    }

    private func controller(for playerIndex: Int) -> GCController? {
        guard playerIndex < controllers.count else { return nil }
        return controllers[playerIndex]
    }

    @objc private func controllerConnected(_ notification: Notification) {
        guard let controller = notification.object as? GCController else {
            return
        }
        register(controller)
    }

    @objc private func controllerDisconnected(_ notification: Notification) {
        guard let controller = notification.object as? GCController else {
            return
        }
        controllers.removeAll { $0 === controller }
        menuInputStates.removeAll()
        Log.debug(
            "InputSystem: controller disconnected — \(controller.vendorName ?? "unknown")"
        )
    }

    private func menuDirection(from gamepad: GCExtendedGamepad) -> MenuDirection? {
        let dpadX = gamepad.dpad.xAxis.value
        let dpadY = gamepad.dpad.yAxis.value
        if abs(dpadX) >= menuDeadzone || abs(dpadY) >= menuDeadzone {
            return dominantDirection(x: dpadX, y: dpadY)
        }

        let stickX = gamepad.leftThumbstick.xAxis.value
        let stickY = gamepad.leftThumbstick.yAxis.value
        guard abs(stickX) >= menuDeadzone || abs(stickY) >= menuDeadzone else {
            return nil
        }
        return dominantDirection(x: stickX, y: stickY)
    }

    private func anyButtonPressed(on gamepad: GCExtendedGamepad) -> Bool {
        gamepad.buttonA.isPressed
            || gamepad.buttonB.isPressed
            || gamepad.buttonX.isPressed
            || gamepad.buttonY.isPressed
            || gamepad.leftShoulder.isPressed
            || gamepad.rightShoulder.isPressed
            || gamepad.leftTrigger.isPressed
            || gamepad.rightTrigger.isPressed
    }

    private func confirmButton(on gamepad: GCExtendedGamepad, controller: GCController) -> GCControllerButtonInput {
        if usesNintendoPhysicalFaceLayout(controller) {
            return gamepad.buttonB
        }
        if buttonIsLabeledA(gamepad.buttonB), !buttonIsLabeledA(gamepad.buttonA) {
            return gamepad.buttonB
        }
        return gamepad.buttonA
    }

    private func usesNintendoPhysicalFaceLayout(_ controller: GCController) -> Bool {
        let productCategory = controller.productCategory.lowercased()
        let vendorName = controller.vendorName?.lowercased() ?? ""
        return productCategory.contains("switch")
            || productCategory.contains("joy-con")
            || productCategory.contains("nintendo")
            || vendorName.contains("nintendo")
    }

    private func buttonIsLabeledA(_ button: GCControllerButtonInput) -> Bool {
        [
            button.localizedName,
            button.unmappedLocalizedName,
            button.sfSymbolsName,
            button.unmappedSfSymbolsName
        ]
        .compactMap { $0 }
        .contains { inputNameRepresentsA($0) }
    }

    private func inputNameRepresentsA(_ name: String) -> Bool {
        let tokens = name
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
        return tokens.contains("a")
    }

    private func buttonDebugName(_ button: GCControllerButtonInput) -> String {
        [
            button.localizedName,
            button.unmappedLocalizedName,
            button.sfSymbolsName,
            button.unmappedSfSymbolsName
        ]
        .compactMap { $0 }
        .joined(separator: "/")
    }

    private func dominantDirection(x: Float, y: Float) -> MenuDirection {
        if abs(x) >= abs(y) {
            return x < 0 ? .left : .right
        }
        return y < 0 ? .down : .up
    }

    private func magnitude(_ v: CGVector) -> CGFloat {
        sqrt(v.dx * v.dx + v.dy * v.dy)
    }

    private func normalised(_ v: CGVector) -> CGVector {
        let m = magnitude(v)
        guard m > 0 else { return .zero }
        return CGVector(dx: v.dx / m, dy: v.dy / m)
    }
}

private enum KeyCode: UInt16 {
    case w = 13
    case a = 0
    case s = 1
    case d = 2
}
