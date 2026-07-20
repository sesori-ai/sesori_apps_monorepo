# Contributing

Thanks for your interest in Sesori. This repo contains the Bridge, the mobile client, and shared protocol code. The instructions below will get you building and testing locally.

## Prerequisites

- **asdf** — recommended for version management. The repo's [`.tool-versions`](../.tool-versions) pins the Flutter and Dart versions automatically.
- **Flutter** — used by the `client/` workspace.
- **Dart SDK** — used by the `bridge/` workspace. It ships with the pinned Flutter version, so no separate install is needed.
- **Make** — each workspace uses a Makefile for common tasks.

Install the pinned Flutter version with asdf, then make sure `dart` is available from the Flutter install.

## Clone the repo

```sh
git clone https://github.com/sesori-ai/sesori_apps_monorepo.git
cd sesori_apps_monorepo
```

## Bridge workspace

The Bridge is a pure Dart workspace under `bridge/`.

```sh
cd bridge
dart pub get
```

Common tasks:

```sh
make pub-get   # resolve dependencies
make codegen   # run build_runner (freezed, json_serializable, ...)
make analyze   # static analysis
make test      # run unit tests
```

## Client workspace

The client is a Flutter workspace under `client/`.

```sh
cd client
flutter pub get
```

Common tasks:

```sh
make pub-get              # resolve dependencies
make codegen              # run build_runner
make analyze              # static analysis
make test                 # run tests
make generate-assets      # regenerate icon-font Dart bindings
make generate-tokens      # sync Figma design tokens into module_prego
```

## Shared packages

`shared/sesori_shared` holds the crypto and protocol types shared by both workspaces. `shared/no_slop_linter` is a custom analyzer plugin pulled in as a dev dependency. If you change shared models, regenerate and test both workspaces.

## Root Makefile

The root `Makefile` manages cross-workspace versioning:

```sh
make bump-version TYPE=patch   # bump bridge + mobile versions in lockstep
make bump-version-check        # preview the bump without writing changes
```

## Code style and architecture

- Follow the existing directory structure and naming conventions.
- Prefer named constructor parameters with `required`.
- Use enums for closed scalar sets and sealed classes for variants with different data.
- Never use an empty string to represent missing data when `null` is more honest.
- Never hand-edit generated files. Change the source and run `make codegen`.
- The Bridge workspace follows a strict layered architecture: Foundation → API → Repository → Service → Consumer. See [bridge/ARCHITECTURE.md](../bridge/ARCHITECTURE.md) for details.
- Read the repo root [AGENTS.md](../AGENTS.md) and workspace-specific `AGENTS.md` files when your change touches that area.

## Running tests

Before submitting a PR, run the relevant tests and analysis for the workspaces you changed:

```sh
cd bridge && make analyze && make test
cd ../client && make analyze && make test
```

Bridge CI is stricter than `make analyze` and uses `dart analyze --fatal-infos`. Consider running that from each changed module if you touched Bridge code.

## Opening issues and pull requests

- Use GitHub Issues for bug reports, feature requests, and questions.
- For security issues, please email [hello@sesori.com](mailto:hello@sesori.com) first.
- Keep pull requests focused. If you are unsure about a large change, open an issue to discuss it first.

### Contributor License Agreement

This repository requires a Contributor License Agreement (CLA). Before your first pull request can be merged, please read [CLA.md](../CLA.md) and comment on the pull request with:

```text
I have read the CLA Document and I hereby sign the CLA
```

The CLA Assistant bot will then record your agreement. This is a one-time requirement.

By contributing, you agree that your contributions will be licensed under the same [Functional Source License, Version 1.1, Apache 2.0 Future License](../LICENSE) that covers this project.
