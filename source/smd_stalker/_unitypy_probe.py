"""Probe UnityPy on the Stalker .asset YAML files."""
import UnityPy

asset_paths = [
    r"C:\Steam\steamapps\common\GarrysMod\ultragmod\assets\temp\assetripper_unity_project\ExportedProject\Assets\Legs_Low.asset",
    r"C:\Steam\steamapps\common\GarrysMod\ultragmod\assets\temp\assetripper_unity_project\ExportedProject\Assets\SandCan_Low.asset",
    r"C:\Steam\steamapps\common\GarrysMod\ultragmod\assets\temp\assetripper_unity_project\ExportedProject\Assets\SandCan_Glass_Low.asset",
    r"C:\Steam\steamapps\common\GarrysMod\ultragmod\assets\temp\assetripper_unity_project\ExportedProject\Assets\Sand.asset",
]

for path in asset_paths:
    print(f"\n=== {path.split(chr(92))[-1]} ===")
    try:
        env = UnityPy.load(path)
        print(f"  cab: {[c.name for c in env.cabs]}")
        for obj in env.objects:
            print(f"  Object type={obj.type.name} path_id={obj.path_id}")
            if obj.type.name == 'Mesh':
                data = obj.read()
                print(f"    name={data.m_Name}")
                print(f"    verts={len(data.m_VertexData.m_Data) if hasattr(data, 'm_VertexData') else 'n/a'}")
                # Try get vertex count via VertexCount or similar
                if hasattr(data, 'm_VertexData'):
                    vd = data.m_VertexData
                    print(f"    VertexData.m_VertexCount={vd.m_VertexCount}")
                    print(f"    VertexData channels: {len(vd.m_Channels)}")
                    for i, ch in enumerate(vd.m_Channels):
                        print(f"      ch{i}: stream={ch.stream} offset={ch.offset} format={ch.format} dim={ch.dimension}")
                if hasattr(data, 'm_IndexBuffer'):
                    print(f"    IndexBuffer size: {len(data.m_IndexBuffer)} bytes")
                if hasattr(data, 'm_SubMeshes'):
                    for i, sm in enumerate(data.m_SubMeshes):
                        print(f"    sub{i}: vertexCount={sm.vertexCount} indexCount={sm.indexCount}")
    except Exception as e:
        import traceback
        print(f"  ERROR: {e}")
        traceback.print_exc()
