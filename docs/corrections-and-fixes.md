# Corrections and Fixes (Working Setup)

This document describes the issues encountered during development and the fixes applied so that the dump completes successfully (device script + SCP + IPA generation).

**Current limitation (Frida 17):** The dump **only works with attach** (`-a`). Without `-a`, Frida 17 typically reports `transport("Timeout was reached")` or `transport("The connection is closed")`. Always open the app on the device first, then run with `-a`.

## 1. Frida 17 timeouts and “connection is closed”

**Symptom:** The CLI failed with `Error: transport("Timeout was reached")` or `Error: transport("The connection is closed")` when running without `-a`, or when loading the script.

**Cause:** On Frida 17, spawn or script load often fails (timeout or connection closed); the only reliable path is **attach** to an already running app.

**Fixes:**

- **Verbose mode (`-v`):** Added step-by-step progress so you can see where it stops:
  - Device manager, USB device, app enumeration, attach/spawn, script load, `post("dump")`, and each SCP get.
- **Error handling:** When a Frida `.transport` or `.timedOut` error is caught, the CLI prints a tip: open the app on the device and run with **`-a`** (attach only), e.g.  
  `frida-ios-dump -a br.com.zanthus.webstore.bistek`.
- **Recommendation:** With Frida 17, **always use `-a`**: open the app on the iPhone first, then run the dump. Add `-v` for verbose if needed.

## 2. Dump stopping after “start dump” / no error (script side)

**Symptom:** Device logs showed `[dump] handleMessage started`, `start dump /path/to/App`, then nothing—no `[device] error`, no further progress.

**Cause:** Script errors (e.g. `TypeError` in `dump.js`) were only printed when `-v` was used, so the process appeared to “hang” without explanation.

**Fixes:**

- **Always print script errors:** Any message from the device with `type: "error"` is now printed (description + stack), even without `-v`, so you see why the dump stopped.
- **Verbose raw messages:** With `-v`, any unhandled message is printed as `[verbose] raw message: ...` to debug protocol/format issues.

## 3. SCP hanging on first file (path with spaces)

**Symptom:** The dump progressed to `[verbose] SCP get: .../Bistek Supermercados.fid` and then stopped—no “SCP done”, no timeout, no error.

**Causes:**

1. **Paths with spaces:** The remote path (e.g. `.../Bistek Supermercados.fid`) was passed to `scp` in a way that broke on the remote side when not using a shell (e.g. backslash-space in a single argument).
2. **Password without sshpass:** When the user passed `-P password` but `sshpass` was not installed, we still ran `scp`; it then waited for a password on stdin and hung indefinitely.

**Fixes:**

- **Password + no sshpass → fail fast:** If `-P` is set and `sshpass` is not found, the tool now exits immediately with a clear message:  
  `Password provided but sshpass not found. Install with: brew install sshpass. Or use -K with an SSH key and omit -P.`
- **SCP via shell when using password:** When a password is provided and `sshpass` is available, SCP is run via `/bin/sh -c '...'` with:
  - **SSHPASS** and **REMOTE** (and other args) passed as **environment variables**, so the remote path with spaces is one quoted argument (`"$USER@$HOST:$REMOTE"`) and is handled correctly by the remote `scp`.
  - **sshpass -e** so the password is read from the environment, not from the command line.
  - Full path to `sshpass` in the command so it works even if `PATH` is minimal.
- **SCP timeout:** A 300s timeout per transfer was added (configurable via `Options.scpSocketTimeout`). If SCP hangs, it is terminated and an error is reported instead of blocking forever.

## 4. Summary of working command (attach only on Frida 17)

After the above fixes, a typical working run is (attach is required with Frida 17):

```bash
# 1. Forward SSH (in another terminal)
iproxy 2222 22

# 2. Open the target app on the iPhone, then:
.build/debug/frida-ios-dump -a -v -P "YOUR_PASSWORD" com.example.app
```

- **`-a`** — attach to the already running app (avoids spawn/load timeouts on Frida 17).
- **`-v`** — verbose (device logs + host progress); optional but useful for debugging.
- **`-P "..."`** — SSH password; requires **sshpass** (`brew install sshpass`) or use **`-K path/to/key`** instead.

The result is a decrypted `.ipa` in the current directory (e.g. `Bistek Supermercados.ipa`).

## References

- Host–device protocol and design: [docs/adr/0001-host-device-communication.md](adr/0001-host-device-communication.md)
- Python version (same behavior): [ml-frida-ios-dump](https://github.com/micheltlutz/frida-ios-dump) (PR with Frida 17 compatibility and timeout/verbose improvements)
