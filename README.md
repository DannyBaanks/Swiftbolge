# Swiftbolge

Classic Malbolge engine in Swift 6.3 — semantic port, bit-exact, of
`Malbolge-Engine/vm.c` (same as its brother *Rustbolge*), with **snapshot /
resume** whose JSON schema is byte-compatible with Rustbolge's: either engine
can resume the other's snapshot.

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
