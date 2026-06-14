import SwiftUI

struct SignInView: View {
    @Environment(AuthManager.self) private var auth
    @State private var email = ""
    @State private var password = ""
    @State private var appear = false
    @FocusState private var focused: Field?

    enum Field { case email, password }

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && !auth.isLoading
    }

    var body: some View {
        ZStack {
            CartographicBackdrop()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                hero
                    .padding(.bottom, 40)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 12)

                form
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 16)

                Spacer(minLength: 0)

                footer
                    .opacity(appear ? 1 : 0)
            }
            .padding(.horizontal, 28)
        }
        .background(Color.atlasBackgroundDeep.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appear = true }
        }
        .onSubmit(handleSubmit)
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.atlasAccent.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.atlasAccent.opacity(0.35), lineWidth: 1)
                    )
                    .frame(width: 68, height: 68)
                Text("A")
                    .font(.system(size: 38, weight: .bold, design: .serif))
                    .foregroundStyle(Color.atlasAccent)
            }
            .shadow(color: Color.atlasAccent.opacity(0.25), radius: 24, y: 8)

            VStack(spacing: 7) {
                Text("Atlas")
                    .font(.system(size: 40, weight: .bold, design: .serif))
                    .foregroundStyle(Color.atlasText)

                Text("CHART EVERYWHERE YOU'VE BEEN")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(2.5)
                    .foregroundStyle(Color.atlasInkFaint)
            }
        }
    }

    // MARK: Form

    private var form: some View {
        VStack(spacing: 14) {
            appleButton
            googleButton

            HStack(spacing: 12) {
                Rectangle().fill(Color.atlasBorder).frame(height: 1)
                Text("or")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.atlasInkFaint)
                Rectangle().fill(Color.atlasBorder).frame(height: 1)
            }
            .padding(.vertical, 2)

            FieldRow(
                icon: "envelope",
                placeholder: "Email",
                text: $email,
                isFocused: focused == .email,
                isSecure: false
            )
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .focused($focused, equals: .email)
            .submitLabel(.next)

            FieldRow(
                icon: "lock",
                placeholder: "Password",
                text: $password,
                isFocused: focused == .password,
                isSecure: true
            )
            .textContentType(.password)
            .focused($focused, equals: .password)
            .submitLabel(.go)

            if let error = auth.error {
                ErrorBanner(message: error)
                    .transition(.opacity)
            }

            signInButton
                .padding(.top, 6)
        }
    }

    private var appleButton: some View {
        Button {
            Task { await auth.signInWithApple() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 17, weight: .medium))
                Text("Sign in with Apple")
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(.black)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(.white)
            )
        }
        .disabled(auth.isLoading)
    }

    private var googleButton: some View {
        Button {
            Task { await auth.signInWithGoogle() }
        } label: {
            HStack(spacing: 9) {
                Text("G")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                Text("Continue with Google")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.atlasInk2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.atlasSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color.atlasBorder, lineWidth: 1)
            )
        }
        .disabled(auth.isLoading)
    }

    private var signInButton: some View {
        Button(action: handleSubmit) {
            ZStack {
                if auth.isLoading {
                    ProgressView().tint(Color.atlasBackgroundDeep)
                } else {
                    HStack(spacing: 8) {
                        Text("Sign in")
                            .font(.system(size: 16, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(canSubmit ? Color.atlasBackgroundDeep : Color.atlasInkFaint)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(canSubmit ? Color.atlasAccent : Color.atlasSurface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(canSubmit ? Color.clear : Color.atlasBorder, lineWidth: 1)
            )
            .shadow(color: canSubmit ? Color.atlasAccent.opacity(0.3) : .clear, radius: 16, y: 6)
        }
        .disabled(!canSubmit)
        .animation(.easeOut(duration: 0.2), value: canSubmit)
    }

    private var footer: some View {
        HStack(spacing: 5) {
            Image(systemName: "lock.shield")
                .font(.system(size: 11))
            Text("Secured by Clerk")
                .font(.system(size: 12, design: .monospaced))
        }
        .foregroundStyle(Color.atlasInkFaint)
        .padding(.bottom, 16)
    }

    private func handleSubmit() {
        if focused == .email {
            focused = .password
        } else if canSubmit {
            Task { await auth.signIn(email: email, password: password) }
        }
    }
}

// MARK: - Field

private struct FieldRow: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let isFocused: Bool
    let isSecure: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(isFocused ? Color.atlasAccent : Color.atlasInkFaint)
                .frame(width: 18)

            Group {
                if isSecure {
                    SecureField("", text: $text, prompt: prompt)
                } else {
                    TextField("", text: $text, prompt: prompt)
                }
            }
            .font(.system(size: 16))
            .foregroundStyle(Color.atlasText)
            .tint(Color.atlasAccent)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.atlasSurface.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(isFocused ? Color.atlasAccent : Color.atlasBorder, lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.18), value: isFocused)
    }

    private var prompt: Text {
        Text(placeholder).foregroundColor(Color.atlasInkFaint)
    }
}

// MARK: - Cartographic backdrop (graticule + great-circle arc)

private struct CartographicBackdrop: View {
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color.atlasBackground, Color.atlasBackgroundDeep],
                center: .top,
                startRadius: 40,
                endRadius: 620
            )

            Canvas { ctx, size in
                // graticule grid
                let step: CGFloat = 46
                var grid = Path()
                var x: CGFloat = 0
                while x <= size.width {
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                    x += step
                }
                var y: CGFloat = 0
                while y <= size.height {
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                    y += step
                }
                ctx.stroke(grid, with: .color(Color.atlasInkFaint.opacity(0.06)), lineWidth: 1)

                // signature great-circle arc
                var arc = Path()
                arc.move(to: CGPoint(x: -20, y: size.height * 0.78))
                arc.addCurve(
                    to: CGPoint(x: size.width + 20, y: size.height * 0.46),
                    control1: CGPoint(x: size.width * 0.3, y: size.height * 0.30),
                    control2: CGPoint(x: size.width * 0.62, y: size.height * 0.34)
                )
                ctx.stroke(arc, with: .color(Color.atlasAccent.opacity(0.22)),
                           style: StrokeStyle(lineWidth: 1.5, dash: [2, 6]))

                // arc endpoints as nodes
                for p in [CGPoint(x: size.width * 0.16, y: size.height * 0.52),
                          CGPoint(x: size.width * 0.84, y: size.height * 0.47)] {
                    let r: CGFloat = 3
                    let dot = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                    ctx.fill(dot, with: .color(Color.atlasAccent.opacity(0.8)))
                    let ring = Path(ellipseIn: CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14))
                    ctx.stroke(ring, with: .color(Color.atlasAccent.opacity(0.3)), lineWidth: 1)
                }
            }
        }
        .ignoresSafeArea()
    }
}
