// swiftbolge CLI â€” argument-for-argument compatible with rustbolge:
//
//   swiftbolge <program.mal> [max_steps] [--snapshot-out f] [--resume f] [--json] < input

import Foundation
import SwiftbolgeCore

let stdout = FileHandle.standardOutput
let stderr = FileHandle.standardError

func die(_ message: String, _ code: Int32) -> Never {
    stderr.write(("error: " + message + "\n").data(using: .utf8)!)
    exit(code)
}

var programPath: String? = nil
var maxSteps: UInt64 = 100_000_000
var snapshotOut: String? = nil
var resumePath: String? = nil
var jsonReport = false

var it = CommandLine.arguments.dropFirst().makeIterator()
while let arg = it.next() {
    switch arg {
    case "--snapshot-out": snapshotOut = it.next()
    case "--resume": resumePath = it.next()
    case "--json": jsonReport = true
    default:
        if !arg.hasPrefix("--") {
            if programPath == nil {
                programPath = arg
            } else if let v = UInt64(arg), v > 0 {
                maxSteps = v
            }
        }
    }
}

let machine: Machine
if let resume = resumePath {
    guard let data = FileManager.default.contents(atPath: resume) else {
        die("cannot read snapshot \(resume)", 2)
    }
    guard let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else {
        die("bad snapshot", 2)
    }
    machine = Machine(snapshot: snap)
} else {
    guard let path = programPath else {
        die("usage: swiftbolge <program.mal> [max_steps] [--snapshot-out f] [--resume f] [--json] < input", 1)
    }
    guard let data = FileManager.default.contents(atPath: path) else {
        die("cannot open \(path)", 2)
    }
    let cells: [UInt32]
    do {
        cells = try loadProgram([UInt8](data))
    } catch LoadError.invalidCharacter(let bad) {
        die(String(format: "invalid character 0x%02x in program", bad), 2)
    } catch {
        die("load error", 2)
    }
    machine = Machine(cells: cells)
}

let inputData = FileHandle.standardInput.readDataToEndOfFile()
machine.run(input: [UInt8](inputData), maxSteps: maxSteps)

stdout.write(Data(machine.output))
if !machine.output.isEmpty {
    stdout.write(Data([0x0A]))
}

let status = machine.haltReason == .stepsExhausted ? "TIMEOUT" : "HALTED"
if jsonReport {
    let report: [String: Any] = [
        "steps": machine.steps,
        "status": status,
        "halt_reason": machine.haltReason?.rawValue ?? "StepsExhausted",
        "final": ["a": machine.a, "c": machine.c, "d": machine.d],
        "output_len": machine.output.count,
    ]
    let json = try! JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
    stderr.write(json)
    stderr.write(Data([0x0A]))
} else {
    stderr.write("steps: \(machine.steps) | status: \(status)\n".data(using: .utf8)!)
}

if let out = snapshotOut {
    let encoder = JSONEncoder()
    guard let data = try? encoder.encode(machine.snapshot()) else {
        die("cannot encode snapshot", 2)
    }
    guard FileManager.default.createFile(atPath: out, contents: data) else {
        die("cannot write snapshot \(out)", 2)
    }
}
