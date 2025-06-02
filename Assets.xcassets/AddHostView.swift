import SwiftUI

struct AddHostView: View {
    @Environment(\.dismiss) var dismiss

    // Basic fields
    @State private var name: String
    @State private var remoteHost: String
    @State private var subnetsToForwardString: String
    @State private var forwardDNS: Bool
    @State private var autoAddHostnames: Bool
    
    // Advanced fields
    @State private var excludedSubnetsString: String
    @State private var customSSHCommand: String
    @State private var isAdvancedExpanded: Bool = false

    private var hostToEdit: SSHHostConfig?
    var onSave: (SSHHostConfig) -> Void

    // Initializer for adding
    init(onSave: @escaping (SSHHostConfig) -> Void) {
        self.hostToEdit = nil
        _name = State(initialValue: "")
        _remoteHost = State(initialValue: "")
        _subnetsToForwardString = State(initialValue: "0/0")
        _forwardDNS = State(initialValue: false)
        _autoAddHostnames = State(initialValue: false)
        _excludedSubnetsString = State(initialValue: "")
        _customSSHCommand = State(initialValue: "")
        self.onSave = onSave
    }

    // Initializer for editing
    init(host: SSHHostConfig, onSave: @escaping (SSHHostConfig) -> Void) {
        self.hostToEdit = host
        _name = State(initialValue: host.name)
        _remoteHost = State(initialValue: host.remoteHost)
        _subnetsToForwardString = State(initialValue: host.subnetsToForward.joined(separator: ", "))
        _forwardDNS = State(initialValue: host.forwardDNS)
        _autoAddHostnames = State(initialValue: host.autoAddHostnames)
        _excludedSubnetsString = State(initialValue: host.excludedSubnetsString ?? "")
        _customSSHCommand = State(initialValue: host.customSSHCommand ?? "")
        _isAdvancedExpanded = State(initialValue: !(host.excludedSubnetsString?.isEmpty ?? true) || !(host.customSSHCommand?.isEmpty ?? true))
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(hostToEdit == nil ? "Add Connection" : "Edit Connection")
                .font(.title2)
                .padding(.top)
                .padding(.bottom, 20)

            Form {
                Section {
                    TextField("Connection Name:", text: $name)
                    TextField("Remote Host (user@server):", text: $remoteHost)
                    TextField("Subnets to Forward (comma-separated):", text: $subnetsToForwardString)
                    Toggle("Forward DNS queries (--dns)", isOn: $forwardDNS)
                    Toggle("Auto Add Hostnames (-N or -H)", isOn: $autoAddHostnames)
                }

                DisclosureGroup(
                    isExpanded: $isAdvancedExpanded,
                    content: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Excluded Subnets (comma-separated):")
                                .font(.caption)
                                .foregroundColor(.gray)
                            TextField("e.g., 192.168.1.1, 10.0.5.0/24", text: $excludedSubnetsString)
                            
                            Text("Custom SSH Command:")
                                .font(.caption)
                                .foregroundColor(.gray)
                            TextField("e.g., ssh -p 2222 -i ~/.ssh/id_rsa_special", text: $customSSHCommand)
                        }
                        .padding(.top, 5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    },
                    label: {
                        HStack {
                            Text("Advanced Options (Optional)")
                                .font(.headline)
                                .fixedSize(horizontal: true, vertical: false) // Prevent word wrap
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                )

                HStack {
                    Button("Cancel") { dismiss() }.keyboardShortcut(.escape)
                    Spacer()
                    Button("Save") {
                        if !name.isEmpty && !remoteHost.isEmpty && !subnetsToForwardString.isEmpty {
                            let subnetsArray = subnetsToForwardString.split(separator: ",")
                                                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                                    .filter { !$0.isEmpty }
                            
                            let finalExcludedSubnets = excludedSubnetsString.trimmingCharacters(in: .whitespacesAndNewlines)
                            let finalCustomSSHCmd = customSSHCommand.trimmingCharacters(in: .whitespacesAndNewlines)

                            var updatedHost = SSHHostConfig(
                                id: hostToEdit?.id ?? UUID(),
                                name: name,
                                remoteHost: remoteHost,
                                subnetsToForward: subnetsArray.isEmpty ? ["0/0"] : subnetsArray,
                                forwardDNS: forwardDNS,
                                autoAddHostnames: autoAddHostnames,
                                excludedSubnetsString: finalExcludedSubnets.isEmpty ? nil : finalExcludedSubnets,
                                customSSHCommand: finalCustomSSHCmd.isEmpty ? nil : finalCustomSSHCmd
                            )
                            if hostToEdit != nil {
                                 updatedHost.status = hostToEdit?.status ?? .disconnected
                            }
                            onSave(updatedHost)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || remoteHost.isEmpty || subnetsToForwardString.isEmpty)
                }
                .padding(.top)
                .padding(.bottom)
            }
        }
        .padding()
        .frame(width: 480)
    }
}

struct AddHostView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AddHostView(onSave: { _ in })
                .previewDisplayName("Add New Host")
                .frame(height: 500)

            AddHostView(host: SSHHostConfig(name: "Sample Edit Long Name For Advanced Options To Test Wrapping Potentially", remoteHost: "edit@me.com", subnetsToForward: ["1.2.3.0/24"], forwardDNS: true, autoAddHostnames: false, excludedSubnetsString: "1.1.1.1", customSSHCommand: "ssh -p 2200"), onSave: { _ in })
                .previewDisplayName("Edit Host with Advanced")
                .frame(height: 550)
        }
    }
}
