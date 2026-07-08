import SceneKit
import simd

/// Procedural low-poly androgynous head mesh for the onboarding scan head.
///
/// The build prompt allows either the ARKit canonical face mesh or a procedural
/// mesh. We generate the head procedurally — a shaped lat/long sphere — because
/// it needs no bundled model file, produces a full head (not a face shell),
/// and works on every device *and* in the simulator (`ARSCNFaceGeometry`
/// requires TrueDepth hardware). Both meshes are computed once and cached.
enum HeadMesh {

    /// Value type wrapping fully immutable data: `SCNGeometrySource` is
    /// created once from a fixed vertex buffer and never mutated afterwards,
    /// so sharing the cached mesh across isolation domains is safe — hence
    /// `@unchecked Sendable` (SceneKit classes carry no Sendable annotation).
    struct Mesh: @unchecked Sendable {
        let vertexSource: SCNGeometrySource
        let normalSource: SCNGeometrySource
        let lineIndices: [Int32]
        let triangleIndices: [Int32]
        /// All vertices except the duplicated pole rings (44 coincident points
        /// per pole would stack additively into a hot glow dot).
        let pointIndices: [Int32]

        /// Solid dark occluder (keeps back-side wires from reading through).
        func fillGeometry() -> SCNGeometry {
            SCNGeometry(sources: [vertexSource, normalSource],
                        elements: [SCNGeometryElement(indices: triangleIndices, primitiveType: .triangles)])
        }

        /// Lat/long wireframe.
        func wireGeometry() -> SCNGeometry {
            SCNGeometry(sources: [vertexSource],
                        elements: [SCNGeometryElement(indices: lineIndices, primitiveType: .line)])
        }

        /// Glowing vertex point cloud.
        func pointsGeometry(pointSize: CGFloat) -> SCNGeometry {
            let element = SCNGeometryElement(indices: pointIndices, primitiveType: .point)
            element.pointSize = pointSize
            element.minimumPointScreenSpaceRadius = 1
            element.maximumPointScreenSpaceRadius = pointSize
            return SCNGeometry(sources: [vertexSource], elements: [element])
        }
    }

    /// Hero mesh, ~1.8k vertices — wireframe + points.
    static let lowPoly: Mesh = build(stacks: 40, slices: 44)

    /// Denser, calmer mesh the "Ceiling" beat crossfades to.
    static let dense: Mesh = build(stacks: 80, slices: 88)

    // MARK: Construction

    private static func build(stacks: Int, slices: Int) -> Mesh {
        var positions: [SCNVector3] = []
        var normals: [SCNVector3] = []
        positions.reserveCapacity((stacks + 1) * slices)
        normals.reserveCapacity((stacks + 1) * slices)

        for i in 0...stacks {
            let theta = Float(i) / Float(stacks) * .pi
            for j in 0..<slices {
                let phi = Float(j) / Float(slices) * 2 * .pi
                // Unit sphere, y up, +z facing the camera.
                let dir = SIMD3<Float>(sin(theta) * sin(phi), cos(theta), sin(theta) * cos(phi))
                let p = shape(dir)
                positions.append(SCNVector3(p.x, p.y, p.z))
                let n = simd_normalize(p)
                normals.append(SCNVector3(n.x, n.y, n.z))
            }
        }

        func index(_ i: Int, _ j: Int) -> Int32 { Int32(i * slices + (j % slices)) }

        var lines: [Int32] = []
        var triangles: [Int32] = []
        for i in 0..<stacks {
            for j in 0..<slices {
                let a = index(i, j)
                let b = index(i, j + 1)
                let c = index(i + 1, j)
                let d = index(i + 1, j + 1)
                lines.append(contentsOf: [a, c])                       // meridian segment
                if i > 0 { lines.append(contentsOf: [a, b]) }          // ring (skip pole)
                triangles.append(contentsOf: [a, c, b, b, c, d])
            }
        }

        return Mesh(
            vertexSource: SCNGeometrySource(vertices: positions),
            normalSource: SCNGeometrySource(normals: normals),
            lineIndices: lines,
            triangleIndices: triangles,
            pointIndices: Array(Int32(slices)..<Int32(stacks * slices))
        )
    }

    // MARK: Head shaping

    /// Deforms a unit-sphere direction into an androgynous head.
    /// The silhouette was validated visually (side + front profile renders)
    /// before porting: round cranium, full occiput, flat face plane with a
    /// soft nose/brow, late jaw taper into a ROUNDED chin — never a spike.
    private static func shape(_ dir: SIMD3<Float>) -> SIMD3<Float> {
        var p = dir * SIMD3<Float>(0.74, 1.0, 0.88)
        p.y *= 1.14

        // Skull width: wide through temples/cheeks, tapering late into a
        // rounded chin (cubic taper + a small bulge right at the chin tip).
        let t = min(max((0.30 - dir.y) / 1.30, 0), 1)
        var w = 1 - 0.34 * t * t * t * 2.2
        w = max(w, 0.60)
        w += 0.05 * gauss((dir.y + 0.92) / 0.22)
        w *= 1 - 0.05 * smoothstep(0.55, 1.0, dir.y)
        p.x *= w
        p.z *= w

        let front = max(0, dir.z)
        let back = smoothstep(0.15, -0.25, dir.z)

        // Full back of the skull, flatter face plane, slanted forehead.
        p.z *= 0.93 + 0.17 * back
        p.z *= 1 - 0.07 * smoothstep(0.25, 0.85, dir.y) * front

        // Chin mass, pulled slightly forward and down.
        if dir.z > 0 {
            p.z += 0.10 * gauss(dir.x / 0.30) * gauss((dir.y + 0.80) / 0.30)
        }
        p.y -= 0.04 * gauss(dir.x / 0.35) * gauss((dir.y + 0.85) / 0.25)

        // Nose: a soft, wide ridge. Brow, eye sockets, lips — subtle.
        p.z += 0.12 * gauss(dir.x / 0.20) * gauss((dir.y + 0.10) / 0.20) * front
        p.z += 0.05 * gauss((dir.y - 0.32) / 0.16) * gauss(dir.x / 0.55) * front
        p.z -= 0.05 * (gauss((dir.x - 0.28) / 0.16) + gauss((dir.x + 0.28) / 0.16))
                    * gauss((dir.y - 0.05) / 0.13) * front
        p.z += 0.02 * gauss(dir.x / 0.25) * gauss((dir.y + 0.45) / 0.10) * front

        return p
    }

    private static func gauss(_ x: Float) -> Float { exp(-x * x) }

    private static func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
