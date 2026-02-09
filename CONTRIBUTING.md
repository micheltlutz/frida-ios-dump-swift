# Contributing to frida-ios-dump-swift

Thank you for your interest in contributing. This document explains how to set up the project, the conventions we use, and how to submit changes.

## Development setup

- **macOS** with Xcode or Swift 5.9+
- **frida-swift** as a sibling directory (see [README](README.md#build))
- Optional: jailbroken iOS device + iproxy for testing the full dump flow

```bash
cd /path/to/parent
git clone https://github.com/YOUR_USER/frida-ios-dump-swift.git
cd frida-ios-dump-swift
# Ensure ../frida-swift exists
swift build
```

## Code and documentation

- **Language:** Code (names, comments, log messages) and documentation (README, docs, ADRs) are in **English**.
- **Style:** Follow common Swift style (e.g. Swift API Design Guidelines). Keep changes focused and easy to review.

## Submitting changes

1. **Fork** the repository and create a branch from the default branch (e.g. `main`).
2. **Make your changes** and ensure the project still builds: `swift build`.
3. **Commit** with clear messages (e.g. "Add timeout for SCP transfers").
4. **Open a Pull Request** against the upstream default branch. Use the [PR template](.github/PULL_REQUEST_TEMPLATE.md): describe what changed and why, and note any breaking or notable behavior.

## Issue templates

When opening an issue, use one of the templates (bug report, feature request, etc.) and fill in the requested information. For bugs, include:

- macOS version and Swift version (`swift --version`)
- Frida version on the device (if relevant)
- Whether you used `-a` (attach) or spawn
- Full command and (if applicable) verbose output (`-v`)

## Questions

For questions or discussion, you can open an issue with the appropriate label or use the "Custom" issue template and describe your question.
