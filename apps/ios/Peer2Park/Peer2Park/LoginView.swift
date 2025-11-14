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

    // New: read the session-only manager and the dismiss environment
    @EnvironmentObject private var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Modern dark blue gradient background
            LinearGradient(
                colors: [Color(red: 6/255, green: 18/255, blue: 82/255), Color(red: 10/255, green: 44/255, blue: 120/255)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle decorative radial glow
            RadialGradient(gradient: Gradient(colors: [Color.white.opacity(0.03), Color.clear]), center: .topLeading, startRadius: 20, endRadius: 500)
                .blendMode(.overlay)
                .ignoresSafeArea()

            // Login card
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)

                    // Brand
                    VStack(spacing: 12) {
                        Image("peer2park_white_transparent")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 256, height: 256)
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 6)

                        Text("Peer2Park")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Sign in with the email and password you'll use for your parking account.")
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color.white.opacity(0.85))
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 8)

                    // Card
                    VStack(spacing: 16) {
                        // Email
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email")
                                .font(.caption)
                                .foregroundColor(Color.white.opacity(0.8))
                            TextField("you@domain.com", text: $email)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .focused($focus, equals: .email)
                                .padding(12)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                                .accessibilityHint("Enter the email associated with your Peer2Park profile.")
                        }

                        // Password
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(.caption)
                                .foregroundColor(Color.white.opacity(0.8))
                            SecureField("Password", text: $password)
                                .textContentType(.password)
                                .focused($focus, equals: .password)
                                .padding(12)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                                .accessibilityHint("Enter your password.")
                        }

                        Toggle(isOn: $rememberDevice) {
                            Text("Stay signed in on this device")
                                .font(.footnote)
                                .foregroundColor(Color.white.opacity(0.9))
                        }

                        // Primary action
                        Button {
                            Task { await performPlaceholderLogin() }
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Continue")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(colors: [Color(red: 0/255, green: 160/255, blue: 255/255), Color(red: 0/255, green: 110/255, blue: 255/255)], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 6)
                        }
                        .disabled(isLoading || email.isEmpty || password.isEmpty)
                        .accessibilityLabel("Continue to Peer2Park")
                        .accessibilityHint("Runs a placeholder action until the backend is connected.")

                        if let statusMessage {
                            Text(statusMessage)
                                .font(.footnote)
                                .foregroundStyle(Color.white.opacity(0.85))
                                .padding(.top, 4)
                                .accessibilityIdentifier("loginStatusMessage")
                        }
                    }
                    .padding(20)
                    .background(BlurView(style: .systemThinMaterialDark).background(Color.white.opacity(0.02)))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)


                    Text("You can manage permissions anytime in Settings.")
                        .font(.footnote)
                        .foregroundColor(Color.white.opacity(0.7))
                        .padding(.bottom, 24)
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
            // Auto-dismiss if already confirmed this session
            .onAppear {
                if sessionManager.didConfirmLoginThisSession {
                    dismiss()
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

            // Mark that the user confirmed during this session and dismiss the login UI
            sessionManager.didConfirmLoginThisSession = true
            dismiss()
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(SessionManager())
}

// Small helper blur view to get a translucent card background
fileprivate struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
