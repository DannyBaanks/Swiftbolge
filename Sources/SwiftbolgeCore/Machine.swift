// Swiftbolge — Classic Malbolge engine in Swift, semantic port of
// Malbolge-Engine vm.c (same as Rustbolge), with snapshot/resume whose JSON
// schema is byte-compatible with Rustbolge's: a Rustbolge snapshot resumes
// under Swiftbolge and vice versa.

import Foundation

public let MEM_SIZE: UInt32 = 59049
public let LAST: UInt32 = MEM_SIZE - 1
public let POW9: UInt32 = 19683
public let HALF: UInt32 = 243
public let BLOCK_SIZE: UInt32 = 243
public let OUT_CAP = 65536

public let ENCRYPT: [UInt8] = Array(
    "5z]&gqtyfr$(we4{WP)H-Zn,[%\\3dL+Q;>U!pJS72FhOA1CB6v^=I_0/8|jsb9m<.TVac`uY*MK'X~xDl}REokN:#?G\"i@".utf8)

private let CRAZY_TBL: [[UInt8]] = [[1, 0, 0], [1, 0, 2], [2, 2, 1]]

private func buildCrazy5() -> [[UInt32]] {
    var tbl = [[UInt32]](repeating: [UInt32](repeating: 0, count: Int(HALF)),
                         count: Int(HALF))
    for a5 in 0..<Int(HALF) {
        for b5 in 0..<Int(HALF) {
            var r: UInt32 = 0, p: UInt32 = 1
            var aa = UInt32(a5), bb = UInt32(b5)
            for _ in 0..<5 {
                r += UInt32(CRAZY_TBL[Int(bb % 3)][Int(aa % 3)]) * p
                aa /= 3
                bb /= 3
                p *= 3
            }
            tbl[a5][b5] = r
        }
    }
    return tbl
}

public func crazy(_ a: UInt32, _ b: UInt32, _ crazy5: [[UInt32]]) -> UInt32 {
    crazy5[Int(a % HALF)][Int(b % HALF)] + HALF * crazy5[Int(a / HALF)][Int(b / HALF)]
}

public func rotate(_ n: UInt32) -> UInt32 {
    POW9 * (n % 3) + n / 3
}

public enum HaltReason: String {
    case vInstruction = "VInstruction"
    case invalidCell = "InvalidCell"
    case eof = "Eof"
    case stepsExhausted = "StepsExhausted"
    case restoredHalted = "RestoredHalted"
}

/// JSON-compatible with Rustbolge's `Snapshot` (serde): overlay is an array
/// of [addr, value] pairs, sorted by address, exactly like serde does.
public struct Snapshot: Codable {
    public var a: UInt32
    public var c: UInt32
    public var d: UInt32
    public var halted: Bool
    public var steps: UInt64
    public var input_pos: UInt64
    public var output: [UInt8]
    public var fill_start: UInt32
    public var chain_until: UInt32
    public var chain: [UInt32]
    public var overlay: [[UInt32]]
}

public final class Machine {
    public private(set) var a: UInt32 = 0
    public private(set) var c: UInt32 = 0
    public private(set) var d: UInt32 = 0
    public private(set) var halted = false
    public private(set) var haltReason: HaltReason?
    public private(set) var steps: UInt64 = 0
    public private(set) var inputPos = 0
    public private(set) var output: [UInt8] = []

    private var fillStart: UInt32
    private var chainUntil: UInt32
    private var chain: [UInt32]
    private var overlay: [UInt32: UInt32]
    private let crazy5: [[UInt32]]

    public init(cells: [UInt32]) {
        let fs: UInt32 = cells.count > 2 ? UInt32(cells.count) : 2
        fillStart = fs
        chainUntil = fs
        chain = [UInt32](repeating: 0, count: Int(MEM_SIZE))
        overlay = [UInt32: UInt32](minimumCapacity: cells.count)
        for (i, cell) in cells.enumerated() {
            overlay[UInt32(i)] = cell
        }
        crazy5 = buildCrazy5()
    }

    public init(snapshot s: Snapshot) {
        a = s.a; c = s.c; d = s.d
        halted = s.halted
        haltReason = s.halted ? .restoredHalted : nil
        steps = s.steps
        inputPos = Int(s.input_pos)
        output = s.output
        fillStart = s.fill_start
        chainUntil = s.chain_until
        chain = [UInt32](repeating: 0, count: Int(MEM_SIZE))
        chain.replaceSubrange(0..<s.chain.count, with: s.chain)
        overlay = [:]
        for pair in s.overlay { overlay[pair[0]] = pair[1] }
        crazy5 = buildCrazy5()
    }

    public func snapshot() -> Snapshot {
        let pairs = overlay.keys.sorted().map { [$0, overlay[$0]!] }
        return Snapshot(a: a, c: c, d: d, halted: halted, steps: steps,
                        input_pos: UInt64(inputPos), output: output,
                        fill_start: fillStart, chain_until: chainUntil,
                        chain: Array(chain[0..<Int(chainUntil)]),
                        overlay: pairs)
    }

    private func memGet(_ x: UInt32) -> UInt32 {
        if let v = overlay[x] { return v }
        if x < fillStart { return 0 }
        if x >= chainUntil { ensureFilled(x) }
        return chain[Int(x)]
    }

    private func ensureFilled(_ x: UInt32) {
        let blockEnd = (x / BLOCK_SIZE + 1) * BLOCK_SIZE
        let tailEnd = (fillStart / BLOCK_SIZE + 1) * BLOCK_SIZE

        var i: UInt32, p1: UInt32, p2: UInt32
        if chainUntil == fillStart {
            p1 = overlay[fillStart - 1] ?? 0
            p2 = overlay[fillStart - 2] ?? 0
            i = fillStart
        } else {
            i = chainUntil
            p1 = chain[Int(i - 1)]
            p2 = chain[Int(i - 2)]
        }

        while i < blockEnd {
            let nxt: UInt32
            if i == tailEnd {
                nxt = crazy(memGet(i - 1), memGet(i - 2), crazy5)
            } else if i == tailEnd + 1 {
                nxt = crazy(p1, memGet(i - 2), crazy5)
            } else {
                nxt = crazy(p1, p2, crazy5)
            }
            chain[Int(i)] = nxt
            p2 = p1
            p1 = nxt
            i += 1
        }
        chainUntil = blockEnd
    }

    /// Run up to `maxSteps` more instructions with the given input bytes.
    @discardableResult
    public func run(input: [UInt8], maxSteps: UInt64) -> HaltReason {
        var executed: UInt64 = 0
        while !halted && executed < maxSteps {
            executed += 1
            let ins = memGet(c)
            guard ins >= 33 && ins <= 126 else {
                halted = true; haltReason = .invalidCell; break
            }
            let v = (ins &+ c) % 94
            switch v {
            case 4:
                c = memGet(d)
            case 5:
                if output.count < OUT_CAP {
                    output.append(UInt8(a % 256))
                }
            case 23:
                if inputPos < input.count {
                    a = UInt32(input[inputPos]); inputPos += 1
                } else {
                    halted = true; haltReason = .eof; break
                }
            case 39:
                let r = rotate(memGet(d))
                overlay[d] = r
                a = r
            case 40:
                d = memGet(d)
            case 62:
                let r = crazy(a, memGet(d), crazy5)
                overlay[d] = r
                a = r
            case 81:
                halted = true; haltReason = .vInstruction; break
            default:
                break
            }
            if halted { break }
            let enc = memGet(c)
            if enc >= 33 && enc <= 126 {
                overlay[c] = UInt32(ENCRYPT[Int(enc - 33)])
            }
            c = c == LAST ? 0 : c + 1
            d = d == LAST ? 0 : d + 1
        }
        steps = steps &+ executed
        return haltReason ?? .stepsExhausted
    }
}

public enum LoadError: Error {
    case invalidCharacter(UInt8)
}

/// Loader compatible with malbolge.c / Rustbolge: skip whitespace, reject
/// any other non-printable byte.
public func loadProgram(_ source: [UInt8]) throws -> [UInt32] {
    var cells: [UInt32] = []
    for ch in source {
        switch ch {
        case 10, 13, 32, 9:
            continue
        case 33...126:
            if cells.count < Int(MEM_SIZE) { cells.append(UInt32(ch)) }
        default:
            throw LoadError.invalidCharacter(ch)
        }
    }
    return cells
}
