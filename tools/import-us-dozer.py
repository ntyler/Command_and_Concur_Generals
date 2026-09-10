"""Convert the original AVCONSTDOZ_A rest pose to a self-contained Godot GLB.

Usage: python tools/import-us-dozer.py <folder-containing-W3D.big-and-Textures.big>
Requires numpy and Pillow. This is a bounded importer for this model, not a
general W3D converter. The original game installation is read only.
"""

import argparse
import hashlib
import io
import json
from pathlib import Path
import struct

import numpy as np
from PIL import Image


def archive_file(path, wanted):
    with path.open("rb") as stream:
        header = stream.read(16)
        assert header[:4] in (b"BIGF", b"BIG4"), "Unsupported BIG archive"
        for _ in range(struct.unpack_from(">I", header, 8)[0]):
            offset, size = struct.unpack(">II", stream.read(8))
            name = bytearray()
            while (byte := stream.read(1)) != b"\0":
                if not byte:
                    raise ValueError("Truncated BIG index")
                name.extend(byte)
            if name.decode("ascii").lower() == wanted.lower():
                stream.seek(offset)
                result = stream.read(size)
                assert len(result) == size, "Truncated BIG entry"
                return result
    raise ValueError(f"Missing {wanted} in {path.name}")


def chunks(data):
    offset = 0
    while offset < len(data):
        kind, flags = struct.unpack_from("<II", data, offset)
        size = flags & 0x7FFFFFFF
        offset += 8
        assert offset + size <= len(data), "Truncated W3D chunk"
        yield kind, data[offset:offset + size]
        offset += size


def cstring(data):
    return data.split(b"\0", 1)[0].decode("ascii")


def pivot_matrix(record):
    name, parent, tx, ty, tz, _, _, _, x, y, z, w = struct.unpack("<16sI3f3f4f", record)
    matrix = np.eye(4)
    matrix[:3, :3] = [
        [1 - 2 * (y*y + z*z), 2 * (x*y - z*w), 2 * (x*z + y*w)],
        [2 * (x*y + z*w), 1 - 2 * (x*x + z*z), 2 * (y*z - x*w)],
        [2 * (x*z - y*w), 2 * (y*z + x*w), 1 - 2 * (x*x + y*y)],
    ]
    matrix[:3, 3] = [tx, ty, tz]
    return cstring(name), parent, matrix


def geometry(data):
    top = list(chunks(data))
    hierarchy = dict(chunks(next(body for kind, body in top if kind == 0x100)))
    pivots = hierarchy[0x102]
    transforms = []
    for offset in range(0, len(pivots), 60):
        _, parent, matrix = pivot_matrix(pivots[offset:offset + 60])
        if parent != 0xFFFFFFFF:
            matrix = transforms[parent] @ matrix
        transforms.append(matrix)
    hlod = dict(chunks(next(body for kind, body in top if kind == 0x700)))
    bindings = {}
    for kind, body in chunks(hlod[0x702]):
        if kind == 0x704:
            bindings[cstring(body[4:]).split(".")[-1]] = struct.unpack_from("<I", body)[0]

    # Right-handed Z-up/X-forward to Y-up/-Z-forward; preserve face winding.
    axes = np.array([[0, -1, 0], [0, 0, 1], [-1, 0, 0]])
    meshes = []
    for kind, body in top:
        if kind != 0:
            continue
        parts = dict(chunks(body))
        name = cstring(parts[0x1F][8:24])
        if name == "HEADLIGHT01":
            continue  # Additive beam effect, not opaque daytime vehicle geometry.
        vertices = np.frombuffer(parts[2], dtype="<f4").reshape(-1, 3).astype(float)
        normals = np.frombuffer(parts[3], dtype="<f4").reshape(-1, 3).astype(float)
        triangles = np.frombuffer(parts[0x20], dtype="<u4").reshape(-1, 8)[:, :3]
        assert triangles.max() < len(vertices)
        assert struct.unpack("<4I", parts[0x28]) == (1, 1, 1, 1), "Unexpected material layout"
        texture = dict(chunks(dict(chunks(parts[0x30]))[0x31]))[0x32]
        texture_name = cstring(texture).lower()
        assert texture_name in ("avconstdoz.tga", "housecolor2.tga")
        stage = dict(chunks(dict(chunks(parts[0x38]))[0x48]))
        uv = np.frombuffer(stage[0x4A], dtype="<f4").reshape(-1, 2).copy()
        assert len(uv) == len(vertices)
        uv[:, 1] = 1.0 - uv[:, 1]  # W3D V origin to glTF image coordinates.
        transform = transforms[bindings[name]]
        vertices = (vertices @ transform[:3, :3].T + transform[:3, 3]) @ axes.T
        normals = normals @ transform[:3, :3].T @ axes.T
        normals /= np.linalg.norm(normals, axis=1)[:, None]
        meshes.append(dict(name=name, vertices=vertices, normals=normals, uv=uv,
                           triangles=triangles, material=int(texture_name == "housecolor2.tga")))
    assert len(meshes) == 10, "Unexpected vehicle parts"
    points = np.concatenate([mesh["vertices"] for mesh in meshes])
    low, high = points.min(axis=0), points.max(axis=0)
    center = (low + high) / 2
    center[1] = low[1]
    scale = 1.85 / (high[2] - low[2])
    for mesh in meshes:
        mesh["vertices"] = (mesh["vertices"] - center) * scale
    return meshes


def glb(meshes, textures):
    binary = bytearray()
    doc = dict(asset=dict(version="2.0", generator="Fieldwork US dozer importer"),
               scene=0, scenes=[dict(nodes=list(range(len(meshes))))], nodes=[],
               meshes=[], accessors=[], bufferViews=[], buffers=[], images=[],
               samplers=[dict(magFilter=9729, minFilter=9987, wrapS=10497, wrapT=10497)],
               textures=[], materials=[])

    def view(data):
        binary.extend(b"\0" * (-len(binary) % 4))
        index = len(doc["bufferViews"])
        doc["bufferViews"].append(dict(buffer=0, byteOffset=len(binary), byteLength=len(data)))
        binary.extend(data)
        return index

    def accessor(array, dtype, component, shape, bounds=False):
        index = len(doc["accessors"])
        array = np.asarray(array, dtype=dtype)
        info = dict(bufferView=view(array.tobytes()), componentType=component,
                    count=len(array), type=shape)
        if bounds:
            info.update(min=array.min(axis=0).tolist(), max=array.max(axis=0).tolist())
        doc["accessors"].append(info)
        return index

    for index, texture in enumerate(textures):
        output = io.BytesIO()
        Image.open(io.BytesIO(texture)).convert("RGBA").save(output, format="PNG")
        doc["images"].append(dict(bufferView=view(output.getvalue()), mimeType="image/png"))
        doc["textures"].append(dict(source=index, sampler=0))
        # Team color defaults to Alpha in the editor; each unit gets its own runtime material.
        color = [1, 1, 1, 1] if index == 0 else [0.05448, 0.55834, 0.60383, 1]
        doc["materials"].append(dict(name="Body" if index == 0 else "HouseColor",
            pbrMetallicRoughness=dict(baseColorTexture=dict(index=index), baseColorFactor=color,
                                     metallicFactor=0, roughnessFactor=1)))
    for mesh in meshes:
        attributes = dict(POSITION=accessor(mesh["vertices"], "<f4", 5126, "VEC3", True),
                          NORMAL=accessor(mesh["normals"], "<f4", 5126, "VEC3"),
                          TEXCOORD_0=accessor(mesh["uv"], "<f4", 5126, "VEC2"))
        indices = accessor(mesh["triangles"].flatten(), "<u2", 5123, "SCALAR")
        index = len(doc["meshes"])
        doc["meshes"].append(dict(name=mesh["name"], primitives=[
            dict(attributes=attributes, indices=indices, material=mesh["material"])]))
        doc["nodes"].append(dict(name=mesh["name"], mesh=index))
    doc["buffers"].append(dict(byteLength=len(binary)))
    payload = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    payload += b" " * (-len(payload) % 4)
    binary.extend(b"\0" * (-len(binary) % 4))
    return (struct.pack("<4sII", b"glTF", 2, 28 + len(payload) + len(binary))
            + struct.pack("<I4s", len(payload), b"JSON") + payload
            + struct.pack("<I4s", len(binary), b"BIN\0") + binary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("game_directory", type=Path)
    args = parser.parse_args()
    inputs = [("W3D.big", r"Art\W3D\AVCONSTDOZ_A.W3D"),
              ("Textures.big", r"Art\Textures\avconstdoz.dds"),
              ("Textures.big", r"Art\Textures\housecolor2.dds")]
    sources = [archive_file(args.game_directory / archive, name) for archive, name in inputs]
    meshes = geometry(sources[0])
    result = glb(meshes, sources[1:])
    out = Path(__file__).resolve().parents[1] / "assets/units/us_dozer"
    out.mkdir(parents=True, exist_ok=True)
    (out / "us_dozer.glb").write_bytes(result)
    provenance = dict(model="AVCONSTDOZ_A", pose="static hierarchy rest pose",
                      length=1.85, meshes=len(meshes),
                      vertices=sum(len(mesh["vertices"]) for mesh in meshes),
                      triangles=sum(len(mesh["triangles"]) for mesh in meshes),
                      omitted=["HEADLIGHT01 additive beam", "animation", "particles", "damaged variants"],
                      sources=[dict(archive=archive, entry=name, sha256=hashlib.sha256(data).hexdigest())
                               for (archive, name), data in zip(inputs, sources)],
                      output_sha256=hashlib.sha256(result).hexdigest())
    (out / "source.json").write_text(json.dumps(provenance, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(provenance, indent=2))


if __name__ == "__main__":
    main()
