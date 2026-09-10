"""Static W3D geometry conversion for the local Generals object library.

Reads the published W3D chunk layout; preserves original source files separately.
Supports rigid hierarchies, bind-pose skins, per-face materials, UVs and alpha.
Runtime animation, particle emitters and multipass shader effects are catalogued,
not simulated by this visual importer.
"""
from collections import defaultdict
import hashlib
import io
import json
from pathlib import Path
import struct

import numpy as np
from PIL import Image

AXES = np.array([[0, -1, 0], [0, 0, 1], [-1, 0, 0]], dtype=float)


def chunks(data):
    offset = 0
    while offset < len(data):
        kind, flags = struct.unpack_from('<II', data, offset)
        offset += 8
        size = flags & 0x7fffffff
        if offset + size > len(data):
            raise ValueError('Truncated W3D chunk')
        yield kind, data[offset:offset + size]
        offset += size


def string(data):
    return data.split(b'\0', 1)[0].decode('ascii', errors='replace')


def rotation(q):
    x, y, z, w = q
    return np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)],
                     [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)],
                     [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])


def hierarchy(body, pose=None):
    parts = dict(chunks(body))
    pivots = parts[0x102]
    channels = defaultdict(dict)
    if pose is not None:
        for kind, data in chunks(pose):
            if kind != 0x202:
                continue
            first, _, length, flags, pivot, _ = struct.unpack_from('<6H', data)
            if first == 0:
                channels[pivot][flags] = struct.unpack_from('<' + 'f'*length, data, 12)
    matrices, names = [], []
    for offset in range(0, len(pivots), 60):
        record = struct.unpack_from('<16sI3f3f4f', pivots, offset)
        matrix = np.eye(4)
        matrix[:3, :3] = rotation(record[8:12])
        matrix[:3, 3] = record[2:5]
        translation = np.zeros(3)
        animation_rotation = np.eye(3)
        for channel, values in channels[len(matrices)].items():
            if channel in (0, 1, 2):
                translation[channel] = values[0]
            elif channel == 6:
                animation_rotation = rotation(values)
        matrix[:3, 3] += matrix[:3, :3] @ translation
        matrix[:3, :3] = matrix[:3, :3] @ animation_rotation
        if record[1] != 0xffffffff:
            matrix = matrices[record[1]] @ matrix
        matrices.append(matrix)
        names.append(string(record[0]))
    return matrices, names


def rank(row):
    archive = row['archive'].lower()
    return (row['edition'] == 'zero_hour', 'patch' in archive, 'english' in archive,
            row['entry'].startswith('art/'), archive)


class Library:
    def __init__(self, root):
        self.root = Path(root)
        self.manifest = json.loads((self.root / 'data/manifest.json').read_text())
        self.models, self.textures = {}, {}
        for row in sorted(self.manifest['entries'], key=rank):
            name = Path(row['entry']).name.lower()
            if name.endswith('.w3d'):
                self.models[name[:-4]] = row
            elif name.endswith(('.dds', '.tga')):
                self.textures[name] = row
        self.texture_cache = {}

    def texture(self, name):
        name = Path(name.replace('\\', '/')).name.lower()
        stem = name.rsplit('.', 1)[0]
        row = self.textures.get(stem + '.dds') or self.textures.get(name)
        if row is None:
            raise ValueError('Missing texture: ' + name)
        key = row['sha256']
        if key not in self.texture_cache:
            image = Image.open(self.root / row['path']).convert('RGBA')
            output = io.BytesIO()
            image.save(output, format='PNG')
            self.texture_cache[key] = output.getvalue()
        return key, self.texture_cache[key]

    def model(self, name):
        row = self.models[name.lower()]
        return row, list(chunks((self.root / row['path']).read_bytes()))


def convert(library, name, *, keep_effects=False):
    row, top = library.model(name)
    warnings = set()
    bindings = {}
    matrices, bones = [np.eye(4)], ['ROOT']
    top_dict = dict(top)
    pose = None
    if name == 'airngr_skn':
        _, animation_top = library.model('airngr_sta')
        pose = dict(animation_top)[0x200]
        warnings.add('Static first frame of original AIRngr_STA standing animation')
    if 0x100 in top_dict:
        matrices, bones = hierarchy(top_dict[0x100], pose)
    if 0x700 in top_dict:
        hlod = list(chunks(top_dict[0x700]))
        header = dict(hlod)[0x701]
        skeleton = string(header[24:40]).lower()
        if 0x100 not in top_dict and skeleton:
            if skeleton not in library.models:
                raise ValueError('Missing skeleton: ' + skeleton)
            _, skeleton_top = library.model(skeleton)
            matrices, bones = hierarchy(dict(skeleton_top)[0x100], pose)
        lod = next((body for kind, body in hlod if kind == 0x702), None)
        if lod:
            for kind, body in chunks(lod):
                if kind == 0x704:
                    bindings[string(body[4:]).lower()] = struct.unpack_from('<I', body)[0]
    if 0x200 in top_dict or 0x280 in top_dict:
        warnings.add('Static rest pose; animation retained in source')
    primitives = []
    for kind, body in top:
        if kind != 0:
            continue
        pairs = list(chunks(body))
        parts = dict(pairs)
        header = parts[0x1f]
        attributes = struct.unpack_from('<I', header, 4)[0]
        mesh_name, container = string(header[8:24]), string(header[24:40])
        qualified = (container + '.' + mesh_name).lower()
        if bindings and qualified not in bindings:
            continue
        if attributes & 0x1000:
            warnings.add('Hidden mesh retained in source')
            continue
        vertices = np.frombuffer(parts[2], dtype='<f4').reshape(-1, 3).astype(float)
        if not len(vertices) or 0x20 not in parts:
            continue
        normals = np.frombuffer(parts[3], dtype='<f4').reshape(-1, 3).astype(float)
        triangles = np.frombuffer(parts[0x20], dtype='<u4').reshape(-1, 8)[:, :3]
        if not len(triangles):
            continue
        if triangles.max() >= len(vertices):
            raise ValueError('Triangle vertex index out of range')
        bone = bindings.get(qualified, 0)
        if attributes & 0x20000 and 0x0e in parts:
            influences = np.frombuffer(parts[0x0e], dtype='<u2').reshape(-1, 4)[:, 0]
            for index in np.unique(influences):
                mask = influences == index
                matrix = matrices[index]
                vertices[mask] = vertices[mask] @ matrix[:3, :3].T + matrix[:3, 3]
                normals[mask] = normals[mask] @ matrix[:3, :3].T
            if pose is None:
                warnings.add('Skinned model shown in bind pose')
        else:
            matrix = matrices[bone]
            vertices = vertices @ matrix[:3, :3].T + matrix[:3, 3]
            normals = normals @ matrix[:3, :3].T
        vertices = vertices @ AXES.T
        normals = normals @ AXES.T
        normals /= np.maximum(np.linalg.norm(normals, axis=1)[:, None], 1e-12)
        texture_names = []
        if 0x30 in parts:
            for _, texture_body in chunks(parts[0x30]):
                texture_names.append(string(dict(chunks(texture_body))[0x32]))
        vertex_materials = []
        if 0x2a in parts:
            for _, material_body in chunks(parts[0x2a]):
                material_parts = dict(chunks(material_body))
                info = material_parts[0x2d]
                vertex_materials.append(dict(diffuse=[v / 255 for v in info[8:11]],
                    mapping=(struct.unpack_from('<I', info)[0] >> 16) & 0xff,
                    opacity=struct.unpack_from('<f', info, 24)[0],
                    emission=[v / 255 for v in info[16:19]]))
        shaders = [parts[0x29][i:i+16] for i in range(0, len(parts.get(0x29, b'')), 16)]
        passes = [data for part_kind, data in pairs if part_kind == 0x38]
        if not passes:
            raise ValueError('No supported material pass: ' + mesh_name)
        if len(passes) > 1:
            warnings.add('Additional material passes retained in source')
        selected_pass = passes[0]
        if len(passes) > 1:
            # Reflective models draw an environment layer followed by their skin.
            # Keep the UV-mapped skin as the static preview's opaque base color.
            for candidate in passes:
                candidate_parts = dict(chunks(candidate))
                candidate_ids = np.frombuffer(candidate_parts.get(0x39, bytes(4)), dtype='<u4')
                if all(vertex_materials[index]['mapping'] == 0 for index in candidate_ids):
                    selected_pass = candidate
                    break
        mat_pass = list(chunks(selected_pass))
        pass_parts = dict(mat_pass)
        stages = [dict(chunks(data)) for part_kind, data in mat_pass if part_kind == 0x48]
        if len(stages) > 1:
            warnings.add('Additional texture stages retained in source')
        stage = stages[0] if stages else {}
        texids = np.frombuffer(stage.get(0x49, struct.pack('<i', -1)), dtype='<i4')
        shaderids = np.frombuffer(pass_parts.get(0x3a, bytes(4)), dtype='<u4')
        matids = np.frombuffer(pass_parts.get(0x39, bytes(4)), dtype='<u4')
        uv = np.frombuffer(stage.get(0x4a, bytes(len(vertices)*8)), dtype='<f4').reshape(-1, 2).copy()
        if not np.isfinite(uv).all():
            warnings.add('Non-finite source UV coordinates replaced with zero in preview')
            uv[~np.isfinite(uv)] = 0
        uv[:, 1] = 1 - uv[:, 1]
        faceuv = None
        if 0x4b in stage:
            faceuv = np.frombuffer(stage[0x4b], dtype='<u4').reshape(-1, 3)
        colors = np.ones((len(vertices), 4), dtype=float)
        if 0x3b in pass_parts and len(pass_parts[0x3b]) == len(vertices)*4:
            colors = np.frombuffer(pass_parts[0x3b], dtype='u1').reshape(-1, 4) / 255.0
        groups = defaultdict(list)
        for i, triangle in enumerate(triangles):
            material_id = int(matids[0] if len(matids) == 1 else matids[triangle[0]])
            shader_id = int(shaderids[0] if len(shaderids) == 1 else shaderids[i])
            texture_id = int(texids[0] if len(texids) == 1 else texids[i])
            groups[material_id, shader_id, texture_id].append(i)
        for (material_id, shader_id, texture_id), faces in groups.items():
            shader = shaders[shader_id] if shaders else bytes(16)
            if not keep_effects and mesh_name != 'AVCOMANCHE_PROP' and len(passes) == 1 and shader[1] == 0 and shader[3] != 0:
                warnings.add('Blended non-solid effect retained in source')
                continue
            material = vertex_materials[material_id].copy() if vertex_materials else dict(diffuse=[1,1,1], opacity=1, emission=[0,0,0])
            material.update(two_sided=bool(attributes & 0x2000), alpha_test=bool(shader[12]),
                            blend=shader[3] != 0 and len(passes) == 1, name=mesh_name, texture=None)
            if mesh_name.upper().startswith('HOUSECOLOR'):
                material['name'] = 'HouseColor_' + mesh_name
                material['diffuse'] = [0.05448, 0.55834, 0.60383]
            if 0 <= texture_id < len(texture_names):
                texture_name = texture_names[texture_id]
                try:
                    material['texture'] = library.texture(texture_name)
                except (ValueError, OSError) as error:
                    warnings.add(str(error))
                if 'housecolor' in texture_name.lower() or mesh_name.upper().startswith('HOUSECOLOR'):
                    material['name'] = 'HouseColor_' + mesh_name
                    material['diffuse'] = [0.05448, 0.55834, 0.60383]
            # Corner expansion also supports per-face UV indexing without losing seams.
            indices = triangles[faces].flatten()
            uv_indices = faceuv[faces].flatten() if faceuv is not None else indices
            primitives.append(dict(name=mesh_name, bone=bones[bone],
                pivot=(AXES @ matrices[bone][:3, 3]).tolist(),
                vertices=vertices[indices], normals=normals[indices], uv=uv[uv_indices],
                colors=colors[indices], material=material))
    if not primitives:
        raise ValueError('No visible geometry in this source file')
    return primitives, sorted(warnings), row


def write_glb(primitives, path):
    binary = bytearray()
    doc = dict(asset=dict(version='2.0', generator='Fieldwork Generals library importer'),
               scene=0, scenes=[dict(nodes=list(range(len(primitives))))], nodes=[],
               meshes=[], accessors=[], bufferViews=[], buffers=[], materials=[],
               images=[], textures=[], samplers=[dict(magFilter=9729, minFilter=9987, wrapS=10497, wrapT=10497)])
    image_indices = {}
    def view(data):
        binary.extend(b'\0' * (-len(binary) % 4))
        result = len(doc['bufferViews'])
        doc['bufferViews'].append(dict(buffer=0, byteOffset=len(binary), byteLength=len(data)))
        binary.extend(data)
        return result
    def accessor(array, shape, bounds=False):
        array = np.asarray(array, dtype='<f4')
        result = len(doc['accessors'])
        entry = dict(bufferView=view(array.tobytes()), componentType=5126, count=len(array), type=shape)
        if bounds:
            entry.update(min=array.min(axis=0).tolist(), max=array.max(axis=0).tolist())
        doc['accessors'].append(entry)
        return result
    for primitive in primitives:
        material = primitive['material']
        pbr = dict(baseColorFactor=material['diffuse']+[float(np.clip(material['opacity'], 0, 1))],
                   metallicFactor=0, roughnessFactor=1)
        texture = material['texture']
        if texture:
            key, png = texture
            if key not in image_indices:
                index = len(doc['images'])
                doc['images'].append(dict(bufferView=view(png), mimeType='image/png'))
                doc['textures'].append(dict(source=index, sampler=0))
                image_indices[key] = index
            pbr['baseColorTexture'] = dict(index=image_indices[key])
        mat = dict(name=material['name'], pbrMetallicRoughness=pbr,
                   doubleSided=material['two_sided'], emissiveFactor=material['emission'])
        if material['alpha_test']:
            mat.update(alphaMode='MASK', alphaCutoff=0.5)
        elif material['blend'] or material['opacity'] < 0.999:
            mat['alphaMode'] = 'BLEND'
        doc['materials'].append(mat)
        attributes = dict(POSITION=accessor(primitive['vertices'], 'VEC3', True),
                          NORMAL=accessor(primitive['normals'], 'VEC3'),
                          TEXCOORD_0=accessor(primitive['uv'], 'VEC2'),
                          COLOR_0=accessor(primitive['colors'], 'VEC4'))
        index = len(doc['meshes'])
        doc['meshes'].append(dict(name=primitive['name'], primitives=[dict(attributes=attributes, material=index)]))
        doc['nodes'].append(dict(name=primitive['name'], mesh=index,
                                extras=dict(w3d_bone=primitive['bone'], w3d_pivot=primitive['pivot'])))
    doc['buffers'].append(dict(byteLength=len(binary)))
    payload = json.dumps(doc, separators=(',', ':')).encode()
    payload += b' ' * (-len(payload) % 4)
    binary.extend(b'\0' * (-len(binary) % 4))
    result = (struct.pack('<4sII', b'glTF', 2, 28+len(payload)+len(binary))
              + struct.pack('<I4s', len(payload), b'JSON') + payload
              + struct.pack('<I4s', len(binary), b'BIN\0') + binary)
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(result)
    return hashlib.sha256(result).hexdigest()
