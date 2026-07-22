"""GLB -> SMD converter for ULTRAKILL Virtue (and similar static-mesh enemies).

Strategy:
  * Walk the node tree, computing a world matrix per node from
    (translation, rotation, scale) chained with the parent.
  * For each node that has a mesh, transform its vertices into world space and
    accumulate triangles per material.
  * Apply Unity->Source axis flip: Unity is left-handed, Y-up. Source is
    right-handed, Z-up. The QC `$upaxis Y` + `$origin 0 0 0 90` already rotates
    Y-up to Z-up; here we flip X to convert left-handed to right-handed (matches
    the unity_to_source_mesh_lessons memo).
  * Skip seasonal cosmetics (Halloween/Christmas/Easter) and SpawnEffect.
  * Drop any prim whose material is on the SKIP list.
"""
import argparse
import math
import struct
from pathlib import Path
from pygltflib import GLTF2
import numpy as np

# ---------------------------------------------------------------------------
# Material filter — keep only the parts that make up the canonical Virtue
# silhouette. Cosmetics + spawn-effect debris are excluded.

SKIP_MATERIALS = {
    "PumpkinMalicious",         # Halloween pumpkin head
    "AltarUnlitRed",            # Christmas hat red
    "Basic Color - White Unlit", # Christmas hat white / Easter egg white
    "Basic Color - Pink Unlit",  # Easter egg pink
    "Default-Material",         # SpawnEffect outer sphere
    "Charge 1",                 # SpawnEffect projectile
}

# Per-material override of the texture name written into the SMD's
# "material" line. Source's studiomdl uses these as VMT names under
# $cdmaterials.
MATERIAL_VMT = {
    "VirtueCrown":  "virtue_crown",
    "VirtueSphere": "virtue_sphere",
}


# ---------------------------------------------------------------------------
# glTF buffer access

def _read_accessor(g: GLTF2, idx: int):
    acc = g.accessors[idx]
    view = g.bufferViews[acc.bufferView]
    buf = g.binary_blob() or g.buffers[view.buffer].uri  # GLB stores raw bytes
    if not isinstance(buf, (bytes, bytearray, memoryview)):
        raise RuntimeError(f"Expected raw GLB binary blob, got {type(buf)}")
    offset = (view.byteOffset or 0) + (acc.byteOffset or 0)

    # Component sizes (glTF spec)
    comp_sizes = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
    comp_dtype = {5120: 'b', 5121: 'B', 5122: 'h', 5123: 'H', 5125: 'I', 5126: 'f'}
    type_counts = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4,
                   "MAT2": 4, "MAT3": 9, "MAT4": 16}
    n = type_counts[acc.type]
    elem_size = comp_sizes[acc.componentType] * n
    stride = view.byteStride or elem_size

    out = []
    for i in range(acc.count):
        start = offset + i * stride
        vals = struct.unpack_from('<' + comp_dtype[acc.componentType] * n,
                                  buf, start)
        out.append(vals if n > 1 else vals[0])
    return out


# ---------------------------------------------------------------------------
# Transforms (right-multiplication, row-major numpy)

def _node_local_matrix(node):
    if node.matrix:
        # glTF matrices are column-major; convert to row-major.
        return np.array(node.matrix, dtype=np.float64).reshape(4, 4).T

    t = node.translation or (0.0, 0.0, 0.0)
    r = node.rotation or (0.0, 0.0, 0.0, 1.0)  # quaternion xyzw
    s = node.scale or (1.0, 1.0, 1.0)

    # Scale
    S = np.diag([s[0], s[1], s[2], 1.0])
    # Rotation from quaternion
    qx, qy, qz, qw = r
    R = np.array([
        [1 - 2*(qy*qy + qz*qz),     2*(qx*qy - qz*qw),     2*(qx*qz + qy*qw), 0],
        [    2*(qx*qy + qz*qw), 1 - 2*(qx*qx + qz*qz),     2*(qy*qz - qx*qw), 0],
        [    2*(qx*qz - qy*qw),     2*(qy*qz + qx*qw), 1 - 2*(qx*qx + qy*qy), 0],
        [0, 0, 0, 1],
    ])
    # Translation
    T = np.identity(4)
    T[0, 3], T[1, 3], T[2, 3] = t
    return T @ R @ S


def _walk_world_matrices(g: GLTF2):
    """Return a dict {node_index: world_matrix (4x4 ndarray)}."""
    world = {}
    scene = g.scenes[g.scene or 0]

    def recurse(idx, parent):
        node = g.nodes[idx]
        local = _node_local_matrix(node)
        world[idx] = parent @ local
        for c in (node.children or []):
            recurse(c, world[idx])

    for root in scene.nodes:
        recurse(root, np.identity(4))
    return world


# ---------------------------------------------------------------------------
# SMD writer

SMD_HEADER = """version 1
nodes
0 "root" -1
end
skeleton
time 0
0 0 0 0 0 0 0
end
triangles
"""


def write_smd(triangles, out_path: Path):
    """triangles: list of (material_name, [(pos, normal, uv), x3])"""
    lines = [SMD_HEADER]
    for mat, verts in triangles:
        lines.append(mat + "\n")
        for (px, py, pz), (nx, ny, nz), (u, v) in verts:
            # Bone parent 0 (root), no weighting
            lines.append(f"0 {px:.6f} {py:.6f} {pz:.6f} "
                         f"{nx:.6f} {ny:.6f} {nz:.6f} "
                         f"{u:.6f} {v:.6f}\n")
    lines.append("end\n")
    out_path.write_text("".join(lines), encoding="utf-8")
    print(f"  wrote {out_path}  ({len(triangles)} triangles)")


# ---------------------------------------------------------------------------
# Main

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--glb", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--flip-x", action="store_true",
                    help="Flip X axis (Unity left-handed -> Source right-handed)")
    args = ap.parse_args()

    g = GLTF2().load(args.glb)
    world = _walk_world_matrices(g)

    triangles = []  # list of (material_name, [v1, v2, v3])

    for node_idx, node in enumerate(g.nodes):
        if node.mesh is None:
            continue
        M = world[node_idx]
        normal_M = np.linalg.inv(M[:3, :3]).T  # normal matrix
        mesh = g.meshes[node.mesh]

        for prim in mesh.primitives:
            if prim.material is None:
                continue
            mat_name = g.materials[prim.material].name
            if mat_name in SKIP_MATERIALS:
                continue
            vmt_name = MATERIAL_VMT.get(mat_name, mat_name.lower().replace(" ", "_"))

            positions = _read_accessor(g, prim.attributes.POSITION)
            normals = _read_accessor(g, prim.attributes.NORMAL)
            uvs = (_read_accessor(g, prim.attributes.TEXCOORD_0)
                   if prim.attributes.TEXCOORD_0 is not None else
                   [(0.0, 0.0)] * len(positions))

            if prim.indices is None:
                indices = list(range(len(positions)))
            else:
                indices = _read_accessor(g, prim.indices)

            # Transform vertices
            xformed_pos = []
            xformed_nrm = []
            for p in positions:
                v = np.array([p[0], p[1], p[2], 1.0])
                w = M @ v
                xformed_pos.append((w[0], w[1], w[2]))
            for n in normals:
                nv = normal_M @ np.array([n[0], n[1], n[2]])
                # Normalize
                ln = math.sqrt(nv[0]**2 + nv[1]**2 + nv[2]**2) or 1
                xformed_nrm.append((nv[0]/ln, nv[1]/ln, nv[2]/ln))

            # Apply Unity → Source flip if requested (negate X on pos+normal,
            # then reverse winding because the flip changes handedness)
            if args.flip_x:
                xformed_pos = [(-p[0], p[1], p[2]) for p in xformed_pos]
                xformed_nrm = [(-n[0], n[1], n[2]) for n in xformed_nrm]

            # Build triangles
            for i in range(0, len(indices), 3):
                tri_idx = indices[i:i+3]
                if args.flip_x:
                    tri_idx = list(reversed(tri_idx))
                verts = []
                for ix in tri_idx:
                    p = xformed_pos[ix]
                    n = xformed_nrm[ix]
                    u = uvs[ix]
                    # Source uses flipped V
                    verts.append((p, n, (u[0], 1.0 - u[1])))
                triangles.append((vmt_name, verts))

    print(f"Total triangles: {len(triangles)}")
    write_smd(triangles, Path(args.out))


if __name__ == "__main__":
    main()
