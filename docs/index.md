# Catalog format

Each app release contains an `<id>.app.tar.bz2` archive and an `index.json` fragment. The archive contains one complete `.app` directory. Release tags use `<id>/<version>`, with any leading `v` removed from the upstream version.

The client uses a fixed builds repository and reads the merged catalog from `releases/download/latest/index.json`. It constructs app download paths as `releases/download/<id>%2F<version>/<id>.app.tar.bz2`, encoding the slash inside the tag as `%2F`.

Extract with `tar -xjpf <archive>` to preserve file permissions and symlinks.

The main catalog uses this structure. Release fragments omit the app-level `description` field:

```json
{
  "schemaVersion": 1,
  "apps": [
    {
      "id": "example",
      "name": "Example",
      "description": {
        "en": "An example application.",
        "zh-Hans": "示例应用。"
      },
      "bundleID": "org.example.app",
      "repository": "https://github.com/owner/example",
      "license": "MIT",
      "versions": [
        {
          "version": "1.2.3",
          "minSimulatorOS": "17.0",
          "sha256": "<archive SHA-256>",
          "size": 123456,
          "revision": "<full upstream commit>",
          "recipeRevision": "<full simstore-builds commit>"
        }
      ]
    }
  ]
}
```

A fragment contains one app and one version. Merge apps by `id` and versions by `version`, preserving other apps and historical versions. Versions contain three numeric components without a `v` prefix; compare their components numerically. `recipeRevision` identifies the recipe commit used for the build.

`minSimulatorOS` is the highest requirement from the built app and its embedded binaries, unless the manifest declares a higher minimum. `sha256` describes the compressed archive and `size` is its size in bytes.

`repository` and `license` belong to the app; the newest published version supplies both values for the whole app. `license` is required and contains the upstream repository's primary SPDX identifier for display; validation only requires a nonempty string. Each version's `revision` identifies its upstream source commit. These fields use the same validation rules as the recipe manifest's `source` fields.

## Localized descriptions

Each published app must have an `apps/<id>/description.yaml` file containing a short, neutral description in each supported language:

```yaml
en: An example application.
zh-Hans: 示例应用。
```

Use language tags such as `en`, `zh-Hans`, or `pt-BR` as keys. English (`en`) is required as the fallback; each translation must be a nonempty, single-line string. The catalog stores all translations in the app-level `description` object so the client can select the user's language.

Collection reads descriptions from the current checkout after merging all release fragments. Descriptions are independent of app versions and are omitted from build fragments. Changes to `apps/<id>/description.yaml` are excluded from automatic build selection. After editing descriptions or translations, rerun the `Update catalog` workflow; rebuilding or republishing apps is unnecessary.

## Updating the catalog

Run the `Update catalog` workflow manually. It scans every page of published app Releases, validates their `index.json` fragments against the current format, and checks archive presence, upload status, size, and the GitHub SHA-256 digest when available. Drafts, prereleases, unrelated tags, and the `latest` Release are excluded. The merged catalog contains all published app versions, sorted newest first by numeric version; apps are sorted by ID. The newest version supplies the display name, repository, and license, while conflicting Bundle IDs or version records stop publication.

Every run uploads the merged `index.json` as a workflow artifact. Runs on `main` also create or update the mutable Release tagged `latest`. Runs on other refs only produce the artifact. Catalog updates are serialized. An updated asset is uploaded under a temporary name and verified before replacing `index.json`; the previous asset is retained until the replacement succeeds, with a rollback attempt if the rename fails. An unchanged catalog keeps its existing asset.

`python3 scripts/update_index.py generate` writes `build/catalog/index.json` without modifying GitHub. GitHub CLI uses the current repository or `GH_REPO` and its configured authentication. Publication is a separate command, `python3 scripts/update_index.py publish build/catalog/index.json`.
