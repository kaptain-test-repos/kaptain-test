# Kaptain Test Repos

Branchout root repo for the `kaptain-test-repos` GitHub org.

End-to-end CI/CD validation of buildon-github-actions. One repo per workflow type, with variant features spread across repos via KaptainPM.yaml overrides. Every repo uses all available hooks with validation scripts that assert expected env vars are present and correct, failing the build if not.


## Testing Strategy

Each repo gets three test passes that exercise different code paths:

1. **Local build** - `BUILD_MODE=local`, `IS_RELEASE=false`. Validates scripts work correctly, and build logic without side effects (no push, no tag, no release).
2. **PR build** - `BUILD_MODE=build_server`, `IS_RELEASE=false`. Exercises majority of GH actions wiring, and quality checks (PR-only), PRERELEASE docker tag suffix, skips push/tag/release.
3. **Merge to main** - `BUILD_MODE=build_server`, `IS_RELEASE=true`. Exercises tag push, docker push, GitHub release creation, manifest publishing and wiring thereof.


## Usage

```bash
branchout init git@github.com:kaptain-test-repos/kaptain-test.git
cd ~/projects/kaptain-test
branchout pull
```

OR

```bash
branchout init https://github.com/kaptain-test-repos/kaptain-test.git
cd ~/projects/kaptain-test
branchout pull
```
