# spec-kit-ext

A collection of community extensions for [spec-kit](https://github.com/github/spec-kit).

## Extensions

| Extension | Version | Description |
|---|---|---|
| [git-commit](extensions/git-commit/) | 0.1.0 | Generates conventional commit messages from staged git changes using an LLM |

## Installation

Install an extension into your spec-kit project:

```
speckit extensions install git-commit
```

Or register a local copy directly:

```
speckit extensions register ./extensions/git-commit
```

## Using the catalog

The catalog is published at:

```
https://raw.githubusercontent.com/fuongz/spec-kit-ext/main/extensions/catalog.json
```

Point your speckit setup at this URL to make extensions discoverable via `speckit extensions search`.

## Contributing

1. Fork this repo
2. Create your extension under `extensions/<your-extension-name>/`
3. Add an `extension.yml` manifest (see [extensions/git-commit/extension.yml](extensions/git-commit/extension.yml) for reference)
4. Add your extension entry to [extensions/catalog.json](extensions/catalog.json)
5. Open a pull request

## License

MIT
