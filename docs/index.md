# Catalog format

Each app release contains an `<id>.app.tar.bz2` archive and an `index.json` fragment. The archive contains one complete `.app` directory. Release tags use `<id>/<version>`, with any leading `v` removed from the upstream version.

The client uses a fixed builds repository and reads the merged catalog from `releases/download/latest/index.json`. It constructs app download paths as `releases/download/<id>%2F<version>/<id>.app.tar.bz2`, encoding the slash inside the tag as `%2F`.

Extract with `tar -xjpf <archive>` to preserve file permissions and symlinks.

The main catalog and release fragments use the same structure:

```json
{
  "schemaVersion": 1,
  "apps": [
    {
      "id": "example",
      "name": "Example",
      "bundleID": "org.example.app",
      "versions": [
        {
          "version": "1.2.3",
          "minSimulatorOS": "17.0",
          "sha256": "<archive SHA-256>",
          "size": 123456,
          "source": {
            "repository": "https://github.com/owner/example",
            "revision": "<full upstream commit>"
          },
          "recipeRevision": "<full simstore-builds commit>"
        }
      ]
    }
  ]
}
```

A fragment contains one app and one version. Merge apps by `id` and versions by `version`, preserving other apps and historical versions. Versions contain three numeric components without a `v` prefix; compare their components numerically. `recipeRevision` identifies the recipe commit used for the build.

`minSimulatorOS` is the highest requirement from the built app and its embedded binaries, unless the manifest declares a higher minimum. `sha256` describes the compressed archive and `size` is its size in bytes.
