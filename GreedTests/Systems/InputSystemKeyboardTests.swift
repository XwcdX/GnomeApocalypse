import AppKit
import Testing

@testable import Greed

@MainActor
@Suite("InputSystem keyboard input")
struct InputSystemKeyboardTests {
    @Test("WASD keyDown events are consumed and update movement")
    func wasdKeyDownEventsAreConsumedAndUpdateMovement() throws {
        let cases: [(UInt16, CGVector)] = [
            (13, CGVector(dx: 0, dy: 1)),
            (0, CGVector(dx: -1, dy: 0)),
            (1, CGVector(dx: 0, dy: -1)),
            (2, CGVector(dx: 1, dy: 0))
        ]

        for (keyCode, expectedMovement) in cases {
            let input = InputSystem()

            let consumed = input.keyDown(with: try keyEvent(type: .keyDown, keyCode: keyCode))

            #expect(consumed)
            expect(input.movementVector(for: 0), equals: expectedMovement)
        }
    }

    @Test("WASD keyUp events are consumed and clear movement")
    func wasdKeyUpEventsAreConsumedAndClearMovement() throws {
        let input = InputSystem()
        #expect(input.keyDown(with: try keyEvent(type: .keyDown, keyCode: 13)))
        expect(input.movementVector(for: 0), equals: CGVector(dx: 0, dy: 1))

        let consumed = input.keyUp(with: try keyEvent(type: .keyUp, keyCode: 13))

        #expect(consumed)
        expect(input.movementVector(for: 0), equals: .zero)
    }

    @Test("unrelated keys are not consumed and do not affect movement")
    func unrelatedKeysAreNotConsumedAndDoNotAffectMovement() throws {
        let input = InputSystem()

        let consumed = input.keyDown(with: try keyEvent(type: .keyDown, keyCode: 49))

        #expect(!consumed)
        expect(input.movementVector(for: 0), equals: .zero)
    }

    @Test("command-modified movement keys are not consumed or held")
    func commandModifiedMovementKeysAreNotConsumedOrHeld() throws {
        let input = InputSystem()

        let consumed = input.keyDown(
            with: try keyEvent(type: .keyDown, keyCode: 13, modifierFlags: .command)
        )

        #expect(!consumed)
        expect(input.movementVector(for: 0), equals: .zero)
    }

    @Test("shift-modified movement keys are consumed")
    func shiftModifiedMovementKeysAreConsumed() throws {
        let input = InputSystem()

        let consumed = input.keyDown(
            with: try keyEvent(type: .keyDown, keyCode: 13, modifierFlags: .shift)
        )

        #expect(consumed)
        expect(input.movementVector(for: 0), equals: CGVector(dx: 0, dy: 1))
    }

    private func keyEvent(
        type: NSEvent.EventType,
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags = []
    ) throws -> NSEvent {
        let character = characterIgnoringModifiers(for: keyCode)
        return try #require(NSEvent.keyEvent(
            with: type,
            location: .zero,
            modifierFlags: modifierFlags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: character,
            charactersIgnoringModifiers: character,
            isARepeat: false,
            keyCode: keyCode
        ))
    }

    private func characterIgnoringModifiers(for keyCode: UInt16) -> String {
        switch keyCode {
        case 13: return "w"
        case 0: return "a"
        case 1: return "s"
        case 2: return "d"
        default: return " "
        }
    }

    private func expect(_ actual: CGVector, equals expected: CGVector) {
        #expect(abs(actual.dx - expected.dx) < 0.001)
        #expect(abs(actual.dy - expected.dy) < 0.001)
    }
}
