import SwiftUI

struct SignInView: View {
    @Environment(AuthManager.self) private var auth
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focused: Field?

    enum Field { case email, password }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo
            VStack(spacing: 8) {
                Text("A")
                    .font(.system(size: 48, weight: .bold, design: .serif))
                    .foregroundStyle(Color.atlasAccent)
                Text("Atlas")
                    .font(AtlasFont.display(28))
                    .foregroundStyle(Color.atlasText)
                Text("Travel Intelligence")
                    .font(AtlasFont.body(13))
                    .foregroundStyle(Color.atlasMuted)
            }
            .padding(.bottom, 48)

            // Form
            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focused, equals: .email)
                    .padding()
                    .background(Color.atlasSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(focused == .email ? Color.atlasAccent : Color.atlasBorder, lineWidth: 1)
                    )
                    .foregroundStyle(Color.atlasText)

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .focused($focused, equals: .password)
                    .padding()
                    .background(Color.atlasSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(focused == .password ? Color.atlasAccent : Color.atlasBorder, lineWidth: 1)
                    )
                    .foregroundStyle(Color.atlasText)
            }
            .padding(.horizontal, 24)

            if let error = auth.error {
                ErrorBanner(message: error)
                    .padding(.top, 12)
            }

            Button {
                Task { await auth.signIn(email: email, password: password) }
            } label: {
                Group {
                    if auth.isLoading {
                        ProgressView().tint(Color.atlasBackground)
                    } else {
                        Text("Sign In")
                            .font(AtlasFont.body(15, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .background(
                email.isEmpty || password.isEmpty || auth.isLoading
                    ? Color.atlasBorder
                    : Color.atlasAccent
            )
            .foregroundStyle(Color.atlasBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .disabled(email.isEmpty || password.isEmpty || auth.isLoading)

            Spacer()
            Spacer()
        }
        .background(Color.atlasBackground.ignoresSafeArea())
        .onSubmit {
            if focused == .email { focused = .password }
            else if !email.isEmpty && !password.isEmpty {
                Task { await auth.signIn(email: email, password: password) }
            }
        }
    }
}
