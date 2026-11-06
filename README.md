# Swiftbolge v2.0 — Classic Malbolge Engine in Swift 6.3 with Cross-Engine Snapshot/Resume

[![Version](https://img.shields.io/badge/version-2.0-blue.svg)](https://github.com/DannyBaanks/Swiftbolge)
[![Swift](https://img.shields.io/badge/Swift-6.3%2B-orange.svg)](https://swift.org)
[![Tests](https://img.shields.io/badge/tests-5%2F5%20PASS-brightgreen.svg)]()

Classic Malbolge engine in Swift 6.3 — semantic port, bit-exact, of
`Malbolge-Engine/vm.c` (same as its brother *Rustbolge*), with **snapshot /
resume** whose JSON schema is byte-compatible with Rustbolge's: either engine
can resume the other's snapshot.

Member of the **v2.0 Malbolge Multi-Oracle Consensus Fleet** alongside
`Zigbolge v2.0`, `Rustbolge v2.0`, `Cobolge v2.0`, and `Fortranbolge v2.0`.

Verified gates (see `ROADMAP.md` — every milestone mirrors Rustbolge's):

- `hello_classic.mal` → `Hello, world.`, 48 steps, HALTED, a=19758 c=85 d=63
- snapshot→resume reproduces the one-shot run exactly
- resumes Rustbolge's real step-17 snapshot to the identical final state
- 5/5 XCTest PASS

## Usage

```
swiftbolge <program.mal> [max_steps] [--snapshot-out f] [--resume f] [--json] < input
```

Identical CLI and JSON stderr report to `rustbolge`, so any harness that
drives one drives the other (malbolge-differential backend: `rustbolge-cli`
shape).

## Limits

Classic only (59049 cells). EOF on `/` halts, following vm.c/Rustbolge — NOT
the oracle's `a=59048`; that divergence is documented in
`malbolge-differential/findings/D5_eof_halt_vs_59048.md`.

Evidence: `evidence/oracle_swift_rust_parity.txt`
SHA-256 `8A97E03BB8AC901F0B9902191F05849868F1B13DE641C8EF973B05F4E637564E`
