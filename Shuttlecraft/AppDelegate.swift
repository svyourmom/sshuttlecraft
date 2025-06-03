import Cocoa
import SwiftUI

// SSHHostConfig and ConnectionStatus enums remain the same
struct SSHHostConfig: Identifiable, Codable {
    var id = UUID()
    var name: String
    var remoteHost: String
    var subnetsToForward: [String] = ["0/0"]
    var forwardDNS: Bool = false
    var autoAddHostnames: Bool = false
    var excludedSubnetsString: String?
    var customSSHCommand: String?
    var status: ConnectionStatus = .disconnected
    var process: Process?

    enum CodingKeys: String, CodingKey {
        case id, name, remoteHost, subnetsToForward, forwardDNS, autoAddHostnames
        case excludedSubnetsString, customSSHCommand, status
    }
    
    func buildSshuttleArguments() -> [String] {
        var args: [String] = []
        if let sshCmd = customSSHCommand, !sshCmd.isEmpty {
            args.append("--ssh-cmd")
            args.append(sshCmd)
        }
        args.append("-r")
        args.append(remoteHost)
        if forwardDNS {
            args.append("--dns")
        }
        if autoAddHostnames {
            args.append("-N")
        }
        args.append(contentsOf: subnetsToForward)
        if let excluded = excludedSubnetsString, !excluded.isEmpty {
            let excludedArray = excluded.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            for subnet in excludedArray {
                args.append("-x")
                args.append(subnet)
            }
        }
        args.append("-v")
        return args
    }
}

enum ConnectionStatus: Codable {
    case disconnected
    case connecting
    case connected
    case error
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    var statusItem: NSStatusItem?
    var menu: NSMenu?
    var preferencesWindow: NSWindow?

    private let hostConfigurationsKey = "ShuttlecraftHostConfigurations"
    private let sshuttleExecutablePath = "/opt/homebrew/bin/sshuttle"

    @Published var hostConfigurations: [SSHHostConfig] {
        didSet {
            if !isLoadingConfigurations { saveHostConfigurations() }
            setupMenu()
            statusItem?.menu = menu
            updateMenuBarIcon()
        }
    }
    private var isLoadingConfigurations = false

    override init() {
        isLoadingConfigurations = true
        if let savedData = UserDefaults.standard.data(forKey: hostConfigurationsKey),
           let decodedConfigurations = try? JSONDecoder().decode([SSHHostConfig].self, from: savedData) {
            self.hostConfigurations = decodedConfigurations.map { config in
                var mutableConfig = config
                mutableConfig.status = .disconnected
                mutableConfig.process = nil
                return mutableConfig
            }
        } else {
            self.hostConfigurations = [
                SSHHostConfig(name: "Work VPN (Sample)", remoteHost: "workuser@work.example.com", subnetsToForward: ["0/0"], forwardDNS: true),
                SSHHostConfig(name: "Dev Server (Sample)", remoteHost: "devuser@dev.internal", subnetsToForward: ["10.0.1.0/24"])
            ]
        }
        isLoadingConfigurations = false
        super.init()
    }

    private func saveHostConfigurations() {
        if let encodedData = try? JSONEncoder().encode(hostConfigurations) {
            UserDefaults.standard.set(encodedData, forKey: hostConfigurationsKey)
        } else {
            print("Failed to save host configurations.")
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setupMenu()
        statusItem?.menu = menu
        updateMenuBarIcon()
        NSApp.setActivationPolicy(.accessory)
    }

    func isAnyConnectionActive() -> Bool {
        return hostConfigurations.contains { $0.status == .connected }
    }

    func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }
        if isAnyConnectionActive() {
            button.image = NSImage(named: "yes")
            button.setAccessibilityLabel("Shuttlecraft Active")
        } else {
            button.image = NSImage(named: "no")
            button.setAccessibilityLabel("Shuttlecraft Inactive")
        }
    }

    func setupMenu() {
        menu = NSMenu()
        menu?.autoenablesItems = false
        for hostConfig in hostConfigurations {
            var itemTitle = hostConfig.name
            let menuItem = NSMenuItem(title: "", action: #selector(hostAction(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = hostConfig.id
            switch hostConfig.status {
            case .connected: menuItem.state = .on
            case .connecting: itemTitle += " (Connecting...)"; menuItem.state = .off
            case .error: itemTitle += " (Error!)"; menuItem.state = .off
            case .disconnected: menuItem.state = .off
            }
            menuItem.title = itemTitle
            menu?.addItem(menuItem)
        }
        menu?.addItem(NSMenuItem.separator())
        let preferencesMenuItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferencesWindow), keyEquivalent: ",")
        preferencesMenuItem.target = self
        menu?.addItem(preferencesMenuItem)
        menu?.addItem(NSMenuItem.separator())
        let quitMenuItem = NSMenuItem(title: "Quit Shuttlecraft", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu?.addItem(quitMenuItem)
    }
    
    private func showAlert(title: String, message: String) {
        // Ensure alert is run on the main thread
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func handleOutput(for hostID: UUID, data: Data, streamName: String) {
        guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty else { return }
        
        print("[\(hostID)] \(streamName): \(output)")

        DispatchQueue.main.async {
            guard let hostIndex = self.hostConfigurations.firstIndex(where: { $0.id == hostID }) else { return }
            
            // Only process output if we are in the 'connecting' state
            guard self.hostConfigurations[hostIndex].status == .connecting else { return }

            let successPatterns = ["c : Connected to server", "Connected to master", "client: Connected"]
            // Added "c : fatal: failed to establish ssh session" and "Connection refused"
            let errorPatterns = ["fatal:", "error:", "ssh: connect to host", "Connection refused", "Permission denied", "Traceback (most recent call last):", "c : fatal: failed to establish ssh session"]

            for pattern in successPatterns {
                if output.localizedCaseInsensitiveContains(pattern) {
                    self.hostConfigurations[hostIndex].status = .connected
                    print("SUCCESS: \(self.hostConfigurations[hostIndex].name) connected based on output: '\(pattern)'")
                    return
                }
            }

            // Prioritize stderr for error patterns, but check all output for these patterns
            // as ssh/sshuttle might send crucial errors to either.
            for pattern in errorPatterns {
                if output.localizedCaseInsensitiveContains(pattern) {
                    print("ERROR: \(self.hostConfigurations[hostIndex].name) error based on output: '\(pattern)'")
                    self.showAlert(title: "Connection Error: \(self.hostConfigurations[hostIndex].name)",
                                   message: "Details: \(output.prefix(250))") // Show more of the error
                    self.hostConfigurations[hostIndex].status = .error
                    self.hostConfigurations[hostIndex].process?.terminate()
                    self.hostConfigurations[hostIndex].process = nil
                    return
                }
            }
        }
    }

    @objc func hostAction(_ sender: NSMenuItem) {
        guard let hostID = sender.representedObject as? UUID else { return }
        guard let hostIndex = hostConfigurations.firstIndex(where: { $0.id == hostID }) else { return }

        let currentStatus = hostConfigurations[hostIndex].status

        if currentStatus == .connected || currentStatus == .connecting {
            if let process = hostConfigurations[hostIndex].process {
                print("Disconnecting from \(hostConfigurations[hostIndex].name)...")
                (process.standardOutput as? Pipe)?.fileHandleForReading.readabilityHandler = nil
                (process.standardError as? Pipe)?.fileHandleForReading.readabilityHandler = nil
                process.terminate()
                hostConfigurations[hostIndex].process = nil
            }
            hostConfigurations[hostIndex].status = .disconnected
        } else if currentStatus == .disconnected || currentStatus == .error {
            let hostConfig = hostConfigurations[hostIndex]
            print("Attempting to connect to \(hostConfig.name)...")

            let process = Process()
            process.executableURL = URL(fileURLWithPath: sshuttleExecutablePath)
            process.arguments = hostConfig.buildSshuttleArguments()

            let stdOutPipe = Pipe()
            process.standardOutput = stdOutPipe
            stdOutPipe.fileHandleForReading.readabilityHandler = { [weak self] fh in
                let data = fh.availableData; if !data.isEmpty { self?.handleOutput(for: hostID, data: data, streamName: "stdout") }
            }

            let stdErrPipe = Pipe()
            process.standardError = stdErrPipe
            stdErrPipe.fileHandleForReading.readabilityHandler = { [weak self] fh in
                let data = fh.availableData; if !data.isEmpty { self?.handleOutput(for: hostID, data: data, streamName: "stderr") }
            }
            
            process.terminationHandler = { [weak self] terminatedProcess in
                DispatchQueue.main.async {
                    guard let self = self, let termHostIndex = self.hostConfigurations.firstIndex(where: { $0.id == hostID }) else { return }
                    let exitCode = terminatedProcess.terminationStatus
                    print("\(self.hostConfigurations[termHostIndex].name) process terminated (PID: \(terminatedProcess.processIdentifier)). Exit code: \(exitCode)")
                    
                    if self.hostConfigurations[termHostIndex].status == .connecting {
                        self.showAlert(title: "Connection Failed: \(self.hostConfigurations[termHostIndex].name)",
                                       message: "Process terminated unexpectedly (Exit code: \(exitCode)). sshuttle output might contain more details.")
                        self.hostConfigurations[termHostIndex].status = .error
                    } else if self.hostConfigurations[termHostIndex].status != .error {
                        self.hostConfigurations[termHostIndex].status = .disconnected
                    }
                    self.hostConfigurations[termHostIndex].process = nil
                    (process.standardOutput as? Pipe)?.fileHandleForReading.readabilityHandler = nil
                    (process.standardError as? Pipe)?.fileHandleForReading.readabilityHandler = nil
                }
            }

            do {
                try process.run()
                hostConfigurations[hostIndex].process = process
                hostConfigurations[hostIndex].status = .connecting
            } catch {
                print("Error launching sshuttle for \(hostConfig.name): \(error)")
                showAlert(title: "Launch Error: \(hostConfig.name)", message: "Failed to start sshuttle: \(error.localizedDescription)")
                hostConfigurations[hostIndex].status = .error
            }
        }
    }

    @objc func openPreferencesWindow() {
        // ... (openPreferencesWindow code as before) ...
        if let existingWindow = preferencesWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let preferencesView = PreferencesView(appDelegate: self)
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.center()
        newWindow.setFrameAutosaveName("PreferencesWindow")
        newWindow.isReleasedWhenClosed = false
        newWindow.title = "Shuttlecraft Preferences"
        newWindow.contentViewController = NSHostingController(rootView: preferencesView)
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        preferencesWindow = newWindow
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // ... (applicationWillTerminate code as before) ...
        print("Shuttlecraft is quitting. Terminating active connections.")
        for index in hostConfigurations.indices {
            if let process = hostConfigurations[index].process, process.isRunning {
                print("Terminating process for: \(hostConfigurations[index].name)")
                (process.standardOutput as? Pipe)?.fileHandleForReading.readabilityHandler = nil
                (process.standardError as? Pipe)?.fileHandleForReading.readabilityHandler = nil
                process.terminate()
                hostConfigurations[index].process = nil
            }
            if hostConfigurations[index].status == .connecting || hostConfigurations[index].status == .connected {
                 hostConfigurations[index].status = .disconnected
            }
        }
    }
}
