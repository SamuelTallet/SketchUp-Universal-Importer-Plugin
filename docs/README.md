# Free universal importer plugin for SketchUp

Import 3D models in SketchUp. 50+ formats are supported. Reduce polygon count on the fly.

## Supported formats

- 3D
- 3DS
- 3MF
- AC
- AC3D
- ACC
- AMJ
- ASE
- ASK
- B3D
- BLEND
- BVH
- CMS
- COB
- DAE/Collada
- DXF
- ENFF
- FBX
- glTF 1.0 + GLB
- glTF 2.0 + GLB
- HMB
- IFC-STEP
- IRR / IRRMESH
- LWO
- LWS
- LXO
- M3D
- MD2
- MD3
- MD5
- MDC
- MDL
- MESH / MESH.XML
- MOT
- MS3D
- NDO
- NFF
- OBJ
- OFF
- OGEX
- PLY
- PMX
- PRJ
- Q3O
- Q3S
- RAW
- SCN
- SIB
- SMD
- STP
- STL
- TER
- UC
- VTA
- X
- X3D
- XGL
- ZGL

## Installation

1. Be sure to have SketchUp 2017 or newer.
2. Download latest Universal Importer plugin from the [SketchUcation PluginStore](https://sketchucation.com/plugin/2275-universal_importer).
3. Install plugin following this [guide](https://www.youtube.com/watch?v=tyM5f81eRno).

Now, you should have in SketchUp an "Universal Importer" submenu in "Extensions" menu and an "Universal Importer" toolbar.

## Troubleshooting

### I get a error when I import a model on Windows.

(Re)install [Microsoft Visual C++ library](https://aka.ms/vs/17/release/vc_redist.x64.exe) then restart Windows.

### Model was imported but textures are missing.

Enable "Claim Missing Textures" option in "Extensions > Universal Importer" menu then import model again.

## Thanks

This plugin relies on [Assimp library](https://github.com/assimp/assimp) and [MeshLab software](https://github.com/cnr-isti-vclab/meshlab). Thanks to Assimp's and MeshLab's contributors.

## Copyright

© 2022 Samuel Tallet
