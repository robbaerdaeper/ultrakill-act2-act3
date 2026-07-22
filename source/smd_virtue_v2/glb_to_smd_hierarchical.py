"""
GLB → SMD converter preserving node hierarchy.
- Each non-mesh node becomes a bone.
- Each mesh node becomes a body section attached to its bone parent.
- Output: ref SMD with full skeleton + skinned vertices per node.

Usage:
  python glb_to_smd_hierarchical.py --glb Virtue.glb --out virtue_ref.smd \
                                    --flip-x --skip-nodes "Seasonal Hats,Halloween,..."
"""
import argparse, struct, math, sys
from pygltflib import GLTF2
import numpy as np

def mat4_mul(a, b):
    return np.matmul(a, b)

def trs_to_mat4(t, r, s):
    tx, ty, tz = t
    qx, qy, qz, qw = r
    sx, sy, sz = s
    rm = np.array([
        [1-2*(qy*qy+qz*qz), 2*(qx*qy-qz*qw),   2*(qx*qz+qy*qw),   0],
        [2*(qx*qy+qz*qw),   1-2*(qx*qx+qz*qz), 2*(qy*qz-qx*qw),   0],
        [2*(qx*qz-qy*qw),   2*(qy*qz+qx*qw),   1-2*(qx*qx+qy*qy), 0],
        [0,                 0,                  0,                  1],
    ])
    sm = np.diag([sx, sy, sz, 1.0])
    tm = np.eye(4); tm[0,3]=tx; tm[1,3]=ty; tm[2,3]=tz
    return mat4_mul(tm, mat4_mul(rm, sm))

def mat4_to_euler_xyz(m):
    t = (m[0,3], m[1,3], m[2,3])
    sy = math.sqrt(m[0,0]**2 + m[1,0]**2)
    if sy > 1e-6:
        rx = math.atan2(m[2,1], m[2,2])
        ry = math.atan2(-m[2,0], sy)
        rz = math.atan2(m[1,0], m[0,0])
    else:
        rx = math.atan2(-m[1,2], m[1,1])
        ry = math.atan2(-m[2,0], sy)
        rz = 0
    return t, (rx, ry, rz)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--glb', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--flip-x', action='store_true', help='Unity→Source X-flip')
    ap.add_argument('--skip-nodes', default='', help='comma-separated node name prefixes to skip')
    args = ap.parse_args()

    skip_prefixes = [s.strip() for s in args.skip_nodes.split(',') if s.strip()]
    g = GLTF2().load(args.glb)
    blob = g.binary_blob()

    parent_of = {}
    for i, n in enumerate(g.nodes):
        for c in (n.children or []):
            parent_of[c] = i

    def should_skip(idx):
        name = g.nodes[idx].name or f"node_{idx}"
        for p in skip_prefixes:
            if name.startswith(p) or name == p:
                return True
            cur = parent_of.get(idx)
            while cur is not None:
                if (g.nodes[cur].name or "").startswith(p):
                    return True
                cur = parent_of.get(cur)
        return False

    def local_matrix(node):
        t = node.translation or [0,0,0]
        r = node.rotation or [0,0,0,1]
        s = node.scale or [1,1,1]
        return trs_to_mat4(t, r, s)

    world = {}
    def compute_world(idx):
        if idx in world: return world[idx]
        m = local_matrix(g.nodes[idx])
        p = parent_of.get(idx)
        if p is not None:
            m = mat4_mul(compute_world(p), m)
        world[idx] = m
        return m
    for i in range(len(g.nodes)):
        compute_world(i)

    out = []
    out.append("version 1\n")
    out.append("nodes\n")
    bone_ids = {}
    next_bid = [0]

    def dfs_emit_bones(idx, parent_bid):
        if should_skip(idx):
            return
        name = (g.nodes[idx].name or f"node_{idx}").replace(" ", "_")
        bid = next_bid[0]; next_bid[0] += 1
        bone_ids[idx] = bid
        out.append(f'  {bid} "{name}" {parent_bid}\n')
        for c in (g.nodes[idx].children or []):
            dfs_emit_bones(c, bid)

    roots = []
    if g.scenes and g.scenes[0].nodes:
        roots = list(g.scenes[0].nodes)
    else:
        roots = [i for i in range(len(g.nodes)) if i not in parent_of]
    for r in roots:
        dfs_emit_bones(r, -1)
    out.append("end\n")

    out.append("skeleton\n")
    out.append("time 0\n")
    for nidx, bid in bone_ids.items():
        # SMD skeleton требует LOCAL-to-parent (не world!). studiomdl/Source
        # сами реконструируют world через parent chain. Если эмитить world —
        # bones double-transform'ятся → mesh ломается.
        m = local_matrix(g.nodes[nidx])
        t, rot = mat4_to_euler_xyz(m)
        x, y, z = t
        if args.flip_x: x = -x
        rx, ry, rz = rot
        out.append(f"  {bid} {x:.6f} {y:.6f} {z:.6f} {rx:.6f} {ry:.6f} {rz:.6f}\n")
    out.append("end\n")

    out.append("triangles\n")
    for nidx, bid in bone_ids.items():
        node = g.nodes[nidx]
        if node.mesh is None: continue
        mesh = g.meshes[node.mesh]
        wm = world[nidx]
        for prim in mesh.primitives:
            pos_acc = g.accessors[prim.attributes.POSITION]
            pos_bv = g.bufferViews[pos_acc.bufferView]
            pos_offset = (pos_bv.byteOffset or 0) + (pos_acc.byteOffset or 0)
            positions = []
            for i in range(pos_acc.count):
                x, y, z = struct.unpack_from('<3f', blob, pos_offset + i*12)
                v = np.array([x, y, z, 1.0])
                v = wm @ v
                wx, wy, wz = v[0], v[1], v[2]
                if args.flip_x: wx = -wx
                positions.append((wx, wy, wz))
            normals = [(0,0,1)]*pos_acc.count
            if prim.attributes.NORMAL is not None:
                n_acc = g.accessors[prim.attributes.NORMAL]
                n_bv = g.bufferViews[n_acc.bufferView]
                n_offset = (n_bv.byteOffset or 0) + (n_acc.byteOffset or 0)
                normals = []
                for i in range(n_acc.count):
                    nx, ny, nz = struct.unpack_from('<3f', blob, n_offset + i*12)
                    if args.flip_x: nx = -nx
                    normals.append((nx, ny, nz))
            uvs = [(0,0)]*pos_acc.count
            if prim.attributes.TEXCOORD_0 is not None:
                uv_acc = g.accessors[prim.attributes.TEXCOORD_0]
                uv_bv = g.bufferViews[uv_acc.bufferView]
                uv_offset = (uv_bv.byteOffset or 0) + (uv_acc.byteOffset or 0)
                uvs = []
                for i in range(uv_acc.count):
                    u, v = struct.unpack_from('<2f', blob, uv_offset + i*8)
                    uvs.append((u, 1.0-v))
            idx_acc = g.accessors[prim.indices]
            idx_bv = g.bufferViews[idx_acc.bufferView]
            idx_offset = (idx_bv.byteOffset or 0) + (idx_acc.byteOffset or 0)
            comp_type = idx_acc.componentType
            comp_size = {5121:1, 5123:2, 5125:4}[comp_type]
            fmt = {5121:'B', 5123:'H', 5125:'I'}[comp_type]
            indices = []
            for i in range(idx_acc.count):
                idx = struct.unpack_from('<'+fmt, blob, idx_offset + i*comp_size)[0]
                indices.append(idx)
            matname = (node.name or f"mat_{nidx}").replace(" ", "_")
            for ti in range(0, len(indices), 3):
                i0, i1, i2 = indices[ti], indices[ti+1], indices[ti+2]
                if args.flip_x:
                    i0, i1, i2 = i0, i2, i1
                out.append(f"{matname}\n")
                for vi in (i0, i1, i2):
                    px, py, pz = positions[vi]
                    nx, ny, nz = normals[vi]
                    u, v = uvs[vi]
                    out.append(f"  {bid} {px:.6f} {py:.6f} {pz:.6f} {nx:.6f} {ny:.6f} {nz:.6f} {u:.6f} {v:.6f} 1 {bid} 1.000\n")
    out.append("end\n")

    with open(args.out, 'w', encoding='utf-8') as f:
        f.writelines(out)
    print(f"Wrote {args.out} with {len(bone_ids)} bones")

if __name__ == '__main__':
    main()
