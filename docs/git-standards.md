# Git Standards

This document defines the mandatory Git practices for MyAaptha.

## Branching Model

- `main`: Production-ready code only.
- `develop`: Integration branch for upcoming releases.
- `feature/<scope>-<short-description>`: New work.
- `release/<version>`: Release stabilization.
- `hotfix/<version-or-issue>`: Urgent production fixes.

## Commit Standards

- Use small, focused commits with one logical change.
- Ensure each commit compiles and passes lint, tests, and formatting checks.
- Use present-tense, imperative commit messages.
- Include scope when helpful.

Recommended format:

`<type>(<scope>): <summary>`

Examples:

- `feat(auth): add token refresh endpoint`
- `fix(ui): prevent null render in dashboard cards`
- `docs(standards): add API pagination guideline`

## Pull Request Standards

- Branch must be up to date with `develop` before review.
- PR must include purpose, design notes, and validation evidence.
- Required checks must pass before merge.
- At least one reviewer approval is required.
- Squash or merge strategy must preserve a readable history.

## Merge Rules

- Never commit directly to `main`.
- Use pull requests for all branch merges.
- Resolve conflicts locally and retest before merge.
- Do not merge failing CI pipelines.

## Tagging and Releases

- Use semantic versioning tags: `vMAJOR.MINOR.PATCH`.
- Create tags only from release-approved commits.
- Include release notes for every tagged version.

## Protected Branch Expectations

The following protections should be configured in GitHub:

- Block force-push on `main` and `develop`.
- Require PR review before merge.
- Require status checks to pass.
- Restrict branch deletion for protected branches.

## Commit Hygiene Checklist

- Code compiles.
- Lint passes.
- Tests pass.
- Formatting passes.
- Documentation updated if behavior changed.