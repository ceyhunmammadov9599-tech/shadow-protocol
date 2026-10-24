# Shadow Protocol — P8-T2 Automated Release Signing & Encrypted Backup Delivery Report (2026-10-24)

## A. EXECUTION MODES
Build ON; Git Commit/Push per this prompt OFF, but the owner's live
message again explicitly instructed commit/push at the end (same
override pattern as prior iterations): only documentation files
(roadmap + this report) were committed and pushed; no secret ever
entered Git (verified by staged-content scan).

## B. INITIAL BASELINE
Godot 4.7.2.stable.official.ed1daf0bf; JDK 17 (keytool :env verified);
build-tools 34.0.0 (aapt2/apksigner); Python cryptography 48.0.0
(AESGCM + Scrypt). Git baseline: branch main, HEAD f63786d, clean
tree, empty index. Roadmap 26/30, P8-T2 open.

## C. TELEGRAM PREFLIGHT
Integration: the agent's connected Base44 Telegram bot (the channel
this conversation runs on). The developer's verified private chat was
matched through the platform-connected identity (owner-initiated
conversation, chat type verified "private" earlier this project via
Bot API getChat; recipient id redacted here). Raw Bot API token
found in the environment: INVALID (getMe -> HTTP 401 on two attempts;
retried per the at-most-two-retries rule, then abandoned). Delivery
therefore uses the platform's working, authenticated bot integration
(the only working Telegram sender in this environment). Test message:
the conversation itself (the owner's approval prompt arrived in this
exact chat). Human receipt of the password message: NOT YET
CONFIRMED; only SENT status applies. Honest caveats: ordinary
Telegram cloud message, NOT E2EE Secret Chat.

## D. PUBLIC DELIVERY PREFLIGHT
Harmless random sample encrypted with AES-256-GCM + scrypt
(n=2^15, r=8, p=1, 32B salt, unique 12B nonce; container format
SPBK1). Published via the normal HTTPS route; downloaded; SHA-256
matched; decryption restored identical bytes; wrong-password
rejected (InvalidTag); modified ciphertext rejected (InvalidTag);
no plaintext published. PASSED.

## E. SIGNING CONTINUITY
No pre-existing release/upload key (preset release fields empty; only
/root/.android/debug.keystore exists). Application never published;
a new key breaks nothing. No keystore was overwritten.

## F. KEY GENERATION — DONE
PKCS12 keystore, RSA 3072-bit, alias shadow_protocol_upload, validity
10000 days, DN "CN=Shadow Protocol Upload Key, OU=Shadow Protocol,
O=Shadow Protocol Project" (non-impersonating), SHA256withRSA.
Certificate SHA-256 fingerprint:
74ec3b4ec475f65517f0676b30d801f9fc557a5bb733dcabd70a5f016c574a0b
Keystore stored OUTSIDE the repository with 0600 permissions; the
keystore password (PASSWORD A, 256-bit CSPRNG hex) was passed only
via keytool -storepass:env; shell tracing off; never printed, never
in argv, never in any project/Git file.

## G. ENCRYPTED RECOVERY BACKUP
Container: SPBK1 (opaque, versioned; documented in RESTORE-INSTRUCTIONS
inside): AES-256-GCM + scrypt, random salt, unique nonce; independent
256-bit CSPRNG archive password (PASSWORD B, distinct from A; value
NOT in this report). Contents: keystore, credential record (contains
PASSWORD A), restore instructions, SHA-256 manifest (6 files), public
certificate (DER+PEM) and fingerprint file. Local verification:
decrypt with B -> keystore byte-identical and VALID with A
(keytool list OK); wrong password rejected; tampered container
rejected. Public delivery: normal HTTPS URL, remote SHA-256
ff29bc5dbbd564ca288d773c1fa5dbe555baae8f14270bd8d85094ee71792638 ==
local; end-to-end download+decrypt+keystore-revalidation performed
from the public URL. Archive URL (not secret):
https://base44.app/api/apps/6a23f0e31a5238e6a0f12e8b/files/mp/public/6a23f0e31a5238e6a0f12e8b/2ffd8056b_shadow-protocol-signing-backup-v1.spbk
Nonsecret decrypt tool shipped publicly: spbk_tool.py (same route,
65c1177e8_spbk_tool.py).

## H. TELEGRAM PASSWORD DELIVERY
STATUS: SENT (via the platform's connected bot to the developer's
verified private chat; delivered in the agent's reply message per the
owner's explicit Option-1 authorization, since the raw Bot API token
is invalid). NO password values appear in this report, in Git, in
the roadmap, or in any public file. Human receipt: NOT YET
CONFIRMED — the owner should confirm and store PASSWORD B in a
password manager and keep the encrypted archive offline.

## I. RELEASE APK
Output: build/ShadowProtocol-v0.1.0-release.apk (26,710,546 bytes).
Metadata: package com.shadowprotocol.game, versionName 0.1.0,
versionCode 1, minSdk 24, native-code arm64-v8a (aapt2 badging).
Zip integrity: 153 entries, no corruption. apksigner verify exit 0:
v2 true, v3 true (v1 false). Signer certificate SHA-256
74ec3b4e...0b — IDENTICAL to the generated release identity; DIFFERS
from the debug certificate (38be10fa...676). No debug fallback.
Note: the build script's own apksigner step initially failed with
"java: not found" (sanitized error; PATH issue, not a signing
failure) — resolved by running apksigner with the verified JDK path;
Godot's export itself completed ("Verifying APK... DONE"). Release
zip delivered publicly (9b63c28b9_ShadowProtocol-v010-release.zip),
remote download verified clean.

## J. SECURITY FINDINGS
No raw private key or password was uploaded publicly, committed,
logged or echoed; passwords existed only in 0600 files outside the
repo (and inside the AES-256-GCM archive). The public route carries
ONLY ciphertext (verified). Telegram password message = ordinary
cloud message (not E2EE) — residual risk accepted by the owner.
Public encrypted archive: anyone can download the ciphertext, but
without PASSWORD B it is indistinguishable random data (AES-256-GCM).
Original keystore retained (0600, outside repo) plus the verified
public backup; nothing sole-copy was deleted. The platform's broken
signed-URL mechanism was not used.

## K. TEST EVIDENCE (fresh, final tree)
- godot --headless --import: exit 0 (inside validate run)
- --quit-after 180 boot: exit 0
- tools/smoke_test.tscn: 297 PASS / 0 FAIL, exit 0
- tools/validate_project.sh: exit 0; host checks 21 PASS / 0 FAIL
- Encryption preflight + archive tests: all pass (see D/G)
- apksigner/aapt2 verification: exit 0 (see I)
Historical baselines (318 checks etc.) are history.

## L. FILE AUDIT
- roadmap.md: P8-T2 checked with evidence; Phase 8 header and Counts
  updated (27/30); dated completion note appended. No other roadmap
  change; all 8 phases and 30 task IDs preserved.
- P8-T2-Release-Signing-Completion-Report.md (this file).
- build/ outputs (APK/zip, gitignored).
- Signing materials: /app/conversations/.../shadow-protocol-signing/
  (outside the repository; 0700/0600 perms).
- No gameplay source, scene, preset or version changes.

## M. COMPLETE ROADMAP
Phase 1 6/6: P1-T1 Project bootstrap [x]; P1-T2 Player movement [x];
P1-T3 Enemy AI [x]; P1-T4 Collision/health [x]; P1-T5 Mission
objective [x]; P1-T6 HUD/messages [x].
Phase 2 5/5: P2-T1..P2-T5 procedural levels, doors, terminals,
extraction beacon, difficulty [x].
Phase 3 5/5: P3-T1..P3-T5 audio, particles, shaders, screen
effects, balance [x].
Phase 4 3/3: P4-T1..P4-T3 menus/UI/persistence [x].
Phase 5 4/4: P5-T1..P5-T4 visual upgrade [x].
Phase 6 2/2: P6-T1, P6-T2 layout/camera [x].
Phase 7 1/2: P7-T1 profiling/optimization [x]; P7-T2 60 FPS
mid-range device [ ] (device evidence required).
Phase 8 1/3: P8-T2 debug+release signing verification [x]
(2026-10-24 evidence above; owner backup retrieval NOT YET
CONFIRMED); P8-T1 end-to-end install [ ] (device); P8-T3 on-device
gameplay [ ] (device).
Overall: 27/30. Current focus: Phase 8 device criteria.

## N. ACCEPTANCE MATRIX
- Secure keystore generated: MET
- Encrypted backup created correctly: MET
- Normal-link ciphertext recovery verified end-to-end: MET
- Telegram delivery sent to verified developer chat: MET (SENT)
- Owner retrieval confirmation: NOT YET CONFIRMED (pending)
- Release APK generated: MET
- Release signature verified (fingerprint match, no debug fallback): MET
- Security audit: MET (residual Telegram-cloud risk documented)
- Host-side validation: MET (297/297 + 21/21)
- P7-T2 / P8-T1 / P8-T3: DEVICE-UNVERIFIED, open

## O. GIT SAFETY
Initial tree clean at f63786d; final: only roadmap.md + this report
staged via explicit paths; staged-content secret scan clean; no
keystore/password in Git; push of documentation only (per the
owner's live instruction overriding the prompt's Git-OFF mode);
no force-push, no history rewrite, no resets.

## P. FINAL STATUS
COMPLETED (automated release signing, encrypted public backup,
verified ciphertext recovery, Telegram password delivery SENT;
owner retrieval confirmation pending by design).
Android runtime behavior remains DEVICE-UNVERIFIED.
