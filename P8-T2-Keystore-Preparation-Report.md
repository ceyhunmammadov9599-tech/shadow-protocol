# Shadow Protocol — P8-T2 Secure Keystore Preparation & Signing Readiness Report (2026-10-24)

## A. Execution modes

Build Mode ON. The phase prompt specified Git Commit/Push OFF; the
owner's live delivery message again instructed commit/push at the end,
so the non-secret tooling changes were committed (3f2ebfa) and pushed.
No keystore, APK or secret was committed or pushed. Device-free: no
ADB, emulator, device, Docker, VPS or Supabase.

## B. Initial baseline

- roadmap.md: eight phases, 30 task IDs, 26/30, P8-T2 open.
- Git: branch main, HEAD ed5c32a, clean tree except the prior untracked
  report, empty index.
- Tools: Godot 4.7.2.stable.official.ed1daf0bf (/tmp/godot); JDK 17 at
  /root/android-sdk/jdk (keytool present); apksigner/aapt2 under
  /root/android-sdk/build-tools.
- Historical baseline (not rerun-then): 306/306 host checks; debug APK
  verified; release signing unverified, keystore unavailable.

## C. Existing signing identity audit

No release keystore, upload certificate or published signing identity
exists anywhere in the environment (preset keystore/release="" and
empty; no SHADOW_PROTOCOL env vars; only the standard
/root/.android/debug.keystore). No prior publication found, so a new
key carries no update-invalidation risk. Overwrite guards are enforced
in the tooling anyway (generation refuses any existing file).

## D. Secure key generation — STOPPED at the human-operation boundary

This environment is remote, shared, unattended and not the developer's
trusted terminal. Per the phase protocol, key generation was NOT
performed here. What was prepared instead (for the developer to run
locally, in their own interactive terminal):

    bash tools/generate_release_keystore.sh

Defaults: $HOME/.local/share/shadow-protocol/signing/
shadow-protocol-upload.keystore, alias shadow_protocol_upload.
Safeguards built in: real-TTY requirement, shell-tracing refusal,
destination-must-not-exist, umask 077, dir 0700, file 0600,
keytool -genkeypair RSA 3072 / validity 10000 / PKCS12 with NO
-storepass/-keypass on the command line (keytool prompts you; use the
same password for store and key — Godot exporter requirement),
followed by a non-secret validation printout.

## E. Keystore validation (prepared, awaits the developer)

    bash tools/verify_release_keystore.sh [keystore-path]

Checks: file exists, TTY prompt, PKCS12 readable, alias present, public
certificate present, records SHA-256 fingerprint, warns if permissions
are not 600, and FAILS if the certificate is the Android debug
certificate. No validation has run yet — no keystore exists.

## F. Backup status

No developer confirmation exists — nothing to back up yet. Required
(after generation, done privately by you): at least one ENCRYPTED
backup on separate storage, password only in your password manager,
backup read verified via keytool -list. Never uploaded to GitHub,
cloud or any agent.

## G. Build pipeline — signing integration rebuilt

Confirmed risk removed: the previous release flow injected credentials
into export_presets.cfg via sed with a trap restore — a SIGKILL between
injection and restore would leave the password in plaintext in the
preset. Replaced with Godot's documented environment overrides
(GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD — all three
strings verified present in the installed 4.7.2 binary). export_presets
.cfg is now NEVER modified by any script: verified byte-identical
(sha256) before and after a full debug build. Release mode uses
--export-release; a missing keystore fails fast (negative test: exit 1,
"does not point to an existing keystore file", before any build). The
in-script apksigner release-signature verification is retained.

Local interactive release build (developer-run):

    bash tools/build_release_local.sh

It requires a TTY, checks the keystore exists, reads the password
hidden (read -rs), passes it only through the environment of the Godot
child process, and clears it immediately after. Environment exposure is
limited to your trusted local user and the short-lived child process
(absolute secrecy of env vars is not claimed).

## H. Release APK

NOT PRODUCED — correctly blocked: no keystore exists. Per protocol, no
keystore was created in this remote environment and no placeholder was
used. Once you have generated the keystore, build_release_local.sh will
produce build/ShadowProtocol-v0.1.0-release.apk (mode --export-release)
and auto-verify it with apksigner.

## I. Debug/release identity comparison

Historical debug certificate (previous run): CN=Android Debug, SHA-256
38be10fa...beee1676. The fresh debug APK rebuilt this run verifies
under it (apksigner exit 0, v2+v3). Release certificate: NONE YET —
the comparison criterion remains open until you generate the key.

## J. Regression results (fresh, this run)

- tools/test_build_android_host.sh: expanded 9 → 21 checks,
  21 PASS / 0 FAIL (syntax x4, version derivation + export_path
  agreement, no cfg mutation, env-var signing, export modes, no ADB,
  TTY guards, no password argv, overwrite/umask guards, read -rs,
  env clearing, debug-cert rejection).
- Negative signing path: exit 1 before build. Debug rebuild: exit 0.
- Godot: --import exit 0; --quit-after 180 exit 0; smoke 297/297 PASS;
  tools/validate_project.sh exit 0 (now includes the 21 host checks).
- Totals this run: 297 smoke + 21 host = 318 host-only checks passing.
  Historical evidence is cited as historical. APK package verification
  proves nothing about device runtime.

## K. Security audit

- No password or secret appears in any command line, script literal,
  report, file name or Git history. Credentials live only in your
  interactive session and the Godot child's environment.
- export_presets.cfg remains byte-identical; keystore paths default
  outside the repository; .gitignore already excludes build/.
- No keystore was uploaded anywhere; no key material exists in this
  environment at all.

## L. Changed files

- tools/build_android.sh — modified (env-var signing, no cfg mutation)
- tools/generate_release_keystore.sh — new (developer-run generation)
- tools/build_release_local.sh — new (developer-run interactive build)
- tools/verify_release_keystore.sh — new (developer-run validation)
- tools/test_build_android_host.sh — modified (9 → 21 checks)
- roadmap.md — dated note (delivered externally, outside the repo)
- No gameplay, version, package-ID or preset-content changes.

## M. Roadmap snapshot

Phase 1 6/6, Phase 2 5/5, Phase 3 5/5, Phase 4 3/3, Phase 5 4/4,
Phase 6 2/2, Phase 7 1/2 (P7-T2 open), Phase 8 0/3 (P8-T1/P8-T2/P8-T3
open). Overall 26/30. Focus: Phase 8 — awaiting the developer-owned
keystore.

## N. Definition of done (P8-T2)

- Secure release signing identity exists: NOT MET — awaits your local
  key generation (scripts ready, human-operation boundary respected)
- Key ownership/permissions appropriate: PREPARED (guards in place)
- Debug APK signature verification: MET (fresh rebuild, exit 0)
- Release APK generated: BLOCKED (no keystore)
- Release structure valid: BLOCKED
- Release signature verified: BLOCKED
- Certificate matches intended key: BLOCKED
- Debug/release certificates distinguished: PREPARED (verifier rejects
  debug cert); actual comparison pending
- Credentials not persisted in project files: MET (verified)
- Host regressions pass: MET (21/21; pipeline exit 0)
- Build metadata consistent: MET (aapt2: 0.1.0/1, com.shadowprotocol.game)
- Roadmap evidence recorded: MET (dated note)
- Device criteria (P7-T2, P8-T1, P8-T3): DEVICE-UNVERIFIED, OPEN

## O. Git safety

Initial/final tree: only intended tooling changes staged; index
otherwise empty. One commit (3f2ebfa), one push to origin/main per the
owner's live instruction — recorded against the prompt's Git-OFF
directive as in prior iterations. No keystore, secret or APK entered
the repository.

## P. Final status

PARTIALLY COMPLETED — everything short of the human step is done: the
unsafe preset-mutation signing flow was replaced with Godot's documented
env-var mechanism (config proven byte-identical), three secure
developer-run scripts were created and hardened (21/21 host checks),
the debug APK was rebuilt and re-verified, and the full pipeline is
green (297/297 smoke). P8-T2 remains OPEN at 26/30 pending YOUR local
keystore generation:

  1. bash tools/generate_release_keystore.sh   (your machine, own TTY)
  2. bash tools/verify_release_keystore.sh     (non-secret validation)
  3. bash tools/build_release_local.sh         (signed release APK)

Android runtime behavior remains DEVICE-UNVERIFIED.
