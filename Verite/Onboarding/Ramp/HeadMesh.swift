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

    struct Mesh {
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
    /// Purely aesthetic — tuned by eye for the wireframe look.
    private static func shape(_ dir: SIMD3<Float>) -> SIMD3<Float> {
        var p = dir * SIMD3<Float>(0.78, 1.0, 0.90) // narrower than deep, deep < tall
        p.y *= 1.12                                  // elongate the skull

        // Jaw taper below the brow line; chin narrows most.
        let lower = 1 - smoothstep(-0.95, 0.12, dir.y)
        p.x *= 1 - 0.36 * lower * lower
        p.z *= 1 - 0.16 * lower * lower

        let front = max(0, dir.z)

        // Chin nudged forward; back of the skull stays full.
        if dir.z > 0 {
            p.z += 0.08 * lower * lower * gauss(dir.x / 0.30)
        } else {
            p.z *= 1.05
        }

        // Brow ridge, eye sockets, nose, lips — subtle, wireframe-legible.
        p.z += 0.05 * gauss((dir.y - 0.28) / 0.10) * gauss(dir.x / 0.50) * front
        p.z -= 0.055 * (gauss((dir.x - 0.30) / 0.14) + gauss((dir.x + 0.30) / 0.14))
                     * gauss((dir.y - 0.10) / 0.10) * front
        p.z += 0.16 * gauss(dir.x / 0.14) * gauss((dir.y + 0.16) / 0.13) * front
        p.z += 0.035 * gauss(dir.x / 0.24) * gauss((dir.y + 0.42) / 0.07) * front

        return p
    }

    private static func gauss(_ x: Float) -> Float { exp(-x * x) }

    private static func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
