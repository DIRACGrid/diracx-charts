# Contributing to diracx-charts

Thank you for your interest in contributing to diracx-charts!

## Pull Request Requirements

When submitting a pull request, please ensure the following:

### Version Bumping

**All pull requests MUST bump the chart version(s) being modified.**

The repository uses automated CI checks to ensure that chart versions are incremented in every PR. This is required because:

- The repository follows a "live at head" approach
- Charts are automatically pushed to by diracx and diracx-web repositories
- The main branch is always tagged with the current version

#### Which versions need to be bumped?

- **The main chart** (`diracx/Chart.yaml`): The `version` field MUST be incremented following [Semantic Versioning](https://semver.org/)
  - MAJOR version for incompatible API changes
  - MINOR version for backwards-compatible functionality additions
  - PATCH version for backwards-compatible bug fixes

Note: Subcharts (like `diracx/charts/cert-manager-issuer/`) are not released separately and do not require version bumps unless you're also updating the main chart version.

#### Example

If the current version in `diracx/Chart.yaml` is `1.0.0` and you're making a backward-compatible bug fix:

```yaml
# Before
version: "1.0.0"

# After
version: "1.0.1"
```

### Pre-commit Checks

This repository uses pre-commit hooks. Make sure to install them:

```bash
pip install pre-commit
pre-commit install
```

### Testing

Before submitting your PR, ensure that:

1. Pre-commit checks pass: `pre-commit run --all-files`
2. The demo runs successfully: `./run_demo.sh --exit-when-done`
3. Helm linting passes: `helm lint diracx/ --set diracx.hostname=diracx.invalid`

## Repository Workflow

This repository follows a **"live at head"** approach with the following policies:

### Branch Strategy

- The `master` branch is the main development branch and should always be in a releasable state
- All changes must go through pull requests
- Pull requests should be kept up-to-date with the base branch before merging
- The repository maintains a linear history (no merge commits)

### Automated Updates

This repository receives automated updates from:
- [DIRACGrid/diracx](https://github.com/DIRACGrid/diracx)
- [DIRACGrid/diracx-web](https://github.com/DIRACGrid/diracx-web)

These automated updates will also need to bump the chart version appropriately.

### Recommended Branch Protection Settings

Repository administrators should configure the following branch protection rules for `master`:

- ✅ Require pull request reviews before merging
- ✅ Require status checks to pass before merging
  - ✅ Require branches to be up to date before merging
  - Required checks: `pre-commit`, `run-demo`, `run-demo-mount-sources`, `check-version-bump`
- ✅ Require linear history (no merge commits)
- ✅ Do not allow bypassing the above settings

## Questions?

If you have questions about contributing, please open an issue for discussion.
