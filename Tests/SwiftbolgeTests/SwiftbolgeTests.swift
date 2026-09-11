import XCTest
@testable import SwiftbolgeCore
import Foundation

final class SwiftbolgeTests: XCTestCase {

    static func helloCells() -> [UInt32] {
        let url = Bundle.module.url(forResource: "fixtures/hello_classic", withExtension: "mal")!
        return try! loadProgram([UInt8](Data(contentsOf: url)))
    }

    // MARK: - M3: the gate (same as Rustbolge and Malbolge-Engine)

    func testHelloWorldGate() {
        let m = Machine(cells: Self.helloCells())
        m.run(input: [], maxSteps: 100_000_000)
        XCTAssertEqual(String(bytes: m.output, encoding: .utf8), "Hello, world.")
        XCTAssertEqual(m.steps, 48)
        XCTAssertEqual(m.haltReason, .vInstruction)
        // exact final registers, shared with Malbolge-Engine and Rustbolge
        XCTAssertEqual(m.a, 19758)
        XCTAssertEqual(m.c, 85)
        XCTAssertEqual(m.d, 63)
    }

    func testLoaderRejectsBinary() {
        XCTAssertNoThrow(try loadProgram(Array("(= \n\t ]}".utf8)))
        XCTAssertThrowsError(try loadProgram([0x07])) { error in
            guard case .invalidCharacter(0x07) = error as! LoadError else {
                return XCTFail("wrong error")
            }
        }
        XCTAssertThrowsError(try loadProgram([0xC3, 0xA9]))
    }

    // MARK: - M5: snapshot/resume bit-exact vs one-shot

    func testSnapshotResumeIsBitExact() {
        let full = Machine(cells: Self.helloCells())
        full.run(input: [], maxSteps: 1_000_000)

        let first = Machine(cells: Self.helloCells())
        first.run(input: [], maxSteps: 17)
        let data = try! JSONEncoder().encode(first.snapshot())
        let snap = try! JSONDecoder().decode(Snapshot.self, from: data)
        let resumed = Machine(snapshot: snap)
        resumed.run(input: [], maxSteps: 1_000_000)

        XCTAssertEqual(full.output, resumed.output)
        XCTAssertEqual(full.steps, resumed.steps)
        XCTAssertEqual(full.a, resumed.a)
        XCTAssertEqual(full.c, resumed.c)
        XCTAssertEqual(full.d, resumed.d)
        XCTAssertEqual(full.halted, resumed.halted)
    }

    func testSnapshotHaltSurvivesJSON() {
        let m = Machine(cells: Self.helloCells())
        m.run(input: [], maxSteps: 1_000_000)
        XCTAssertTrue(m.halted)
        let data = try! JSONEncoder().encode(m.snapshot())
        let m2 = Machine(snapshot: try! JSONDecoder().decode(Snapshot.self, from: data))
        XCTAssertEqual(m2.haltReason, .restoredHalted)
    }

    // MARK: - M5b: cross-language snapshot â€” resume a REAL Rustbolge snapshot

    func testRustbolgeSnapshotResumesIdentically() throws {
        let url = Bundle.module.url(forResource: "fixtures/rust_step17_snapshot",
                                    withExtension: "json")!
        let snap = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))

        // Rustbolge wrote this snapshot after 17 steps of hello_classic.mal
        // with stdout "Hello" (5 bytes) already emitted.
        XCTAssertEqual(snap.steps, 17)
        XCTAssertEqual(String(bytes: snap.output, encoding: .utf8), "Hello")

        let m = Machine(snapshot: snap)
        let reason = m.run(input: [], maxSteps: 1_000_000)

        // Must land on the exact same final state as the one-shot runs of
        // every other VM in the family.
        XCTAssertEqual(reason, .vInstruction)
        XCTAssertEqual(m.steps, 48)
        XCTAssertEqual(String(bytes: m.output, encoding: .utf8), "Hello, world.")
        XCTAssertEqual(m.a, 19758)
        XCTAssertEqual(m.c, 85)
        XCTAssertEqual(m.d, 63)
    }
}
