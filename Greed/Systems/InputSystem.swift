import GameController
import SpriteKit

final class InputSystem {
    static let shared = InputSystem()
    
    private var controllers: [GCController] = []

    private var keysDown: Set<KeyCode> = []
    private var mouseWorldPosition: CGPoint = .zero
    private var lastMouseMoveTime: TimeInterval = 0

    private var autoAimActive: [Bool] = []

    func setup() {
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

    func confirmPressed(for playerIndex: Int) -> Bool {
        if playerIndex == 0, controllers.isEmpty {
            return false
        }
        guard let controller = controller(for: playerIndex) else {
            return false
        }
        return controller.extendedGamepad?.buttonA.isPressed ?? false
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

    private func mouseAimVector(playerWorldPos: CGPoint, gnomes: [EnemyEntity])
        -> CGVector
    {
        let idle =
            CACurrentMediaTime() - lastMouseMoveTime
            > GameConfig.autoAimIdleThreshold
        if idle {
            return autoAimVector(from: playerWorldPos, gnomes: gnomes)
        }
        let diff = CGVector(
            dx: mouseWorldPosition.x - playerWorldPos.x,
            dy: mouseWorldPosition.y - playerWorldPos.y
        )
        return magnitude(diff) > 1 ? normalised(diff) : .zero
    }

    private func autoAimVector(from origin: CGPoint, gnomes: [EnemyEntity])
        -> CGVector
    {
        guard !gnomes.isEmpty else { return .zero }

        let nearest = gnomes.min {
            toroidalDistance(
                from: origin,
                to: $0.position,
                mapSize: GameConfig.mapSize
            )
                < toroidalDistance(
                    from: origin,
                    to: $1.position,
                    mapSize: GameConfig.mapSize
                )
        }
        guard let target = nearest else { return .zero }

        let offset = toroidalOffset(
            from: origin,
            to: target.position,
            mapSize: GameConfig.mapSize
        )
        return magnitude(offset) > 0 ? normalised(offset) : .zero
    }

    private func register(_ controller: GCController) {
        guard !controllers.contains(where: { $0 === controller }) else {
            return
        }
        controllers.append(controller)
        Log.debug(
            "InputSystem: controller connected — \(controller.vendorName ?? "unknown")"
        )
    }

    private func controller(for playerIndex: Int) -> GCController? {
        let controllerIndex = controllers.isEmpty ? playerIndex : playerIndex
        guard controllerIndex < controllers.count else { return nil }
        return controllers[controllerIndex]
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
        Log.debug(
            "InputSystem: controller disconnected — \(controller.vendorName ?? "unknown")"
        )
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
