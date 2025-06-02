Primary navigation
Homepage
Project
S
sshuttlecraft
Learn GitLab
23%

Pinned
Merge requests
0

Manage

Plan

Code

Build

Secure

Deploy

Operate

Monitor

Analyze

Settings
dcorley
sshuttlecraft
sshttlecraft
README.md
README.md
Daniel Corley's avatar
Update file README.md
Daniel Corley authored 24 minutes ago
1f77c58f
README.md
3.79 KiB
# Shuttlecraft
**Shuttlecraft** is a macOS menu bar utility designed to simplify managing and toggling your `sshuttle` VPN connections.
## Features
* **Menu Bar Access:** Quickly connect and disconnect from your configured `sshuttle` hosts directly from the macOS menu bar.
* **Connection Management:**
    * Add, edit, and remove `sshuttle` host configurations through a simple preferences window.
    * Configure parameters for each host, including:
        * Connection Name
        * Remote SSH Host (e.g., `user@server.com`)
        * Subnets to Forward (comma-separated)
        * DNS Forwarding (`--dns`)
        * Auto Add Hostnames (`-N`)
        * Advanced options: Excluded Subnets (`-x`), Custom SSH Command (`--ssh-cmd`)
* **Status Indication:**
    * Visual feedback in the menu for connection status (Disconnected, Connecting, Connected, Error).
    * Dynamic menu bar icon indicating overall connection activity.
    
* **Persistent Configurations:** Your host configurations are saved and loaded across app launches using `UserDefaults`.
* **GPLv3 Licensed:** Open source and free to use, modify, and distribute under the GNU General Public License v3.0.
## License
This project is licensed under the GNU General Public License v3.0. A copy of the license should be included with the source code (e.g., in a `LICENSE` file).
## Requirements
* A modern version of macOS.
* **`sshuttle` must be installed on your system.** Shuttlecraft currently expects `sshuttle` to be located at `/opt/homebrew/bin/sshuttle`. The easiest way to install it there is via [Homebrew](https://brew.sh/):
    ```bash
    brew install sshuttle
    ```
## Installation 
1.  **Install `sshuttle`:** If you haven't already, install `sshuttle` using Homebrew:
    ```bash
    brew install sshuttle
    ```
    Ensure it is available at `/opt/homebrew/bin/sshuttle`.
2.  **Download Shuttlecraft:**
    * Download the latest `Shuttlecraft.app` release from the [GitHub Releases page]([Link to your GitHub Releases page when available]).
3.  **Install the App:**
    * Unzip the downloaded file (if it's a `.zip`).
    * Drag `Shuttlecraft.app` to your `/Applications` folder.
4.  **First Launch (Gatekeeper):**
    * The first time you open Shuttlecraft, macOS Gatekeeper might show a warning because the app is from an (unidentified for now) developer.
    * To open it, right-click (or Control-click) the `Shuttlecraft.app` icon and choose "Open" from the context menu. You may need to confirm again.
    * (Alternatively, you might need to allow it in **System Settings > Privacy & Security**).
5.  **`sudo` Password for `sshuttle`:**
    * When you activate a connection for the first time using Shuttlecraft, `sshuttle` (which Shuttlecraft launches in the background) needs administrator privileges to modify network settings.
    * You will likely see a standard macOS password prompt asking for your administrator password. This is for `sudo` being used by `sshuttle`.
    * You will need to enter your macOS user password for `sshuttle` to function. This may occur for each new `sshuttle` session unless you have configured passwordless `sudo` for `sshuttle` yourself.
## Current Status & Limitations
* The path to the `sshuttle` executable is currently hardcoded to `/opt/homebrew/bin/sshuttle`.
* This application is currently under development. While core features are functional, further refinements and robust error handling are ongoing.
* (Optional: You can mention known minor UI bugs here if you wish, e.g., "The 'Advanced Options' label in the add/edit sheet may shift slightly when expanded/collapsed.")
## Acknowledgements
* This application relies on Shuttle, Major thanks to the creators. https://github.com/sshuttle/sshuttle/graphs/contributors
* AI assistance (e.g., for boilerplate code, debugging, and suggestions) was provided by Google's Gemini.