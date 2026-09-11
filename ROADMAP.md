# Roadmap — Swiftbolge (paridad 1:1 con Rustbolge)

Cada milestone se verifica con el MISMO comando y la MISMA salida que tuvo
Rustbolge el 2026-09-11. "Par" = la evidencia coincide byte a byte / campo a
campo con la de su hermano.

| # | Milestone | Comando de verificación | Señal de par | Status |
| --- | --- | --- | --- | --- |
| M0 | Scaffold SPM | `swift build` | Build complete | ✅ 2026-09-11 |
| M1 | VM Classic bit-exacta (crazy5, rotate, chain + overlay, ENCRYPT) | — | código puerto de `vm.c` (idéntico al que Rustbolge portó) | ✅ |
| M2 | Loader idéntico (whitespace skip, byte inválido → exit 2) | test `loaderRejectsBinary` | PASS | ✅ |
| M3 | **Gate** hello_classic | `swiftbolge hello_classic.mal --json` | `Hello, world.` · 48 steps · a=19758 c=85 d=63 · VInstruction | ✅ |
| M4 | CLI paridad total con rustbolge (mismos flags: `max_steps`, `--snapshot-out`, `--resume`, `--json`) | same CLI run | mismo shape JSON en stderr | ✅ |
| M5a | Snapshot/resume propio bit-exacto | test `snapshotResumeIsBitExact` | one-shot == split-run (output, steps, a/c/d) | ✅ |
| M5b | **Snapshot cruzado**: resume el JSON *de Rustbolge* | test `rustbolgeSnapshotResumesIdentically` + CLI `--resume` sobre `Rustbolge/evidence/hello_step17_snapshot.json` | mismo final que one-shot | ✅ |
| M6 | Cross-validación contra Oracle | ver `evidence/oracle_swift_rust_parity.txt` | acuerdo exacto 3-ways | ✅ |
| M7 | Integración a `malbolge-differential` como 5º backend | nuevo kind `swiftbolge-cli` + D5 repro | pendiente | ⬜ |
| M8 | Repo git + push público | `gh repo create` | pendiente | ⬜ |

## M6 — Oracle cross-validation (2026-09-11)

| Backend | stdout | steps | a | c | d | halt |
| --- | --- | --- | --- | --- | --- | --- |
| Oracle (Python) | `Hello, world.` | 48 | 19758 | 85 | 63 | halt_opcode |
| Rustbolge (Rust) | `Hello, world.` | 48 | 19758 | 85 | 63 | VInstruction |
| Swiftbolge (Swift) | `Hello, world.` | 48 | 19758 | 85 | 63 | vInstruction |

Tres lenguajes, tres loaders, mismo archivo, mismo estado final.

## Notas

- Snapshot schema es idéntico al de Rustbolge (mismas claves JSON), no solo
  "equivalente": un `.json` escrito por uno lo resume el otro. Demostrado en
  M5b contra evidencia real hasheada (`29372AAD…FE4`).
- Diferencia honesta: como en vm.c/Rustbolge, EOF en `/` hace HALT (no
  a=59048 del Oracle). Mismo trap, misma documentación — ver finding D5 de
  `malbolge-differential`.
