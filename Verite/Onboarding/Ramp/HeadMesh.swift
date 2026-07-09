import Foundation
import SceneKit
import simd

/// The onboarding scan-head mesh.
///
/// The geometry is a REAL human head: extracted offline from the MakeHuman
/// base mesh (explicitly released as CC0 — license header ships in the
/// source file), head + neck cut from the body group, internal geometry
/// (mouth bag, eye backing) removed via a multi-view z-buffer visibility
/// pass, normalized and exported as bundled JSON with explicit topology:
/// `HeadMeshLow.json` (~3.9k verts, quad wireframe) and `HeadMeshDense.json`
/// (~15k verts, one subdivision + smoothing, for the "Ceiling" crossfade).
/// The app only loads vertices + indices — no runtime shape math.
/// A simple procedural head remains as a fallback if a resource fails.
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
        /// Subsampled vertices used for the glowing point cloud.
        let pointIndices: [Int32]

        /// Solid dark occluder (keeps back-side wires from reading through).
        func fillGeometry() -> SCNGeometry {
            SCNGeometry(sources: [vertexSource, normalSource],
                        elements: [SCNGeometryElement(indices: triangleIndices, primitiveType: .triangles)])
        }

        /// Quad-edge wireframe.
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

    /// Hero mesh — wireframe + points.
    static let lowPoly: Mesh = loadMesh("HeadMeshLow") ?? build(stacks: 40, slices: 44)

    /// Denser, calmer mesh the "Ceiling" beat crossfades to.
    static let dense: Mesh = loadMesh("HeadMeshDense") ?? build(stacks: 80, slices: 88)

    // MARK: Bundled mesh loading (explicit topology)

    private struct MeshFile: Decodable {
        let positions: [Float]   // x,y,z flattened
        let lines: [Int32]       // index pairs
        let triangles: [Int32]   // index triples
        let points: [Int32]      // vertex subsample for the point cloud
    }

    private static func loadMesh(_ name: String) -> Mesh? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(MeshFile.self, from: data),
              file.positions.count % 3 == 0
        else { return nil }

        let count = Int32(file.positions.count / 3)
        guard count > 3,
              file.lines.count % 2 == 0, !file.lines.isEmpty,
              file.triangles.count % 3 == 0, !file.triangles.isEmpty,
              !file.points.isEmpty,
              (file.lines.max() ?? 0) < count,
              (file.triangles.max() ?? 0) < count,
              (file.points.max() ?? 0) < count
        else { return nil }

        var positions: [SCNVector3] = []
        positions.reserveCapacity(Int(count))
        for k in stride(from: 0, to: file.positions.count, by: 3) {
            positions.append(SCNVector3(file.positions[k], file.positions[k + 1], file.positions[k + 2]))
        }

        return Mesh(
            vertexSource: SCNGeometrySource(vertices: positions),
            normalSource: SCNGeometrySource(normals: approximateNormals(positions)),
            lineIndices: file.lines,
            triangleIndices: file.triangles,
            pointIndices: file.points
        )
    }

    /// Radial approximation is fine: the fill renders with constant lighting,
    /// so normals only need to be plausible, not exact.
    private static func approximateNormals(_ positions: [SCNVector3]) -> [SCNVector3] {
        positions.map { p in
            let v = SIMD3<Float>(Float(p.x), Float(p.y) * 0.25, Float(p.z))
            let n = simd_length(v) > 0 ? simd_normalize(v) : SIMD3<Float>(0, 1, 0)
            return SCNVector3(n.x, n.y, n.z)
        }
    }

    // MARK: Procedural fallback (only if a bundled mesh fails to load)

    private static func build(stacks: Int, slices: Int) -> Mesh {
        var positions: [SCNVector3] = []
        positions.reserveCapacity((stacks + 1) * slices)
        for i in 0...stacks {
            let theta = Float(i) / Float(stacks) * .pi
            for j in 0..<slices {
                let phi = Float(j) / Float(slices) * 2 * .pi
                let dir = SIMD3<Float>(sin(theta) * sin(phi), cos(theta), sin(theta) * cos(phi))
                let p = shape(dir)
                positions.append(SCNVector3(p.x, p.y, p.z))
            }
        }

        let rows = stacks + 1
        let cols = slices
        func index(_ i: Int, _ j: Int) -> Int32 { Int32(i * cols + (j % cols)) }

        var lines: [Int32] = []
        var triangles: [Int32] = []
        for i in 0..<(rows - 1) {
            for j in 0..<cols {
                let a = index(i, j), b = index(i, j + 1)
                let c = index(i + 1, j), d = index(i + 1, j + 1)
                lines.append(contentsOf: [a, c])
                if i > 0 { lines.append(contentsOf: [a, b]) }
                triangles.append(contentsOf: [a, c, b, b, c, d])
            }
        }

        return Mesh(
            vertexSource: SCNGeometrySource(vertices: positions),
            normalSource: SCNGeometrySource(normals: approximateNormals(positions)),
            lineIndices: lines,
            triangleIndices: triangles,
            pointIndices: Array(Int32(cols)..<Int32((rows - 1) * cols))
        )
    }

    /// Rough head deformation for the fallback path.
    private static func shape(_ dir: SIMD3<Float>) -> SIMD3<Float> {
        var p = dir * SIMD3<Float>(0.74, 1.0, 0.88)
        p.y *= 1.14
        let t = min(max((0.30 - dir.y) / 1.30, 0), 1)
        var w = 1 - 0.34 * t * t * t * 2.2
        w = max(w, 0.60)
        w += 0.05 * gauss((dir.y + 0.92) / 0.22)
        p.x *= w
        p.z *= w
        let front = max(0, dir.z)
        p.z *= 0.93 + 0.17 * smoothstep(0.15, -0.25, dir.z)
        p.z += 0.12 * gauss(dir.x / 0.20) * gauss((dir.y + 0.10) / 0.20) * front
        return p
    }

    private static func gauss(_ x: Float) -> Float { exp(-x * x) }

    private static func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
