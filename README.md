# frida-ios-dump (Swift)

Dump decrypted IPAs from jailbroken iOS devices via [Frida](https://frida.re/). This is a **Swift** reimplementation of the original [frida-ios-dump](https://github.com/AloneMonkey/frida-ios-dump) (Python), using the [frida-swift](https://github.com/frida/frida-swift) bindings.

**Note (Frida 17):** With Frida 17 on device, the dump **only works in attach mode** (`-a`). Without `-a`, you may see `transport("Timeout was reached")` or `transport("The connection is closed")`. Open the app on the iPhone first, then run:  
`frida-ios-dump -a -P "password" com.example.app`

## Requirements

- **macOS** (Xcode or Swift 5.9+)
- **Jailbroken iOS device** with [frida-server](https://frida.re/docs/ios/) running
- **USB connection** and [iproxy](https://wiki.theory.org/Bitbucket_username) (or similar) to forward SSH:  
  `iproxy 2222 22` (so the host can `ssh`/`scp` to `localhost:2222`)
- **Swift package** [frida-swift](https://github.com/micheltlutz/frida-swift) as a sibling directory (see Build)

## Build

Clone this repo and ensure [frida-swift](https://github.com/micheltlutz/frida-swift) is available as a sibling directory:

```bash
cd /path/to/ehios
git clone https://github.com/micheltlutz/frida-swift.git   # if not already there
cd frida-ios-dump-swift
swift build
```

The executable is produced at:

```text
.build/debug/frida-ios-dump
```

Release build:

```bash
swift build -c release
# .build/release/frida-ios-dump
```

## Tests

Run the unit tests:

```bash
swift test
```

## Usage

- **List installed applications** (PID, name, bundle identifier):

  ```bash
  .build/debug/frida-ios-dump -l
  ```

- **Dump an app** by bundle id or display name:

  ```bash
  .build/debug/frida-ios-dump com.example.app
  ```

- **Attach to an already running app** (required with Frida 17; spawn often fails with “connection is closed” or timeout):

  ```bash
  .build/debug/frida-ios-dump -a com.example.app
  ```

- **SSH options**: default is `root@localhost:2222` with password `alpine`. Override with:

  - `-H` / `--host` — SSH host (default: localhost)
  - `-p` / `--port` — SSH port (default: 2222). **Note:** `-p` is port; **`-P`** (capital) is password.
  - `-u` / `--user` — SSH user (default: root)
  - `-P` / `--password` — SSH password
  - `-K` / `--key_filename` — path to SSH private key

  Example with password and verbose device logs:

  ```bash
  .build/debug/frida-ios-dump -a -P "mypass" -v com.example.app
  ```

- **Output IPA name**: `-o MyApp` writes `MyApp.ipa` in the current working directory.

## How it works

1. The CLI discovers the USB device via Frida’s `DeviceManager` and finds the target app.
2. It attaches to (or spawns) the app and injects the bundled **dump.js** script.
3. The script runs inside the app, dumps decrypted modules, and sends paths back to the host via Frida messages.
4. The host uses **SCP** (over SSH) to copy those paths from the device into a local `Payload` directory, then builds the **.ipa** with `zip`.

For a detailed description of the host–device communication and design decisions, see [docs/adr/0001-host-device-communication.md](docs/adr/0001-host-device-communication.md).

For a summary of **issues encountered and fixes applied** (Frida 17 timeouts, SCP hanging with paths containing spaces, password/sshpass), see [docs/corrections-and-fixes.md](docs/corrections-and-fixes.md).

## Troubleshooting

- **“Waiting for USB device…”** — Connect the device via USB, ensure frida-server is running, and that no other Frida client is holding the connection.
- **“App not running”** with `-a` — Open the app on the device first, then run the dump again.
- **SCP / SSH errors** — Run `iproxy 2222 22`. For password auth you need **sshpass** (`brew install sshpass`); otherwise use `-K path/to/key`. If you use `-P` without sshpass, the tool will fail immediately with instructions. Paths with spaces (e.g. app names) are handled by running SCP via shell with env vars; see [docs/corrections-and-fixes.md](docs/corrections-and-fixes.md).
- **Timeout waiting for dump** — Keep the app in the foreground and ensure SSH (and frida-server) are reachable.
- **`transport("Timeout was reached")` or `transport("The connection is closed")`** — With Frida 17 the dump **only works with `-a`** (attach). Open the app on the device, then run e.g. `frida-ios-dump -a -P "password" com.example.app`. Use `-v` to debug. See [docs/corrections-and-fixes.md](docs/corrections-and-fixes.md).

- **Dump stops at “SCP get”** — Usually due to path with spaces or missing sshpass. Install sshpass (`brew install sshpass`) and use `-P "password"`; the tool runs SCP via shell so paths like `App Name.fid` work. See [docs/corrections-and-fixes.md](docs/corrections-and-fixes.md).

## License

Same as the original frida-ios-dump (AloneMonkey). See [LICENSE](LICENSE) if present.
