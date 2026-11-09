# MP3 encoder source and replacement

lamejs 1.2.1, by Alex Zhukov and LAME contributors. LGPL-3.0, unmodified.
Source: https://github.com/zhuker/lamejs ; https://lame.sourceforge.io
The full official npm source archive (including original copyright notices,
Java/JS source and build scripts) is lamejs-1.2.1-source.tgz beside this file.
The exact npm integrity and every distributed hash are in ASSETS.json.

The app loads the readable lame.all.js at runtime through JavaScriptCore;
this library is a separate file, not statically linked into the executable.
To use a compatible modified library, replace App/Resources/MP3/lame.all.js,
update this folder's ASSETS.json, and build/sign the app from the fully
available Apache-2.0 source. Retain the lamejs.Mp3Encoder API. The app imposes
no check against an upstream library signature or DRM; the inventory checks
packaging integrity against the version you choose. No reverse-engineering
restriction is imposed for debugging modifications to this LGPL component.
No modifications to the upstream encoder were made by this project.

GPL-3.0 and LGPL-3.0 texts are COPYING and COPYING.LESSER. Original older
LAME license/copyright files remain intact inside the source archive.
The npm wrapper's build-only use-strict dependency is not bundled or executed;
the self-contained lame.all.js does not require npm modules at runtime.
