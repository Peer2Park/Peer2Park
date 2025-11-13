import SwiftUI

struct LoginView: View {
    enum FocusField: Hashable {
        case email
        case password
    }

    @FocusState private var focus: FocusField?
    @State private var email = ""
    @State private var password = ""
    @State private var rememberDevice = false
    @State private var isLoading = false
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Image("peer2park")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .cornerRadius(24)
                            .accessibilityHidden(true)

                        Text("Peer2Park")
                            .font(.title.bold())
                        Text("Sign in with the email and password you'll use for your parking account.")
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)
                .accessibilityElement(children: .combine)

                Section("Account") {
                    TextField("Email address", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .submitLabel(.next)
                        .focused($focus, equals: .email)
                        .accessibilityHint("Enter the email associated with your Peer2Park profile.")

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .submitLabel(.go)
                        .focused($focus, equals: .password)
                        .accessibilityHint("Enter your password.")

                    Toggle("Stay signed in on this device", isOn: $rememberDevice)
                        .accessibilityHint("Leave on if you don't want to log in every time.")
                }

                Section {
                    Button {
                        Task { await performPlaceholderLogin() }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .accessibilityLabel("Signing in")
                            } else {
                                Text("Continue")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    .accessibilityLabel("Continue to Peer2Park")
                    .accessibilityHint("Runs a placeholder action until the backend is connected.")
                }

                if let statusMessage {
                    Section("Status") {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("loginStatusMessage")
                    }
                }
            }
            .navigationTitle("Sign in")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focus = nil
                    }
                }
            }
        }
    }

    private func performPlaceholderLogin() async {
        await MainActor.run {
            isLoading = true
            statusMessage = nil
        }

        try? await Task.sleep(nanoseconds: 1_000_000_000)

        await MainActor.run {
            isLoading = false
            statusMessage = "Email sign-in is coming soon. Please use the other tabs while we finish hooking it up."
        }
    }
}

#Preview {
    LoginView()
}
