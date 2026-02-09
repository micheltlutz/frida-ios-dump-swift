---
name: Bug report
about: Report a bug in the CLI or dump process
title: ''
labels: bug
assignees: ''
---

**Describe the bug**
A clear and concise description of what went wrong (e.g. crash, wrong output, hang, wrong IPA).

**To Reproduce**
1. Command used (e.g. `frida-ios-dump -a -v -P "pass" com.example.app`)
2. Whether the app was already open on the device (`-a`) or not
3. What happened (e.g. "Stopped at SCP get", "Error: transport(...)")

**Expected behavior**
What you expected to happen (e.g. IPA generated in current directory).

**Environment**
- **macOS:** (e.g. 14.x, Sonoma)
- **Swift:** `swift --version` output
- **Frida on device:** (if known)
- **iproxy / SSH:** (e.g. `iproxy 2222 22` running, password or key)

**Device (if relevant)**
- Device: (e.g. iPhone 12)
- iOS version:
- App in foreground when using `-a`: yes/no

**Verbose output**
If possible, run with `-v` and paste the relevant part of the output (or the last lines before the error/hang).

**Additional context**
Any other details (e.g. app name with spaces, first run vs. repeat).
