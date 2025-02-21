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
- BREP
- BVH
- CSM
- COB
- DAE / Collada
- DXF
- ENFF
- FBX
- glTF 1.0 + GLB
- glTF 2.0 + GLB
- HMB
- IFC-STEP
- IGES 5.3
- IQM
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
- STEP AP203, 214, 242
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

### I get an error when I import a model on Windows.

(Re)install [Microsoft Visual C++ library](https://aka.ms/vs/17/release/vc_redist.x64.exe) then restart Windows.

### Model was imported but textures are missing.

Enable "Claim Missing Textures" option in "Extensions > Universal Importer" menu then import model again.

### On SketchUp 2017, imported model has bad texture coordinates and/or face count after polygon reduction is unexpected.

Do "File > Import", select "COLLADA files (*.dae)", click "Options", uncheck "Merge coplanar faces", click "OK", close dialog then re-import model with the plugin.

### When I reduce the polygon count of a mesh exported from CloudCompare, the plugin only imports one line.

Go back to CloudCompare, deselect "Preserve global shift on save", export again the mesh, then import it again with Universal Importer.

### My problem isn't resolved or isn't listed above.

Report a bug on official [Universal Importer forum thread](https://sketchucation.com/forums/viewtopic.php?f=323&t=71951) at SketchUcation or here at GitHub on [Issues](https://github.com/SamuelTallet/SketchUp-Universal-Importer-Plugin/issues) page.

## Thanks

This plugin relies on [Assimp](https://github.com/assimp/assimp) library, [Mayo](https://github.com/fougue/mayo) and [MeshLab](https://github.com/cnr-isti-vclab/meshlab) softwares. Thanks to their awesome contributors.

## License

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3.0 of the License, or (at your option) any later version.

If you release a modified version of this program TO THE PUBLIC, the GPL requires you to MAKE THE MODIFIED SOURCE CODE AVAILABLE to the program's users, UNDER THE GPL.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the [GNU General Public License](https://www.gnu.org/licenses/gpl.html) for more details.

## Copyright

© 2024 Samuel Tallet
