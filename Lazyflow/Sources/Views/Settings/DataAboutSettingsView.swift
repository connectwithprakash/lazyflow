import SwiftUI
import LazyflowCore
import LazyflowUI

struct DataAboutSettingsView: View {
    @State private var showAbout = false

    var body: some View {
        Form {
            Section("Data") {
                NavigationLink {
                    DataManagementView()
                } label: {
                    Text("Data Management")
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(Color.Lazyflow.textSecondary)
                }

                Button {
                    showAbout = true
                } label: {
                    Text("About Lazyflow")
                        .foregroundColor(Color.Lazyflow.textPrimary)
                }

                Link(destination: URL(string: "https://lazyflow.netlify.app/privacy/")!) {
                    Text("Privacy Policy")
                }

                Link(destination: URL(string: "https://lazyflow.netlify.app/terms/")!) {
                    Text("Terms of Service")
                }
            }
        }
        .settingsFormWidth()
        .navigationTitle("Data & About")
        .sheet(isPresented: $showAbout) { AboutView() }
    }
}
