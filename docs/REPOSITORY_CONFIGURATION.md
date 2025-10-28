# Repository Configuration Guide

This document provides guidance for repository administrators on configuring the diracx-charts repository.

## Branch Protection Rules

To maintain code quality and enforce the "live at head" approach, configure the following branch protection rules for the `master` branch:

### Required Settings

1. **Navigate to Repository Settings**
   - Go to: `Settings` → `Branches` → `Branch protection rules`
   - Add a rule for the `master` branch

2. **Configure Protection Rules**

   #### Pull Request Requirements
   - ✅ **Require a pull request before merging**
     - Require approvals: `1` (or more, as desired)
     - Dismiss stale pull request approvals when new commits are pushed
     - Require review from Code Owners (if CODEOWNERS file is present)

   #### Status Check Requirements
   - ✅ **Require status checks to pass before merging**
     - ✅ **Require branches to be up to date before merging** (critical for "live at head")
     - Required status checks:
       - `pre-commit` (from `.github/workflows/main.yml`)
       - `run-demo` (from `.github/workflows/main.yml`)
       - `run-demo-mount-sources` (from `.github/workflows/main.yml`)
       - `check-version-bump` (from `.github/workflows/version-check.yml`)

   #### Commit History
   - ✅ **Require linear history**
     - This prevents merge commits and keeps the git history clean
     - Pull requests must be rebased or squashed before merging

   #### Other Recommended Settings
   - ✅ **Do not allow bypassing the above settings**
   - ✅ **Require conversation resolution before merging**
   - ⚠️ Consider: **Restrict who can push to matching branches** (optional, based on your team structure)

### Why These Settings?

#### Require branches to be up to date
This is essential for the "live at head" approach because:
- The repository receives automated updates from diracx and diracx-web
- The master branch is always tagged with the current version
- Ensures no conflicts or issues arise from stale branches being merged

#### Require linear history
Benefits include:
- Cleaner, more readable git history
- Easier to understand the sequence of changes
- Simplifies troubleshooting and git bisect operations
- Works well with automated versioning and tagging

#### Version bump check
Ensures that:
- Every change increments the chart version
- No conflicting versions are introduced
- Chart releases are properly tracked

## Automated Updates Configuration

The repository receives automated updates from dependent repositories. Ensure that:

1. **GitHub Actions has write permissions**
   - Go to: `Settings` → `Actions` → `General` → `Workflow permissions`
   - Set to: `Read and write permissions`
   - This allows the release workflow to create tags and releases

2. **Automated PRs are configured correctly**
   - Automated updates from diracx and diracx-web should:
     - Create pull requests (not push directly to master)
     - Include version bumps in their changes
     - Wait for CI checks to pass

## Monitoring

Regularly check:
- Pull requests are being properly reviewed
- Status checks are passing consistently
- Version bumps are being applied correctly
- The release workflow is creating tags/releases as expected

## Questions or Issues?

If you encounter problems with these settings or need clarification, please:
- Review the GitHub documentation on [branch protection rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- Open an issue in the repository for discussion
