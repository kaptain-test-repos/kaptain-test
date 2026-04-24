# Kaptain Test Repos

GitHub org: `kaptain-test-repos`

Purpose: end-to-end CI/CD validation of buildon-github-actions. One repo per workflow type, variant features spread across repos via KaptainPM.yaml overrides. Every repo uses all available hooks with validation scripts that assert expected env vars are present and correct, failing the build if not.

## Testing Strategy

Each repo gets three test passes that exercise different code paths:

1. **Local build** - `BUILD_MODE=local`, `IS_RELEASE=false`. Validates scripts work correctly, and build logic without side effects (no push, no tag, no release).
2. **PR build** - `BUILD_MODE=build_server`, `IS_RELEASE=false`. Exercises majority of GH actions wiring, and quality checks (PR-only), PRERELEASE docker tag suffix, skips push/tag/release.
3. **Merge to main** - `BUILD_MODE=build_server`, `IS_RELEASE=true`. Exercises tag push, docker push, GitHub release creation, manifest publishing and wiring thereof.

Hook validation scripts check the correct behaviour for each context (e.g., pre-version hooks assert version vars are NOT set, post-version hooks assert they ARE set and internally consistent, release-only hooks verify IS_RELEASE state matches expectations).

## Hook Availability by Workflow Type

Not all workflows support all 8 hooks. Each repo enables every hook its workflow supports:

| Workflow Type | Hooks Available | Count |
|---|---|---|
| basic-quality-checks | preBuild, postBuild | 2 |
| basic-quality-and-versioning | preBuild, preTaggingTests, postVersionsAndNaming, postBuild | 4 |
| docker-build-dockerfile, docker-build-retag | preBuild, preTaggingTests, postVersionsAndNaming, preDockerPrepare, postDockerTests, postBuild | 6 |
| kubernetes-app-docker-dockerfile, kubernetes-app-docker-retag | all 8 | 8 |
| kubernetes-app-manifests-only, kubernetes-bundle-resources, kubernetes-bundle-vendor-helm-rendered | preBuild, preTaggingTests, postVersionsAndNaming, prePackagePrepare, postPackageTests, postBuild | 6 |
| layer-and-layerset-build, spec-check-filter-release, aws-eks-cluster-management | preBuild, preTaggingTests, postVersionsAndNaming, preDockerPrepare, postDockerTests, postBuild | 6 |

## Repos

| # | Repo | Workflow | Variant Features | Justification |
|---|------|----------|------------------|---------------|
| 1 | `test-basic-quality-checks` | `basic-quality-checks` | All QC options enabled (conventional branches, conventional commits, block double hyphen, block slash, block duplicate commits). | Only workflow with no versioning. Tests quality checks and bit flag combinations in isolation. |
| 2 | `test-basic-quality-and-versioning` | `basic-quality-and-versioning` | Default git-auto versioning. Release branch (`release/1.x`) with independent version sequence. `always-strip-one-newline` trailing newline mode. | Simplest versioning workflow. Release branch tests version series isolation. |
| 3 | `test-docker-build-dockerfile` | `docker-build-dockerfile` | `mustache` token style, `UPPER_SNAKE` name style, `squash-all`, custom `dockerfile-sub-path`, multiple `dockerfile-substitution-files`, `dockerfile-no-cache: false`. User config tokens with nested paths. Multi-platform (`linux/amd64,linux/arm64`) using a single Dockerfile with platform-agnostic installs. | Core docker build. Stacks non-default options to exercise overrides. Multi-platform is a config toggle, not a separate source structure. |
| 4 | `test-docker-build-retag` | `docker-build-retag` | `file-pattern-match` versioning (version from Dockerfile ENV). | Only retag workflow. File-pattern versioning is a natural fit for tracking upstream. |
| 5 | `test-kubernetes-app-docker-dockerfile` | `kubernetes-app-docker-dockerfile` | All generators enabled (deployment + service + configmap + secret-template + PDB + serviceaccount), `erb` token style, `token-substitution-passes: 2` for chaining, GitHub release with substituted + verbatim + raw files, release notes from file. Additional tokens injected via `prePackagePrepare` hook. `project-name-prefixed-separate` image reference style. | The "kitchen sink" pipeline. Only workflow with all 8 hooks. Exercises generator interactions (service/PDB selector matching, configmap/secret volume mount references, env var injection from configmap keys). |
| 6 | `test-kubernetes-app-docker-retag` | `kubernetes-app-docker-retag` | `statefulset` workload with PVC template, `separate` image reference style, `helm` token style. Headless service auto-generation. | Only kube+retag workflow. StatefulSet exercises PVC, headless service naming, and pod management policy. |
| 7 | `test-kubernetes-app-manifests-only` | `kubernetes-app-manifests-only` | `allow-builtin-token-override: true`, `github-actions` token style, `cronjob` workload type with schedule/suspend tokens. Token override flow (defers docker image tokens to downstream). | Only manifests-without-docker workflow. Exercises token override, cronjob schedule/suspend token generation, and the template project pattern. |
| 8 | `test-kubernetes-bundle-resources` | `kubernetes-bundle-resources` | `compound-file-pattern-match` versioning (two source files), `lower-kebab` name style, `preserve-all` trailing newline mode, custom `config-sub-path`. | Only bundle-resources workflow. Compound versioning needs two source files. |
| 9 | `test-kubernetes-bundle-vendor-helm-rendered` | `kubernetes-bundle-vendor-helm-rendered` | Helm fetch from OCI registry, post-processing with sed patterns + yq transforms + file moves, image retagging (generates additional tokens). `stringtemplate` token style. | Only vendor-helm workflow. Exercises the full 9-stage post-processing pipeline and additional token generation from image retags. |
| 10 | `test-layer-and-layerset-build` | `layer-and-layerset-build` | Layer type (`layer-` prefix). Payload files, layer-payload validation, schema validation. | Layer type requires `layer-` project prefix and `src/layer/` source with payload files. Fundamentally different source structure from layerset. |
| 11 | `test-layerset-and-layerset-build` | `layer-and-layerset-build` | Layerset type (`layerset-` prefix). Range resolution, dependency validation (hard mode), metadata injection. References `test-layer-and-layerset-build` (same org) AND a real layer from `kube-kaptain` org (cross-org). | Layerset requires `layerset-` prefix, `src/layerset/` source, no payload files, range resolution, and dependency pulling. Cannot share a repo with layer due to project name prefix requirement. Cross-org dependency exercises explicit long-form image URI resolution (`ghcr.io/kube-kaptain/...` vs default same-org), no extra auth needed since public. |
| 12 | `test-spec-check-filter-release` | `spec-check-filter-release` | JSON schema validation, API spec validation against meta-schema, OCI scratch packaging. `t4` token style. | Only spec-validation workflow. |
| 13 | `test-aws-eks-cluster-management` | `aws-eks-cluster-management` | Three-phase validation, cluster YAML generation, node group config with token substitution, secrets from `src/secrets/`. | Only EKS workflow. Needs stub/mock for AWS credentials or a test account. |

## Total: 13 repos

## Variant Feature Distribution

Each major feature tested at least once. Features that are pure config (token styles, QC options, etc.) are spread across repos rather than getting dedicated repos.

| Feature | Tested In | Notes |
|---------|-----------|-------|
| **Token styles** | shell (default, #2), mustache (#3), erb (#5), helm (#6), github-actions (#7), stringtemplate (#9), t4 (#12) | 7 of 10 styles covered; remaining 3 (blade, ognl, swift) are syntactic variants of the same substitution engine |
| **Name styles** | PascalCase (default, most), UPPER_SNAKE (#3), lower-kebab (#8) | Covers the main categories (pascal, snake, kebab) |
| **Name validation** | MATCH (default, most), ALL (#8 with lower-kebab) | |
| **Versioning: git-auto** | #1-3, #5-7, #9-13 | Default, tested broadly |
| **Versioning: file-pattern** | #4 | |
| **Versioning: compound** | #8 | |
| **Release branches** | #2 | Independent version sequence on `release/1.x` |
| **Multi-platform docker** | #3 | Single Dockerfile, `linux/amd64,linux/arm64` |
| **Squash modes** | squash-all (#3), default squash (others) | |
| **Token chaining** | #5 (multi-pass), #7 (override/defer) | |
| **Nested user tokens** | #3 | `Category/SubVar` paths |
| **Custom config-sub-path** | #8 | |
| **allow-builtin-token-override** | #7 | Template project pattern |
| **Trailing newline modes** | always-strip-one (#2), preserve-all (#8), default strip-for-single-line (others) | All 3 modes covered |
| **Additional tokens via hook** | #5, #9 | prePackagePrepare injects tokens; helm retag generates them |
| **All QC options** | #1 | Conventional branches + commits, slash blocking, double hyphen, duplicates |
| **All kubernetes generators** | #5 | deployment + service + configmap + secret + PDB + serviceaccount |
| **Workload types** | deployment (#5), statefulset (#6), cronjob (#7), job (not covered) | Job could be added to #8 if needed |
| **Image reference styles** | combined (default), separate (#6), project-name-prefixed-separate (#5) | 3 of 4 covered |
| **GitHub release file types** | #5 (substituted + verbatim + raw) | |
| **GitHub release notes** | from file (#5), auto-generated (others) | |
| **Helm post-processing** | #9 (sed + yq + file moves + image retag) | |
| **Layer/layerset** | #10 (layer), #11 (layerset with dependency on #10) | |
| **Manifest repo provider publish** | #5, #6, #7, #8, #9 (all kubernetes workflows) | |
| **Token override flow** | #7 | Manifests-only specific |
| **All 8 hooks** | #5 (only workflow type that has all 8) | |
| **6 hooks (docker)** | #3, #4, #10, #11, #12, #13 | |
| **6 hooks (package)** | #6, #7, #8, #9 | |
| **4 hooks** | #2 | |
| **2 hooks** | #1 | |

## Gaps

- **Job workload type**: not covered. Could add to #8 (bundle-resources) since it has no generators by default, or accept the gap since Job is structurally similar to CronJob minus the schedule wrapper.
- **blade, ognl, swift token styles**: not covered. Same substitution engine, just different delimiters. Low risk.
- **project-name-prefixed-combined image style**: not covered (3 of 4 styles are). Low risk, same logic with a different token prefix.
- **DaemonSet workload type**: not covered directly (layer naming reference removed). Could add to an existing kubernetes repo.
- **dockerfile-env-kubectl pattern type**: covered by #4 (file-pattern-match). Custom pattern type not separately tested but same code path.

## Implementation Notes

- All repos need: `KaptainPM.yaml`, `build.yaml` (workflow caller), minimal source files, `.kaptain/hooks/` scripts
- Hook validation scripts should be a shared library (common repo or copied) with per-workflow-type config
- `test-layerset-build` (#11) depends on `test-layer-build` (#10) being published first
- `test-eks-management` (#13) needs AWS credentials (org secret or test account) or a stub
- Seed tags needed for repos using git-auto versioning
- `test-docker-retag` (#4) needs a known upstream image to pull (e.g., `alpine:3.21`)
- Every repo tested three ways: local build, PR, merge to main
