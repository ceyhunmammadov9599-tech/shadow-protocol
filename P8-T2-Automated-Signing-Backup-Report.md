# Shadow Protocol — Automated Release Signing & Complete GitHub Backup Report (2026-10-24)

## A. Execution modes

Build ON; Git Commit/Push ON (both authorized by this phase prompt).

## B. Initial baseline

- Godot 4.7.2.stable.official.ed1daf0bf (/tmp/godot); JDK 17
  (/root/android-sdk/jdk, keytool supports -storepass:env, verified
  with a scratch 30-day keystore that was deleted); Android SDK
  build-tools 34.0.0/35.0.0 (aapt2, apksigner); OpenSSL 3.0.20.
- Git: branch main, HEAD 3f2ebfa, clean tree except two untracked
  non-secret reports, empty index. Upstream origin confirmed:
  github.com/ceyhunmammadov9599-tech/shadow-protocol.git.
- Roadmap: 8 phases, 30 task IDs, 26/30 complete, P8-T2 open.

## C. Existing signing identity

No pre-existing release/upload keystore, no publication, no registered
upload key (preset keystore/release="", no SHADOW_PROTOCOL env vars,
no .jks/.p12/.pfx release files anywhere). Continuity risk: none for
this unpublished application. Overwrite protections remain in the
tooling (generation refuses existing files).

## D. Private delivery capability — VERIFICATION FAILED

The platform's owner-restricted facility is Base44 private storage
plus time-limited signed download URLs. Probe performed BEFORE any key
generation, as required, with a non-secret probe file:

- upload_private_file → OK (private URI, not publicly addressable:
  access without a valid token is refused).
- create_file_signed_url (3 attempts, 600s/900s/300s expiries) →
  download returned HTTP 401 "token validation failed" every time, via
  sandbox curl AND via a real Chrome browser session (Browserbase).
- Conclusion: the expiring-link channel cannot be verified to deliver
  any binary to the owner. An obscure/failing URL is not proof of
  secure private access; no other recipient-only secret channel exists
  in this environment (Telegram direct text is excluded by the
  no-passwords-through-AI-messages rule).

## E. Automated key generation — NOT PERFORMED (policy)

Per the phase protocol ("Never generate an irreplaceable secret before
verifying the developer can securely receive it"), no keystore, no
signing key and no password were generated. No cryptographic material
exists from this attempt.

SECURE PATH FORWARD (one message from you): reply in this chat with a
strong passphrase of YOUR choosing. I will then (1) generate the
keystore (RSA-3072, PKCS12, 10000d, CSPRNG store password via
-storepass:env, never in argv), (2) build and verify the signed
release APK, (3) encrypt the keystore + credential record with YOUR
passphrase (AES-256, PBKDF2 ~600k iterations), and (4) deliver the
encrypted archive through a normal link — the ciphertext is safe to
carry anywhere, and only you can decrypt it. The passphrase travels
owner-to-agent inside this private chat, never agent-to-owner, and is
never echoed, logged or committed.

## F. Backup deliverables — none this run (blocked upstream by D).
The public signing certificate will be extracted and delivered once
the key exists.

## G. Debug APK

Existing verified debug APK remains current for the unchanged game
source (built through the corrected pipeline this session):
com.shadowprotocol.game, versionName 0.1.0, versionCode 1, arm64-v8a;
apksigner verify exit 0 (v2+v3 true), signer CN=Android Debug;
zip 162 entries clean. APK/zip delivered to the owner (public channel
is acceptable: debug keys are not secrets).

## H. Release APK — BLOCKED (no signing key, by design). Precise
blocker: private-delivery channel non-functional (see D); key
generation withheld per policy (see E).

## I. Signing security posture (verified this run)

- tools/build_android.sh passes signing only through Godot's documented
  GODOT_ANDROID_KEYSTORE_RELEASE_* env overrides; export_presets.cfg
  is never modified (sha256-verified identical across a full build).
- No password appears in argv, logs, scripts or tracked files
  (history scan of all 76 tracked paths: clean; only safe tooling
  scripts match keystore keywords).
- keytool :env syntax verified working on the installed JDK.

## J. Complete GitHub backup — COMPLETED

Commit 57855a1 pushed to origin/main (github.com/
ceyhunmammadov9599-tech/shadow-protocol, branch main). Contents:
- Included: project.godot, export_presets.cfg (no secrets), icon.svg
  (+.import), 3 scenes, 40 GDScript sources, 16 tools/build/test
  scripts, README.md with a new reproducible-development section,
  roadmap.md (now committed per this phase's explicit directive,
  superseding the earlier external-only convention — flagged for your
  review), .gitignore, and all non-secret phase reports.
- Verified complete: every .gd/.tscn/.import/.svg resource outside
  build/ and .godot/ is tracked; assets/ contains only empty
  placeholder directories (the game renders procedurally — no binary
  assets exist to commit).
- Excluded (by .gitignore, verified): .godot/, build/, *.apk, *.aab,
  *.keystore, *.jks, keystore.properties, local presets.
- Staged via explicit paths (no git add .); staged diff scanned for
  secrets: clean (one benign documentation mention of -storepass).

## K. Fresh clone reproducibility — VERIFIED

Actually performed: fresh clone from GitHub to a separate directory →
headless import exit 0 → smoke test "SMOKE TEST: all checks passed",
297 PASS / 0 FAIL. A new computer can clone, import and verify the
game with only Godot 4.7.2 installed.

## L. Test evidence (fresh, final tree)

- --import exit 0; --quit-after 180 exit 0.
- Smoke: 297 PASS / 0 FAIL, exit 0.
- tools/validate_project.sh exit 0 (21 Android build/signing host
  checks PASS).
- Fresh clone: import exit 0; smoke 297/297.
- Historical baselines (306/318, prior 297 runs) are cited as history.

## M. File audit

- README.md: new reproducible-development section (clone → release
  build, keystore restore, open items, device disclaimer).
- .gitignore: roadmap.md exclusion removed per complete-backup
  directive.
- roadmap.md: dated note (private delivery blocked, backup completed,
  evidence); P8-T2 remains unchecked.
- P8-T2-Release-Signing-Report.md, P8-T2-Keystore-Preparation-Report.md:
  committed as non-secret documentation.
- No gameplay, version, package-ID or preset changes.

## N. Roadmap (recalculated from checkboxes)

Phase 1 6/6 (P1-T1..P1-T6), Phase 2 5/5 (P2-T1..P2-T5), Phase 3 5/5
(P3-T1..P3-T5), Phase 4 3/3 (P4-T1..P4-T3), Phase 5 4/4 (P5-T1..P5-T4),
Phase 6 2/2 (P6-T1, P6-T2), Phase 7 1/2 (P7-T1 done; P7-T2 open),
Phase 8 0/3 (P8-T1, P8-T2, P8-T3 open). Overall 26/30. Focus: Phase 8,
awaiting a usable secure delivery channel for the signing identity.

## O. P8-T2 acceptance

- Release key securely created/recovered: NOT MET (withheld per policy)
- Private key security checks: NOT APPLICABLE (no key)
- Owner-only recovery delivery: BLOCKED (channel failed verification)
- Release APK generated: NOT MET (no key)
- Release signature verification: NOT MET
- Intended identity confirmed: NOT MET
- Debug APK signature verification: MET (fresh, exit 0)
- Regressions pass: MET (297/297 + 21/21 + fresh clone 297/297)
- Roadmap evidence recorded: MET
- Device criteria (P7-T2, P8-T1, P8-T3): DEVICE-UNVERIFIED, OPEN

## P. Git finalization

Commit 57855a1, branch main, upstream origin → PUSH_OK (remote HEAD
verified 57855a1). Secret scan of staged content: clean. No force-push,
no history rewrite, no unrelated staged work.

## Q. Final status

PARTIALLY COMPLETED.
- Part A (automated signing + owner-only delivery): BLOCKED at the
  private-delivery gate; no key material was generated, exactly as
  the protocol requires. One secure unblock exists: send a passphrase
  of your choice in this chat (see E).
- Part B (complete non-secret GitHub source backup): COMPLETED,
  including a verified fresh-clone reproducibility test.
Android runtime behavior remains DEVICE-UNVERIFIED.
