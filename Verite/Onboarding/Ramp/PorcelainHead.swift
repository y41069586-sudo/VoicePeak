import Foundation
import SceneKit
import SwiftUI
import simd

// ============================================================
// MARK: — The Porcelain Bust (Lumière's head)
// ============================================================
//
// The onboarding head, reborn for the light stage: the same real human head
// mesh (CC0 MakeHuman base, bundled as HeadMeshLow.json) — but rendered as a
// SOLID matte-ceramic sculpture under warm studio light with a soft rose rim,
// not as a neon wireframe. A beauty-editorial bust, slowly turning.
//
// The old scan-terminal renderer (wireframe + additive glow + sweep shader)
// was removed with the dark theme; this file is its calm replacement.

enum PorcelainHeadMesh {

    /// Immutable geometry data, built once. `SCNGeometry` isn't Sendable-
    /// annotated but is never mutated after creation — safe to share.
    struct Mesh: @unchecked Sendable {
        let geometry: SCNGeometry
    }

    static let shared: Mesh? = load()

    private struct MeshFile: Decodable {
        let positions: [Float]   // x,y,z flattened
        let triangles: [Int32]   // index triples
    }

    private static func load() -> Mesh? {
        guard let url = Bundle.main.url(forResource: "HeadMeshLow", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(MeshFile.self, from: data),
              file.positions.count % 3 == 0,
              file.triangles.count % 3 == 0,
              !file.triangles.isEmpty
        else { return nil }

        let count = file.positions.count / 3
        guard count > 3, Int((file.triangles.max() ?? 0)) < count else { return nil }

        var positions: [SIMD3<Float>] = []
        positions.reserveCapacity(count)
        for k in stride(from: 0, to: file.positions.count, by: 3) {
            positions.append(SIMD3(file.positions[k], file.positions[k + 1], file.positions[k + 2]))
        }

        // Smooth per-vertex normals (area-weighted face-normal average) —
        // a solid PBR surface needs real normals, unlike the old constant-
        // lit wireframe.
        var normals = [SIMD3<Float>](repeating: .zero, count: count)
        for t in stride(from: 0, to: file.triangles.count, by: 3) {
            let ia = Int(file.triangles[t])
            let ib = Int(file.triangles[t + 1])
            let ic = Int(file.triangles[t + 2])
            let a = positions[ia], b = positions[ib], c = positions[ic]
            let n = simd_cross(b - a, c - a) // length ∝ area → weighting for free
            normals[ia] += n
            normals[ib] += n
            normals[ic] += n
        }
        let vertexNormals: [SCNVector3] = normals.map { n in
            let v = simd_length(n) > 0 ? simd_normalize(n) : SIMD3<Float>(0, 0, 1)
            return SCNVector3(v.x, v.y, v.z)
        }
        let vertices: [SCNVector3] = positions.map { SCNVector3($0.x, $0.y, $0.z) }

        // Matte porcelain: warm cream diffuse, high roughness, no metalness.
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = UIColor(red: 0.95, green: 0.91, blue: 0.87, alpha: 1)
        material.roughness.contents = 0.62
        material.metalness.contents = 0.0
        material.isDoubleSided = false

        let geometry = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: vertices),
                SCNGeometrySource(normals: vertexNormals),
            ],
            elements: [SCNGeometryElement(indices: file.triangles, primitiveType: .triangles)]
        )
        geometry.materials = [material]
        return Mesh(geometry: geometry)
    }
}

// ============================================================
// MARK: — Scene container
// ============================================================

/// Owns the tiny sculpture scene: bust + three-point studio light
/// (warm key, lilac fill, rose rim) and the slow ambient turn.
@MainActor
final class PorcelainHeadController {

    let scene = SCNScene()
    private let spin = SCNNode()

    init() {
        scene.background.contents = UIColor.clear

        if let mesh = PorcelainHeadMesh.shared {
            let head = SCNNode(geometry: mesh.geometry)
            spin.addChildNode(head)
        }
        // Rest the bust in a gentle three-quarter tilt.
        spin.eulerAngles = SCNVector3(-0.04, 0.35, 0)
        scene.rootNode.addChildNode(spin)

        // Warm key light — upper left, like window light in a studio.
        addLight(type: .directional, color: UIColor(red: 1.0, green: 0.94, blue: 0.86, alpha: 1),
                 intensity: 780, position: SCNVector3(-2.5, 2.6, 2.6))
        // Cool lilac fill — soft, from the right.
        addLight(type: .directional, color: UIColor(red: 0.87, green: 0.82, blue: 0.92, alpha: 1),
                 intensity: 320, position: SCNVector3(2.6, 0.4, 1.8))
        // Dusty-rose rim — from behind, catches the profile edge.
        addLight(type: .directional, color: UIColor(red: 0.86, green: 0.58, blue: 0.63, alpha: 1),
                 intensity: 420, position: SCNVector3(1.6, 1.2, -2.8))
        // Ambient floor so shadows stay porcelain, never black.
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(red: 0.93, green: 0.89, blue: 0.86, alpha: 1)
        ambient.light?.intensity = 420
        scene.rootNode.addChildNode(ambient)

        let camera = SCNCamera()
        camera.fieldOfView = 34
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0.05, 4.4)
        scene.rootNode.addChildNode(cameraNode)
    }

    private func addLight(type: SCNLight.LightType, color: UIColor,
                          intensity: CGFloat, position: SCNVector3) {
        let node = SCNNode()
        node.light = SCNLight()
        node.light?.type = type
        node.light?.color = color
        node.light?.intensity = intensity
        node.position = position
        node.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(node)
    }

    /// One slow, museum-turntable rotation. Reduce Motion holds the pose.
    func setTurning(_ on: Bool) {
        if on, spin.action(forKey: "turn") == nil {
            let turn = SCNAction.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: 46)
            spin.runAction(.repeatForever(turn), forKey: "turn")
        } else if !on {
            spin.removeAction(forKey: "turn")
        }
    }
}

// ============================================================
// MARK: — SwiftUI wrapper (drop-in where the orb lived)
// ============================================================

/// The bust as a plain SwiftUI view, staged (scale/offset/opacity) by the
/// flow exactly like the orb was. Falls back to the TeintOrb when the mesh
/// resource is unavailable, so the flow can never lose its hero.
struct PorcelainHeadView: View {
    var haloed: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var controller = PorcelainHeadController()

    var body: some View {
        ZStack {
            if haloed {
                Circle()
                    .fill(RadialGradient(colors: [RampStage.glow.opacity(0.5), .clear],
                                         center: .center, startRadius: 0, endRadius: 170))
                    .frame(width: 340, height: 340)
                    .blur(radius: 10)
            }
            if PorcelainHeadMesh.shared != nil {
                PorcelainSceneView(controller: controller)
                    .frame(width: 300, height: 340)
                    .shadow(color: RampStage.accent.opacity(0.28), radius: 30, y: 18)
            } else {
                TeintOrb(haloed: false)
            }
        }
        .onAppear { controller.setTurning(!reduceMotion) }
        .accessibilityHidden(true)
    }
}

private struct PorcelainSceneView: UIViewRepresentable {
    let controller: PorcelainHeadController

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = controller.scene
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.autoenablesDefaultLighting = false
        view.isUserInteractionEnabled = false
        view.isPlaying = true
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {}
}
