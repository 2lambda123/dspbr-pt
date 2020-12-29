## 

# Enterprise PBR Sample Renderer ([Demo](https://dassaultsystemes-technology.github.io/dspbr-pt/) |  [Validation Report](https://dassaultsystemes-technology.github.io/dspbr-pt/report/))


A WebGL path-tracer implementing the [Enterprise PBR Shading Model (DSPBR)](https://github.com/DassaultSystemes-Technology/EnterprisePBRShadingModel).

It supports the [glTF](https://www.khronos.org/gltf/) file format with several PBR Next extensions and wip extension proposals (marked as PR below).

* [KHR_materials_sheen](https://github.com/KhronosGroup/glTF/blob/master/extensions/2.0/Khronos/KHR_materials_sheen/README.md)
* [KHR_materials_clearcoat](https://github.com/KhronosGroup/glTF/blob/master/extensions/2.0/Khronos/KHR_materials_clearcoat/README.md)
* [KHR_materials_transmission](https://github.com/KhronosGroup/glTF/blob/master/extensions/2.0/Khronos/KHR_materials_transmission/README.md)
* [KHR_materials_translucency PR](https://github.com/KhronosGroup/glTF/pull/1825)
* [KHR_materials_specular PR](https://github.com/KhronosGroup/glTF/pull/1719)
* [KHR_materials_ior PR](https://github.com/KhronosGroup/glTF/pull/1718)
* [KHR_materials_volume PR](https://github.com/KhronosGroup/glTF/blob/c6be3dbc8c5b744f9ae13dbf0ba25b6eec05da0c/extensions/2.0/Khronos/KHR_materials_volume/README.md) (refraction only)

All of the mentioned extensions are implemented in terms of the Enterprise PBR specification. If you're interested in equations head over to the spec repo and check the [latest specification document](https://dassaultsystemes-technology.github.io/EnterprisePBRShadingModel/spec-2021x.md.html). If you're looking for code, [dspbr.glsl](./lib/shader/dspbr.glsl) should give you most of the relevant pieces.

> **NOTE**  
> The demo app uses the three.js [WebGLRenderer](https://threejs.org/docs/#api/en/renderers/WebGLRenderer) as fallback when path-tracing is disabled. Please check the three.js [documentation](https://threejs.org/docs/#api/en/materials/MeshPhysicalMaterial) for information on supported material extensions. 

## Quickstart

```bash
# Installs all dependencies necessary to run and develop the renderer and viewer app
npm install --production

# Alternatively, if you intent to run the validation or CLI rendering (see below) omit the --production flag
# This will additionally install electron (~200MB)
npm install 

# Launch the viewer in a browser with attached file watcher for auto refresh on file edits
npm run dev
```
```bash
# Builds a distributable package of the viewer to ./dist
npm run build
```

## Validation
The Enterprise PBR Specification repository provides a [*Validation Suite*](https://github.com/DassaultSystemes-Technology/EnterprisePBRShadingModel/tree/master/validation). The suite is a collection of lightweight test scenes accompanied by HDR reference renderings (generated by the Dassault Systèmes Stellar renderer). It further provides scripts to compare the output of a custom render engine to the provided grund-truth images. The suite generates an overview of the comparison result as HTML report.
The report for the current state of dspbr-pt can be found [here](https://dassaultsystemes-technology.github.io/dspbr-pt/report/)

In case you start to toy with the shaders you might want to run the validation regularly. It'll give you a good overview on which materials features were messed up by your changes ;)

```bash
# Clones the Enterprise PBR repo to the current working dir, runs the validation renderings and generates a report at ./validation/report/index.html
npm run validation

```

The validation scripts use the [CLI rendering](##CLI-Renderer) functionality as explained below. Validation render settings need to be adjusted directly in the [run_validation.py](./scripts/run_validation.py) script render call for now.

```python
# line 38
 render_call = ['npm', 'run', 'render', '--', '--', "../"+ file, '--res', '400', '400', '--samples', '512', '-b', '32', '--ibl-rotation', '180'];
```

## CLI Renderer

Command-line rendering is available via headless electron

```bash
# Builds the cli renderer to ./dist
npm run build-headless 

# Renders an image via command-line
npm run render -- -- <scene_path> --ibl <hdr_path> --res <width> <height> --samples <num_samples>

```
```bash
# Example
# Writes output image to ./output.png
npm run render -- -- "./assets/scenes/metal-roughness-0.05.gltf" --ibl "./assets/env/Footprint_Court_Env.hdr" -r 512 512 -s 32 
```


## Renderer API Usage

```javascript
import { PathtracingRenderer, PerspectiveCamera } from './lib/renderer';
import { Loader } from './lib/scene_loader';

let renderer = new PathtracingRenderer(canvas);
let camera = new PerspectiveCamera(45, canvas.width/canvas.height, 0.01, 1000);

const normalizeSceneDimension = true; 
const scenePromise = Loader.loadScene(scene_url, normalizeSceneDimension);
const iblPromise = Loader.loadIBL(ibl_url);

Promise.all([scenePromise, iblPromise]).then(([gltf, ibl]) => {
  renderer.setIBL(ibl);
  renderer.setScene(gltf).then(() => {
    renderer.render(camera, -1, (frame) => {
      controls.update();
      console.log("Finished frame number:", frame);
    })
  });
});
```
Please check [src/app.ts](src/app.ts) and [lib/renderer.ts](lib/renderer.ts) for more details.


## License
* Source code license info in [LICENSE](LICENSE)
* Provided assets are due to their own licenses. Detailed per-asset license information can be found in the [asset index file](assets/asset_index.ts)

