# US dozer visual

`us_dozer.glb` contains the original `AVCONSTDOZ_A` vehicle geometry and textures
used by the US dozer in Command & Conquer: Generals / Zero Hour, imported from
the user's local game installation. This is original game art; the separate
engine source release does not establish a license for these assets.

The model has 10 visible mesh parts, 566 vertices and 312 triangles. Original
positions, normals and UV mapping are retained through a coordinate conversion,
uniform scaling to 1.85 world units long, horizontal centering and grounding.
The UV V axis is flipped for glTF. The two DDS textures are embedded as PNGs.
`HOUSECOLOR` panels receive each
unit's team color without modifying shared materials.

This is a static rest pose. The additive headlight beam, digging animation,
wheel animation, particles and damaged variants are not imported. Movement,
collision, health, construction and economy rules are unchanged.

Rebuild with Python, numpy and Pillow:

```powershell
python tools/import-us-dozer.py 'C:\path\to\Command and Conquer Generals'
```

The input folder must contain `W3D.big` and `Textures.big`. `source.json` records
the exact archive entries, source hashes, output hash and conversion scope.
Open `scenes/bulldozer_model.tscn` in Godot to inspect the model in the 3D viewport.
The gameplay scene loads it through `_build_visual()`, preserving production's
requirement that an uninitialized unit scene contain only its controller.
