import SwiftUI

struct PreferencesView: View {
    @ObservedObject var appDelegate: AppDelegate
    
    @State private var showingConfigSheet = false
    @State private var hostToEdit: SSHHostConfig? = nil
    @State private var selection: UUID?

    var body: some View {
        VStack {
            Text("SSH Host Configurations")
                .font(.title2)
                .padding(.top)

            if appDelegate.hostConfigurations.isEmpty {
                HStack {
                    Spacer()
                    Text("No SSH host configurations yet. Click '+' to add one.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
            } else {
                List(selection: $selection) {
                    ForEach(appDelegate.hostConfigurations) { hostConfig in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(hostConfig.name)
                                    .font(.headline)
                                Text("Remote: \(hostConfig.remoteHost)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("Subnets: \(hostConfig.subnetsToForward.joined(separator: ", "))")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                // Optionally, indicate if advanced options are set:
                                if hostConfig.excludedSubnetsString != nil || hostConfig.customSSHCommand != nil {
                                    Text("Advanced options configured")
                                        .font(.caption2)
                                        .italic()
                                        .foregroundColor(.orange)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .tag(hostConfig.id)
                    }
                }
            }

            HStack {
                Button(action: {
                    hostToEdit = nil
                    showingConfigSheet = true
                }) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add")
                }
                
                Button(action: {
                    if let selectedID = selection,
                       let selectedHost = appDelegate.hostConfigurations.first(where: { $0.id == selectedID }) {
                        hostToEdit = selectedHost
                        showingConfigSheet = true
                    }
                }) {
                    Image(systemName: "pencil.circle.fill")
                    Text("Edit")
                }
                .disabled(selection == nil)
                
                Button(action: {
                    removeSelectedHost()
                }) {
                    Image(systemName: "minus.circle.fill")
                    Text("Remove")
                }
                .disabled(selection == nil || appDelegate.hostConfigurations.isEmpty)
                
                Spacer()
            }
            .padding()

        }
        .frame(minWidth: 580, minHeight: 500) // Matches window size in AppDelegate
        .sheet(isPresented: $showingConfigSheet) {
            if let host = hostToEdit {
                AddHostView(host: host) { updatedHostConfig in
                    if let index = appDelegate.hostConfigurations.firstIndex(where: { $0.id == updatedHostConfig.id }) {
                        appDelegate.hostConfigurations[index] = updatedHostConfig
                    }
                }
            } else {
                AddHostView { newHostConfig in
                    appDelegate.hostConfigurations.append(newHostConfig)
                }
            }
        }
    }

    private func removeSelectedHost() {
        guard let selectedID = selection else { return }
        appDelegate.hostConfigurations.removeAll { $0.id == selectedID }
        selection = nil
    }
}

struct PreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        let dummyAppDelegate = AppDelegate()
        dummyAppDelegate.hostConfigurations.append(
            SSHHostConfig(name: "Preview Host", remoteHost: "user@preview", subnetsToForward: ["0/0"], forwardDNS: true, autoAddHostnames: true, excludedSubnetsString: "10.0.0.1", customSSHCommand: "ssh -X")
        )
        return PreferencesView(appDelegate: dummyAppDelegate)
    }
}
