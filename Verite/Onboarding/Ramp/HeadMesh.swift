import Foundation
import SceneKit
import simd

/// The onboarding scan-head mesh.
///
/// The head geometry is AUTHORED OFFLINE: lofted from anatomical horizontal
/// cross-sections (superellipse rings + a mid-sagittal face profile with
/// forehead, nose-root dip, nose, lips, chin) and visually validated from
/// four angles before being exported as bundled JSON grids
/// (`HeadGridLow.json` ~2.1k vertices, `HeadGridDense.json` ~8.4k). The app
/// only loads vertices and builds wire/point/fill geometry from them — no
/// runtime shape math to get wrong. A simple procedural head remains as a
/// fallback if a resource ever fails to load.
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
        /// All vertices except the tiny crown/chin cap rings (dozens of near-
        /// coincident points would stack additively into a hot glow dot).
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

    /// Hero mesh — wireframe + points.
    static let lowPoly: Mesh = loadGrid("HeadGridLow") ?? build(stacks: 40, slices: 44)

    /// Denser, calmer mesh the "Ceiling" beat crossfades to.
    static let dense: Mesh = loadGrid("HeadGridDense") ?? build(stacks: 80, slices: 88)

    // MARK: Bundled grid loading

    private struct GridFile: Decodable {
        let rows: Int
        let cols: Int
        let positions: [Float] // x,y,z flattened, row-major, columns wrap
    }

    private static func loadGrid(_ name: String) -> Mesh? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(GridFile.self, from: data),
              file.rows > 2, file.cols > 2,
              file.positions.count == file.rows * file.cols * 3
        else { return nil }

        var positions: [SCNVector3] = []
        positions.reserveCapacity(file.rows * file.cols)
        for k in stride(from: 0, to: file.positions.count, by: 3) {
            positions.append(SCNVector3(file.positions[k], file.positions[k + 1], file.positions[k + 2]))
        }
        return makeMesh(rows: file.rows, cols: file.cols, positions: positions)
    }

    // MARK: Shared geometry construction (grid topology, columns wrap)

    private static func makeMesh(rows: Int, cols: Int, positions: [SCNVector3]) -> Mesh {
        let normals = positions.map { p -> SCNVector3 in
            let v = SIMD3<Float>(Float(p.x), Float(p.y), Float(p.z))
            let n = simd_length(v) > 0 ? simd_normalize(v) : SIMD3<Float>(0, 1, 0)
            return SCNVector3(n.x, n.y, n.z)
        }

        func index(_ i: Int, _ j: Int) -> Int32 { Int32(i * cols + (j % cols)) }

        var lines: [Int32] = []
        var triangles: [Int32] = []
        for i in 0..<(rows - 1) {
            for j in 0..<cols {
                let a = index(i, j)
                let b = index(i, j + 1)
                let c = index(i + 1, j)
                let d = index(i + 1, j + 1)
                lines.append(contentsOf: [a, c])                 // meridian segment
                if i > 0 { lines.append(contentsOf: [a, b]) }    // ring (skip cap)
                triangles.append(contentsOf: [a, c, b, b, c, d])
            }
        }

        return Mesh(
            vertexSource: SCNGeometrySource(vertices: positions),
            normalSource: SCNGeometrySource(normals: normals),
            lineIndices: lines,
            triangleIndices: triangles,
            pointIndices: Array(Int32(cols)..<Int32((rows - 1) * cols))
        )
    }

    // MARK: Procedural fallback (only if a bundled grid fails to load)

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
        return makeMesh(rows: stacks + 1, cols: slices, positions: positions)
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
