# Contributing Guidelines

## Pre-commit

We encourage the use of `pre-commit` locally, this reduces the amount of common
mistakes and engineers can just focus on reviewing the actual changes.

```bash
# Install pre-commit
brew install pre-commit
# This will enable pre-commit to run every time you git commit
pre-commit install
```

If you want to do an adhoc run of pre-commit

> [!WARNING]
> This will only run on files that are staged in git

```bash
pre-commit run --all-files
```

If you want to commit and skip checks

```bash
git commit --no-verify -m "some message"
```

## Development

```bash
make install  # Install dependencies
make test     # Run tests with coverage
make lint     # Run linting
make format   # Auto-format code
```

## Releasing

This package is consumed as a git dependency. To release a new version:

> [!IMPORTANT]
> Requires the [GitHub CLI (`gh`)](https://cli.github.com/) to be installed and authenticated.
>
> Install with `brew install gh`.

```bash
make release
```

This will:

1. Check `gh` CLI is installed
2. Check you're on `main` with no uncommitted changes
3. Check HEAD isn't already tagged
4. Show the current version and ask if it's a major, minor, or patch bump
5. Show commits since the last release
6. Ask for confirmation
7. Create a signed tag with the changelog as the tag message
8. Push the tag to origin
9. Create a GitHub Release with auto-generated notes

Consumers update by changing the `tag` in their `pyproject.toml`.

## Reporting Bugs/Feature Requests

We welcome you to use the GitHub issue tracker to report bugs or suggest
features.

When filing an issue, please check existing open, or recently closed, issues to
make sure somebody else hasn't already
reported the issue. Please try to include as much information as you can.

## Repo config

This repo uses the `gh` CLI extension [gh-repo-settings](https://github.com/ONSdigital/gh-repo-settings) to configure and maintain the repo's settings.

## Pull Request Process

When contributing to this repository, please first discuss the change you wish
to make via issue, slack, or any other method with the owners of this repository
before making a change.

We use Trunk-Based Development (TBD), please adhere to the following:

### Creating a feature

1. Clone the repo

    ```bash
    git clone git@github.com:ONSDigital/dis-infra-python-logging.git
    cd dis-infra-python-logging
    ```

1. Create a new branch off `main`

    ```bash
    git switch -c feature/<feature_name>
    ```

1. Make your changes and commit

1. Push your branch

    ```bash
    git push origin feature/<feature_name>
    ```

1. Create a PR against the `main` branch

### Rebasing

Rebasing is heavily encouraged using TBD as all history needs to be linear

```bash
git switch main
git pull --rebase origin main
git switch feature/<feature_name>
git rebase main
git push origin feature/<feature_name> --force-with-lease
```
