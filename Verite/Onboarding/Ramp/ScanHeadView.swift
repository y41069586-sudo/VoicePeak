import SceneKit
import SwiftUI
import UIKit

// ============================================================
// MARK: — Head stage (per-screen placement)
// ============================================================

/// Where the head sits on a given onboarding screen. The SceneKit view stays
/// alive for the whole flow; screens only re-stage the head (position, scale,
/// spin pace, opacity) so the object feels continuous and premium.
struct HeadStage {
    var x: Float = 0
    var y: Float = 0
    var z: Float = 0
    var scale: CGFloat = 1
    var opacity: CGFloat = 1
    /// Seconds per full rotation. `nil` = decelerate and hold facing the camera.
    var spinDuration: Double? = 14
    var transitionDuration: Double = 0.8
}

// ============================================================
// MARK: — Controller
// ============================================================

/// Owns the SceneKit scene for the onboarding head: procedural wireframe/point
/// mesh, continuous rotation, the scan-line sweep (shader-modifier vertex
/// brightening + a visible light plane), vertex-cluster flashes, and the
/// dense-mesh "ceiling" crossfade.
@MainActor
final class ScanHeadController {

    let scene = SCNScene()

    /// Model-space regions used for cluster flashes.
    enum Cluster: CaseIterable {
        case forehead, leftCheek, rightCheek, chin

        // Anchored to the real head mesh's surface (queried from the data).
        var position: SCNVector3 {
            switch self {
            case .forehead:   return SCNVector3(0, 0.38, 0.74)
            case .leftCheek:  return SCNVector3(0.30, -0.08, 0.62)
            case .rightCheek: return SCNVector3(-0.30, -0.08, 0.62)
            case .chin:       return SCNVector3(0, -0.48, 0.72)
            }
        }
    }

    // Node graph: pivot (stage placement) → tilt (fixed pose) → spin (rotation).
    private let pivot = SCNNode()
    private let tilt = SCNNode()
    private let spin = SCNNode()

    private let fillNode: SCNNode
    private let wireNode: SCNNode
    private let pointsNode: SCNNode
    private let denseWireNode: SCNNode
    private let sweepPlane: SCNNode

    /// Materials carrying the scan-line shader modifier (`u_scanY`).
    private let scanMaterials: [SCNMaterial]

    private var currentSpinDuration: Double?

    /// Bumped on every user grab; stale fling-resume tasks check it.
    private var dragGeneration = 0
    private var dragStartAngle: Float = 0

    private let accent: UIColor

    // MARK: Init

    init() {
        // Everything is built from locals first; stored properties are assigned
        // at the end so no closure touches `self` before it is initialized.
        let accentColor = UIColor(RampStage.accent)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        accentColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let scanColor = NSValue(scnVector3: SCNVector3(Float(r), Float(g), Float(b)))

        let low = HeadMesh.lowPoly
        let dense = HeadMesh.dense

        func glowMaterial(alpha: CGFloat) -> SCNMaterial {
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = UIColor.black
            material.emission.contents = accentColor
            material.transparency = alpha
            material.blendMode = .add
            material.writesToDepthBuffer = false
            material.isDoubleSided = true
            material.shaderModifiers = [.fragment: ScanHeadController.scanFragmentModifier]
            material.setValue(NSNumber(value: -2.0), forKey: "u_scanY")
            material.setValue(scanColor, forKey: "u_scanColor")
            return material
        }

        // Solid occluder so back-side wires don't read through the face.
        let fillMaterial = SCNMaterial()
        fillMaterial.lightingModel = .constant
        fillMaterial.diffuse.contents = UIColor(red: 0.02, green: 0.035, blue: 0.08, alpha: 1)
        let fillGeometry = low.fillGeometry()
        fillGeometry.materials = [fillMaterial]
        let fill = SCNNode(geometry: fillGeometry)
        // Slightly inset so wires sit cleanly on the surface.
        fill.scale = SCNVector3(0.995, 0.995, 0.995)
        fill.renderingOrder = 0

        // Wireframe edges — accent at ~35% opacity (spec).
        let wireMaterial = glowMaterial(alpha: 0.35)
        let wireGeometry = low.wireGeometry()
        wireGeometry.materials = [wireMaterial]
        let wire = SCNNode(geometry: wireGeometry)
        wire.renderingOrder = 1

        // Vertices as small glowing points, additive.
        let pointsMaterial = glowMaterial(alpha: 0.9)
        let pointsGeometry = low.pointsGeometry(pointSize: 3.5)
        pointsGeometry.materials = [pointsMaterial]
        let points = SCNNode(geometry: pointsGeometry)
        points.renderingOrder = 2

        // Denser, calmer mesh for the "Ceiling" beat — starts invisible.
        let denseMaterial = glowMaterial(alpha: 0.16)
        let denseGeometry = dense.wireGeometry()
        denseGeometry.materials = [denseMaterial]
        let denseWire = SCNNode(geometry: denseGeometry)
        denseWire.renderingOrder = 1
        denseWire.opacity = 0

        // The visible sweep plane — accent-gradient band of light.
        let plane = SCNPlane(width: 2.9, height: 0.55)
        let planeMaterial = SCNMaterial()
        planeMaterial.lightingModel = .constant
        planeMaterial.diffuse.contents = UIColor.black
        planeMaterial.emission.contents = ScanHeadController.sweepGradientImage(color: accentColor)
        planeMaterial.blendMode = .add
        planeMaterial.writesToDepthBuffer = false
        planeMaterial.readsFromDepthBuffer = false
        planeMaterial.isDoubleSided = true
        plane.materials = [planeMaterial]
        let sweep = SCNNode(geometry: plane)
        sweep.opacity = 0
        sweep.position = SCNVector3(0, 1.4, 0.4)
        sweep.renderingOrder = 3

        accent = accentColor
        fillNode = fill
        wireNode = wire
        pointsNode = points
        denseWireNode = denseWire
        sweepPlane = sweep
        scanMaterials = [wireMaterial, pointsMaterial, denseMaterial]

        // Assemble.
        spin.addChildNode(fillNode)
        spin.addChildNode(wireNode)
        spin.addChildNode(pointsNode)
        spin.addChildNode(denseWireNode)
        tilt.addChildNode(spin)
        tilt.addChildNode(sweepPlane)
        tilt.eulerAngles.x = -0.06
        pivot.addChildNode(tilt)
        pivot.opacity = 0 // cold open fades the head in from black
        scene.rootNode.addChildNode(pivot)

        let camera = SCNCamera()
        camera.fieldOfView = 45
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0.1, 4.6)
        scene.rootNode.addChildNode(cameraNode)
        scene.background.contents = UIColor.clear
    }

    // MARK: Stage transitions

    func apply(_ stage: HeadStage, reduceMotion: Bool) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = reduceMotion ? 0.2 : stage.transitionDuration
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pivot.position = SCNVector3(stage.x, stage.y, stage.z)
        pivot.scale = SCNVector3(stage.scale, stage.scale, stage.scale)
        pivot.opacity = stage.opacity
        SCNTransaction.commit()
        // Reduce Motion: no continuous rotation, hold the current pose.
        setSpin(duration: reduceMotion ? nil : stage.spinDuration, animatedStop: !reduceMotion)
    }

    private func setSpin(duration: Double?, animatedStop: Bool) {
        applySpin(duration: duration, animatedStop: animatedStop, force: false)
    }

    private func applySpin(duration: Double?, animatedStop: Bool, force: Bool) {
        guard force || duration != currentSpinDuration || spin.action(forKey: "spin") == nil else { return }
        currentSpinDuration = duration

        // Freeze at the currently *presented* angle before changing pace.
        let angle = spin.presentation.eulerAngles.y
        spin.removeAction(forKey: "spin")
        spin.eulerAngles.y = angle

        if let duration {
            let turn = SCNAction.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: duration)
            spin.runAction(.repeatForever(turn), forKey: "spin")
        } else if animatedStop {
            // Decelerate to the next full turn so the head holds facing the camera.
            let target = (2 * CGFloat.pi) * ceil(CGFloat(angle) / (2 * .pi) + 0.001)
            let turn = SCNAction.rotateTo(x: 0, y: target, z: 0, duration: 1.6)
            turn.timingMode = .easeOut
            spin.runAction(turn, forKey: "spin")
        }
    }

    // MARK: User interaction (drag to spin)

    /// Grab the head: freeze the ambient spin at its presented angle so the
    /// finger takes over seamlessly mid-rotation.
    func beginDrag() {
        dragGeneration += 1
        let angle = spin.presentation.eulerAngles.y
        spin.removeAction(forKey: "spin")
        spin.eulerAngles.y = angle
        dragStartAngle = angle
    }

    /// Live drag: rotate by the finger's horizontal travel.
    func dragBy(radians: Float) {
        spin.eulerAngles.y = dragStartAngle + radians
    }

    /// Release: fling with the remaining velocity, decelerate, then hand
    /// control back to the ambient spin of the current stage.
    func endDrag(velocity radiansPerSecond: Float) {
        let generation = dragGeneration
        let clamped = max(-14, min(14, radiansPerSecond))
        let fling = SCNAction.rotateBy(x: 0, y: CGFloat(clamped) * 0.32, z: 0, duration: 0.85)
        fling.timingMode = .easeOut
        spin.runAction(fling, forKey: "spin")
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(880))
            guard let self, self.dragGeneration == generation else { return }
            self.applySpin(duration: self.currentSpinDuration, animatedStop: true, force: true)
        }
    }

    // MARK: Scan-line sweep

    /// One vertical top→bottom sweep: the light plane travels down while the
    /// shader uniform brightens vertices inside the band as it passes.
    func sweep(duration: Double, delay: Double = 0) {
        let top: CGFloat = 1.4
        let bottom: CGFloat = -1.5

        sweepPlane.removeAllActions()
        sweepPlane.position = SCNVector3(0, Float(top), 0.4)
        let travel = SCNAction.moveBy(x: 0, y: bottom - top, z: 0, duration: duration)
        travel.timingMode = .easeInEaseOut
        sweepPlane.runAction(.sequence([
            .wait(duration: delay),
            .fadeOpacity(to: 0.8, duration: 0.15),
            travel,
            .fadeOpacity(to: 0, duration: 0.25),
        ]))

        for material in scanMaterials {
            let animation = CABasicAnimation(keyPath: "u_scanY")
            animation.fromValue = Float(top)
            animation.toValue = Float(bottom)
            animation.duration = duration
            animation.beginTime = CACurrentMediaTime() + delay + 0.15
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            material.setValue(NSNumber(value: Float(bottom)), forKey: "u_scanY")
            material.addAnimation(animation, forKey: "scanSweep")
        }
    }

    // MARK: Cluster flashes

    /// Brief additive flash at a face region (quiz absorption, "Score" beat).
    func flash(_ cluster: Cluster) {
        let sphere = SCNSphere(radius: 0.11)
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = UIColor.black
        material.emission.contents = accent
        material.blendMode = .add
        material.writesToDepthBuffer = false
        sphere.materials = [material]

        let node = SCNNode(geometry: sphere)
        node.position = cluster.position
        node.opacity = 0
        node.renderingOrder = 4
        spin.addChildNode(node)
        node.runAction(.sequence([
            .group([.fadeOpacity(to: 0.85, duration: 0.10), .scale(to: 1.5, duration: 0.10)]),
            .group([.fadeOut(duration: 0.45), .scale(to: 2.6, duration: 0.45)]),
            .removeFromParentNode(),
        ]))
    }

    // MARK: Ceiling crossfade

    /// Crossfades the raw wireframe into the denser, calmer mesh ("your 10/10").
    func setCeilingMode(_ on: Bool) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.9
        denseWireNode.opacity = on ? 0.9 : 0
        wireNode.opacity = on ? 0.12 : 1
        pointsNode.opacity = on ? 0.18 : 1
        SCNTransaction.commit()
    }

    // MARK: Shader

    /// Fragment shader modifier: vertices/edges inside a horizontal band around
    /// `u_scanY` (model space) brighten as the sweep plane passes them.
    private static let scanFragmentModifier = """
    #pragma arguments
    float u_scanY;
    float3 u_scanColor;
    #pragma body
    float4 v_model = scn_node.inverseModelViewTransform * float4(_surface.position, 1.0);
    float band = 1.0 - smoothstep(0.0, 0.22, abs(v_model.y - u_scanY));
    _output.color.rgb += u_scanColor * band * band * 1.6;
    """

    /// Soft vertical accent gradient for the sweep plane (clear → accent → clear).
    private static func sweepGradientImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 8, height: 64)
        return UIGraphicsImageRenderer(size: size).image { context in
            let colors = [color.withAlphaComponent(0).cgColor,
                          color.withAlphaComponent(0.9).cgColor,
                          color.withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors,
                                            locations: [0, 0.5, 1]) else { return }
            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: 0, y: size.height),
                options: []
            )
        }
    }
}

// ============================================================
// MARK: — SwiftUI wrapper
// ============================================================

/// The persistent SceneKit layer behind every onboarding screen.
/// 60fps target; the mesh is cached, materials are additive-only, and there is
/// no per-frame Swift work — rotation and sweeps run as SceneKit actions.
struct ScanHeadSceneView: UIViewRepresentable {
    let controller: ScanHeadController

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
