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

If your changes affect:

- **The main chart** (`diracx/Chart.yaml`): Increment the `version` field following [Semantic Versioning](https://semver.org/)
  - MAJOR version for incompatible API changes
  - MINOR version for backwards-compatible functionality additions
  - PATCH version for backwards-compatible bug fixes

- **The cert-manager-issuer subchart** (`diracx/charts/cert-manager-issuer/Chart.yaml`): Increment the `version` field if you modify this subchart

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

## Questions?

If you have questions about contributing, please open an issue for discussion.
