import SwiftUI
import AVFoundation
import CoreMotion
import CoreLocation

// MARK: - ARSkyView  (entry point, full-screen cover)

struct ARSkyView: View {
    @Environment(AuthManager.self) private var auth

    /// Passed in from SkyView so we share the same location fix.
    let locationProvider: LocationProvider

    @State private var vm = ARSkyViewModel()
    @State private var selectedAircraft: OverheadAircraft? = nil

    // Camera permission state
    @State private var cameraPermission: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            switch cameraPermission {
            case .authorized:
                arContent
            case .denied, .restricted:
                cameraPermissionDenied
            default:
                // .notDetermined — show camera immediately then check
                arContent
                    .task { await requestCameraPermission() }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .sheet(item: $selectedAircraft) { ac in
            AircraftDetailSheet(
                aircraft: ac,
                userCoordinate: locationProvider.coordinate,
                isFollowed: false,
                onFollow: {}
            )
            .presentationDetents([.large])
            .presentationBackground(Color.atlasBackground)
            .presentationDragIndicator(.visible)
        }
        .task {
            await requestCameraPermission()
            vm.startUpdates(api: auth.api, location: locationProvider)
        }
        .onDisappear {
            vm.stopUpdates()
        }
    }

    // MARK: - Main AR content

    private var arContent: some View {
        ZStack {
            // Camera preview layer
            CameraPreviewView()
                .ignoresSafeArea()

            // Aircraft labels overlay
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                ZStack {
                    ForEach(vm.projected.filter(\.isVisible)) { proj in
                        let x = proj.screenX * w
                        let y = proj.screenY * h
                        let isNearest = proj.id == vm.nearestVisibleID

                        ARLabel(
                            projected: proj,
                            isHighlighted: isNearest
                        )
                        .position(x: x, y: y)
                        .onTapGesture {
                            selectedAircraft = proj.aircraft
                        }
                    }

                    // Center reticle
                    ARReticle()
                        .position(x: w / 2, y: h / 2)
                }
            }

            // HUD
            VStack {
                topHUD
                Spacer()
                if shouldShowPointHint {
                    pointHint
                        .padding(.bottom, 60)
                }
            }
            .padding(.top, 56)
        }
    }

    // MARK: - HUD

    private var topHUD: some View {
        HStack {
            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.atlasText)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }

            Spacer()

            // Heading + count pill
            HStack(spacing: 10) {
                // Compass heading
                VStack(spacing: 1) {
                    Text(compassLabel(heading: vm.deviceHeading))
                        .font(AtlasFont.mono(13, weight: .bold))
                        .foregroundStyle(Color.atlasCyan)
                    Text(String(format: "%.0f°", vm.deviceHeading))
                        .font(AtlasFont.mono(10))
                        .foregroundStyle(Color.atlasInk2)
                }

                Divider()
                    .frame(height: 24)
                    .background(Color.atlasBorder)

                // Aircraft count
                let overheadCount = vm.aircraft.count
                Text("\(overheadCount) overhead")
                    .font(AtlasFont.mono(12, weight: .medium))
                    .foregroundStyle(overheadCount > 0 ? Color.atlasText : Color.atlasInkFaint)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.atlasBorder, lineWidth: 0.5))

            Spacer()

            // Loading indicator placeholder (keeps HUD balanced)
            Group {
                if vm.isLoading {
                    ProgressView()
                        .tint(.atlasCyan)
                        .scaleEffect(0.8)
                        .frame(width: 36, height: 36)
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var pointHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.atlasAccent)
            Text("Point at the sky")
                .font(AtlasFont.body(14, weight: .medium))
                .foregroundStyle(Color.atlasText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.atlasAccent.opacity(0.3), lineWidth: 0.5))
    }

    /// Show hint when pitch is low (phone pointed at ground/horizontal).
    private var shouldShowPointHint: Bool {
        vm.devicePitch < 15 && !vm.aircraft.isEmpty
    }

    // MARK: - Camera denied

    private var cameraPermissionDenied: some View {
        ZStack {
            Color.atlasBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button top-left
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.atlasText)
                            .frame(width: 36, height: 36)
                            .background(Color.atlasSurface2, in: Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                Spacer()

                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.atlasAccent.opacity(0.1))
                            .frame(width: 72, height: 72)
                        Image(systemName: "camera.slash")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color.atlasAccent)
                    }

                    VStack(spacing: 8) {
                        Text("Camera Access Needed")
                            .font(AtlasFont.display(22, weight: .bold))
                            .foregroundStyle(Color.atlasText)
                        Text("Atlas needs camera access to overlay aircraft in the real-world view.")
                            .font(AtlasFont.body(15))
                            .foregroundStyle(Color.atlasInk2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Open Settings")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .background(AtlasGradient.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 48)
                }

                Spacer()
            }
        }
    }

    // MARK: - Permissions

    private func requestCameraPermission() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermission = .authorized
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraPermission = granted ? .authorized : .denied
        case .denied, .restricted:
            cameraPermission = .denied
        @unknown default:
            break
        }
    }

    // MARK: - Helpers

    private func compassLabel(heading: Double) -> String {
        let dirs = ["N","NNE","NE","ENE","E","ESE","SE","SSE","S","SSW","SW","WSW","W","WNW","NW","NNW"]
        let idx = Int((heading + 11.25) / 22.5) % 16
        return dirs[idx]
    }
}

// MARK: - ARLabel  (glass floating label per aircraft)

struct ARLabel: View {
    let projected: ARProjectedAircraft
    let isHighlighted: Bool

    private var ac: OverheadAircraft { projected.aircraft }
    private var tone: AtlasTone { ac.tone }

    var body: some View {
        HStack(spacing: 8) {
            // Silhouette
            let category = AircraftCategory(typeCode: ac.type, isMilitary: ac.isMilitary)
            AircraftMarker(
                category: category,
                heading: ac.track != nil ? (ac.track! - 90) : nil,  // rotate: silhouette points up, track is compass
                color: tone.color,
                baseSize: 16,
                selected: isHighlighted
            )

            // Data column
            VStack(alignment: .leading, spacing: 2) {
                // Callsign / display name
                Text(ac.displayName)
                    .font(.system(size: isHighlighted ? 13 : 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(isHighlighted ? tone.color : Color.atlasText)
                    .lineLimit(1)

                // Type + altitude
                HStack(spacing: 5) {
                    if let t = ac.type {
                        Text(t)
                            .font(AtlasFont.mono(10))
                            .foregroundStyle(Color.atlasInk2)
                    }
                    if let fl = ac.flightLevelString {
                        Text(fl)
                            .font(AtlasFont.mono(10))
                            .foregroundStyle(Color.atlasInk2)
                    }
                }

                // Distance
                Text(String(format: "%.0f km", projected.groundDistanceKm))
                    .font(AtlasFont.mono(10))
                    .foregroundStyle(tone.color.opacity(0.8))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            // Glass card
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.atlasSurface.opacity(isHighlighted ? 0.75 : 0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isHighlighted
                                ? tone.color.opacity(0.7)
                                : Color.white.opacity(0.08),
                            lineWidth: isHighlighted ? 1.5 : 0.5
                        )
                )
                .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 4)
                .shadow(color: isHighlighted ? tone.color.opacity(0.3) : .clear, radius: 16, x: 0, y: 0)
        }
        // Emergency pulse
        .overlay(alignment: .topTrailing) {
            if ac.isEmergency {
                Circle()
                    .fill(Color.atlasDanger)
                    .frame(width: 8, height: 8)
                    .offset(x: 3, y: -3)
            }
        }
        .scaleEffect(isHighlighted ? 1.05 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHighlighted)
    }
}

// MARK: - ARReticle

struct ARReticle: View {
    private let size: CGFloat = 48

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.atlasCyan.opacity(0.4), lineWidth: 1)
                .frame(width: size, height: size)

            // Cross hairs (4 ticks)
            ForEach([0.0, 90.0, 180.0, 270.0], id: \.self) { angle in
                Rectangle()
                    .fill(Color.atlasCyan.opacity(0.6))
                    .frame(width: 1, height: 8)
                    .offset(y: -(size / 2))
                    .rotationEffect(.degrees(angle))
            }

            // Center dot
            Circle()
                .fill(Color.atlasCyan)
                .frame(width: 4, height: 4)
                .shadow(color: Color.atlasCyan.opacity(0.9), radius: 4)
        }
    }
}

// MARK: - CameraPreviewView  (AVCaptureVideoPreviewLayer via UIViewRepresentable)

struct CameraPreviewView: UIViewRepresentable {
    func makeUIView(context: Context) -> CameraPreviewUIView {
        CameraPreviewUIView()
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

final class CameraPreviewUIView: UIView {
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCamera()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCamera()
    }

    private func setupCamera() {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            // Show a dark background when permission is not yet granted.
            backgroundColor = UIColor(Color.atlasBackground)
            return
        }

        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            backgroundColor = UIColor(Color.atlasBackground)
            return
        }

        session.addInput(input)

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        self.layer.addSublayer(layer)
        previewLayer = layer

        captureSession = session

        // Start session on a background thread.
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    deinit {
        captureSession?.stopRunning()
    }
}
