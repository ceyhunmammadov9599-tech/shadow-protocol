# Shadow Protocol — P8-T2 Private Delivery Diagnosis & Alternative Search Report (2026-10-24)

## A. Roadmap and initial Git baseline

- roadmap.md: 8 phases, 30 unique task IDs, 26 complete / 4 open,
  P8-T2 open. Read fully before any action.
- Git baseline (read-only): branch main, HEAD fd9d331, clean tree,
  empty index. Upstream: github.com/ceyhunmammadov9599-tech/shadow-
  protocol.git.

## B. Private delivery root-cause diagnosis (non-secret evidence)

The failing mechanism: Base44 private storage + time-limited signed
download URLs (three attempts last run, HTTP 401). This run the
token payload was decoded (no token values printed):

- iss/sub: urn:app:588d9e2325... (a different application identity)
- aud: urn:service:file.download
- obj: /private/6a23f0e31a5238e6a0f12e8b/<file> (this Superagent app)
- validity window: 900 s, not expired at test time.

ROOT CAUSE (observed, consistent): the token's issuer/subject
application identity does not match the object-owning application in
the path — a cross-application token that the media service rejects
("token validation failed") for every client (sandbox curl, real
Chrome via Browserbase). This is a platform-side token configuration
defect. Per protocol, authentication was not disabled or bypassed;
the prior signed-URL strategy was not retried with new parameters.

## C. Alternative delivery mechanisms actually inspected

1. Authenticated API file routes (§5-A/C): the /api/apps/<id>/files/
   route serves public objects but returns 404 file_not_found for
   private objects, both anonymously and with a valid Base44 service
   token. No alternative private-download API exists.
2. Agent API surface: docs/skill/openapi endpoints return "App not
   found" without the editor-provided base URL; no file-retrieval
   endpoint is documented in the available skill material.
3. Recipient public-key E2E (§5-D): no GPG or SSH keys are published
   on the developer's GitHub account — no pre-existing
   owner-controlled public key exists to verify and use.
4. Owner secret viewer (§5-B): the Base44 editor Settings → Secrets
   tab is owner-only and can reveal stored values, but this agent has
   no set_secrets capability, so no value can be written to it.
5. OAuth connectors: none of the supported connectors is authorized;
   Gmail/Drive/OneDrive delivery is impossible until the owner
   connects one.
6. Telegram/public storage/GitHub/AI-chat: excluded for signing
   secrets by the phase protocol (Telegram and chat delivery require
   the owner's explicit override, not an agent decision).
7. Backend-function retrieval: functions can be deployed, but no
   owner-accessible authenticated invocation surface exists that this
   environment can verify; an unproven channel cannot replace the
   required end-to-end delivery proof.

## D. End-to-end harmless-file delivery test — NOT COMPLETED

The harmless probe (probe file uploaded, SHA-256 known locally)
cannot be retrieved through any verified owner-only channel; the
probe remains in private storage (harmless). No key material was
generated.

## E. Password recovery channel — NOT ESTABLISHED

No owner-only, agent-writable channel exists (see C.4/C.5). Per §6 the
signing password therefore cannot be delivered or recovered safely.

## F. Signing identity continuity

Unchanged from prior audits: no release/upload keystore, no
publication, no registered upload key (preset keystore/release="",
no release env vars, only the standard debug keystore). A new key
would not break any published app. Not proof of unpublished Play
status; treated as a reported finding.

## G. Real keystore generated? NO — withheld by the stop rule

(§8: owner-only binary delivery unproven + password recovery
unproven ⇒ do not create the key.) No keystore, password, certificate
or release APK exists from this run.

## H. Private recovery delivery — BLOCKED (blockers in B/C/E).

## I. Signed release APK — BLOCKED upstream (no signing key, by
design). The existing debug APK remains the verified artifact:
com.shadowprotocol.game 0.1.0/1 arm64-v8a, apksigner verify exit 0
(v2+v3), zip 162 entries clean.

## J. Fresh test evidence (this run, final tree)

- tools/test_build_android_host.sh: 21 PASS / 0 FAIL (exit 0).
- Godot smoke: 297 PASS / 0 FAIL, exit 0 (run after the only file
  change — roadmap.md documentation metadata; no source or engine
  configuration changed since this morning's full suite: import/boot/
  smoke/validate all exit 0 at 2026-10-24 ~10:00 UTC).
- Historical numbers (297+21=318 baseline, 306/306) are historical.

## K. Git commit reconciliation (read-only)

- 57855a1 exists: parent 3f2ebfa, on main, ancestor of HEAD.
- fd9d331 exists: parent 57855a1, on main, equals HEAD.
- Chain is linear: 3f2ebfa → 57855a1 → fd9d331; no divergence.
- Remote verification via read-only GitHub API (no git fetch):
  remote main is at fd9d331 — both commits are on the remote.
- Local origin/main tracking ref is stale (130ac14, Phase 7 era):
  explicit-URL pushes do not update it; no history rewritten, purely
  cosmetic. Non-secret project files remain fully tracked (70 files).

## L. Documentation consistency findings and corrections

roadmap.md intro contained two demonstrably stale statements, now
corrected with dated notes (historical evidence preserved):
- "NOT committed to the repository" — false since 2026-10-24
  (roadmap committed in 57855a1 per the complete-backup directive).
- "Current focus: Phase 7" — stale; corrected to Phase 8
  (P7-T1 complete, P7-T2 open; P8-T1/T2/T3 open).
Audit notes elsewhere explicitly marked as historical records were
left untouched.

## M. Modified files

- roadmap.md only: intro metadata correction + dated Phase 8
  diagnostic note (no task, checkbox or phase-count changes; still
  26/30, 8 phases, 30 task IDs).
- This report file.
- No gameplay, source, build-configuration, preset or version changes.

## N. Complete roadmap (recalculated from checkboxes)

Phase 1: 6/6 — P1-T1 Project bootstrap, P1-T2 Player movement,
P1-T3 Enemy AI, P1-T4 Collision/health, P1-T5 Mission objective,
P1-T6 HUD/messages [all x]
Phase 2: 5/5 — P2-T1..P2-T5 (procedural levels, doors, terminals,
extraction beacon, difficulty) [all x]
Phase 3: 5/5 — P3-T1..P3-T5 (audio, particles, shaders, screen
effects, balance) [all x]
Phase 4: 3/3 — P4-T1..P4-T3 (menu/UI/persistence) [all x]
Phase 5: 4/4 — P5-T1..P5-T4 (visual upgrade tasks) [all x]
Phase 6: 2/2 — P6-T1, P6-T2 (layout remediation, camera fix) [all x]
Phase 7: 1/2 — P7-T1 [x] profiling/optimization; P7-T2 [ ] 60 FPS
on mid-range device (real-device evidence required)
Phase 8: 0/3 — P8-T1 [ ] device installation, P8-T2 [ ] release
signing (blocked: see B/C/E), P8-T3 [ ] on-device gameplay
verification
Overall: 26/30. Current focus: Phase 8.

## O. Secret exposure

No secret values, tokens, passwords or private keys were printed,
logged, committed or uploaded. Only non-secret JWT payload fields
(issuer/audience/expiry) were decoded for diagnosis. All tokens used
for testing were passed via environment variables, never echoed.

## P. Commit/push status

The phase prompt set Git Mode OFF; the owner's live delivery message
again instructed commit/push at the end (same override pattern as
prior iterations). The documentation-only roadmap correction and this
report were committed and pushed to main (hash in the delivery
message). No keystore or secret is in the repository; staged content
scanned clean.

## Q. Final status

BLOCKED (for the signing objective) — with the root cause fully
diagnosed and every alternative channel in this environment
inspected and documented. Key generation remains withheld per the
protocol's stop rule; P8-T2 stays open at 26/30.

ONE OWNER DECISION unblocks everything (no terminal commands, no
password pasting — I generate and handle all key material):
- Option 1 (fastest): explicitly authorize delivery of the encrypted
  backup archive through a public link AND the password as a direct
  Telegram message to you (your DM; the keystore itself stays
  AES-256-encrypted everywhere and is useless without your DM).
- Option 2 (protocol-classic): connect one OAuth connector in the
  agent editor (Gmail or Google Drive) — I deliver the encrypted
  backup and credentials to your own account.
- Option 3: report the token defect to Base44 (issuer app mismatch)
  and I retry the signed-URL flow after the fix.
Android runtime behavior remains DEVICE-UNVERIFIED (P7-T2, P8-T1,
P8-T3).
