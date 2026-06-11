# Galasa Release Process - Automation Assessment & Plan

## Executive Summary

The Galasa release process currently involves **~50+ manual steps** across pre-release and release phases. This document provides a comprehensive analysis of the current process and a roadmap for automation via GitHub Actions workflows.

**Goal:** Automate all GitHub Actions-compatible steps of the release process, reducing manual intervention to only those steps requiring internal cicsk8s cluster access.

**Important Limitation:** Steps requiring access to the internal cicsk8s Kubernetes cluster (behind IBM firewall) **cannot be automated via GitHub Actions** and must remain manual or use alternative internal automation (e.g., internal Tekton/Jenkins pipelines).

---

## Current Process Analysis

### Pre-Release Process (10 automated steps + 8 manual steps)

#### Automated Steps (via scripts)
1. ✅ Create ArgoCD apps (`02-create-argocd-apps.sh`)
2. ✅ Delete old branches (`03-repo-branches-delete.sh`)
3. ✅ Create new branches (`04-repo-branches-create.sh`)
4. ✅ Check Helm charts released (`05-helm-charts.sh`)
5. ✅ Build Galasa mono repo (`10-build-galasa-mono-repo.sh`)
6. ✅ Check artifacts signed (`20-check-artifacts-signed.sh`)

#### Manual Steps Requiring Automation
1. ❌ **Manual Helm Release/Tag deletion** (prerelease.md lines 22-24, 35-37)
   - Navigate to GitHub UI
   - Click delete on each Release
   - Click delete on each Tag
   - **Automation:** Use GitHub API/CLI to delete releases and tags

2. ❌ **Manual workflow monitoring** (prerelease.md lines 38-42)
   - Watch Isolated build workflow
   - Watch Web UI build workflow
   - **Automation:** Poll workflow status via GitHub API

3. ❌ **Manual MEND security scan** (prerelease.md line 21, 50-52)
   - Follow internal wiki instructions
   - Upload MVP zip to MEND
   - Review results
   - **Automation:** Integrate MEND API if available, or create automated upload script

4. ❌ **Manual MVP testing** (prerelease.md lines 54-65)
   - Download MVP zip
   - Extract and test Docker image
   - Test Simplatform connectivity
   - **Automation:** Create automated test script with Docker and 3270 emulator

### Release Process (15 automated steps + 20+ manual steps)

#### Automated Steps (via scripts)
1. ✅ Create ArgoCD apps
2. ✅ Delete/create branches
3. ✅ Check Helm charts
4. ✅ Build Galasa
5. ✅ Check artifacts signed
6. ✅ Run test suites (23-28 scripts)
7. ✅ Publish to Maven Central Portal (30-central-publisher-portal.sh)
8. ✅ Deploy Docker images (34-deploy-docker-galasa.sh)
9. ✅ Tag repositories (41-tag-github-repositories.sh)
10. ✅ Update CPS properties (set-version.sh)

#### Manual Steps Requiring Automation

**Testing Phase:**
1. ❌ **Manual MVP testing** (release.md lines 45-56)
   - Same as pre-release
   - **Automation:** Reuse automated test script

2. ❌ **Manual MEND scan** (release.md lines 58-60)
   - Same as pre-release
   - **Automation:** Reuse MEND integration

3. ❌ **Manual workflow monitoring** (release.md lines 35-39, 68-74)
   - Monitor multiple GitHub Actions workflows
   - Monitor Tekton pipelines
   - **Automation:** Automated polling with status reporting

4. ❌ **Manual test failure handling** (release.md lines 89-97)
   - Manually edit YAML files
   - Manually run kubectl commands
   - **Automation:** Create retry mechanism with parameterized workflow

**Publishing Phase:**
5. ❌ **Manual Maven Central publishing** (31-publish-to-maven-central.md)
   - Log into Maven Central Portal
   - Check validation
   - Click "Publish" button
   - **Automation:** Use Maven Central Publisher API if available, or create automated browser script

6. ❌ **Manual Maven Central monitoring** (32-wait-maven.sh)
   - Currently uses `watch` command
   - **Automation:** Integrate into workflow with proper polling and timeout

7. ❌ **Manual docs publishing** (release.md lines 114-116)
   - Ensure branches are up to date
   - Manually trigger workflow
   - **Automation:** Automate branch sync and workflow trigger

**Release Artifacts:**
8. ❌ **Manual CLI release upload** (42-upload-cli-release.md)
   - Download binaries from website
   - Create GitHub release
   - Upload binaries
   - Add release notes
   - **Automation:** Use GitHub API to create release and upload assets

9. ❌ **Manual Isolated/MVP release upload** (43-upload-isolated-release.md)
   - Download zips
   - Create GitHub release
   - Upload zips
   - **Automation:** Use GitHub API to create release and upload assets

10. ❌ **Manual Homebrew/Scoop updates** (44-update-homebrew-and-scoop.md)
    - Clone repos
    - Run scripts
    - Check changes
    - Commit and push
    - **Automation:** Create automated PR workflow

**Version Bumping:**
11. ❌ **Manual version bumping** (95-move-to-new-version.md)
    - Create branches in multiple repos
    - Run set-version scripts
    - Build locally
    - Manual verification
    - Create PRs
    - Wait for builds
    - Merge PRs
    - **Automation:** Create automated PR workflow for version bumps

12. ❌ **Manual CPS property updates** (release.md lines 135-139)
    - Use galasactl to update properties
    - **Automation:** Script with galasactl commands

13. ❌ **Manual Docker image retagging** (release.md lines 141-147)
    - Pull, tag, push Docker images
    - **Automation:** Script with Docker commands

**Cleanup:**
14. ❌ **Manual GHCR image deletion** (release.md lines 152-166)
    - Delete 13+ images from GHCR
    - **Automation:** Use GitHub API to delete packages

---

## Automation Scope: What Can and Cannot Be Automated

### ✅ Steps That CAN Be Automated via GitHub Actions

**Pre-Release:**
- Create/delete ArgoCD apps (if ArgoCD is externally accessible)
- Create/delete GitHub branches
- Check Helm chart releases
- Build Galasa mono repo (triggers GitHub Actions workflow)
- Monitor GitHub Actions workflows (Isolated, Web UI builds)
- Check artifact signatures
- Delete Helm releases/tags for prerelease

**Release:**
- All pre-release automatable steps
- Run GitHub Actions-based tests (23-run-isolated-tests.sh, 24-run-simbank-ivts.sh, 25-run-ivts.sh)
- Publish to Maven Central Publisher Portal
- Monitor Maven Central availability
- Deploy Docker images to IBM Cloud Container Registry
- Tag GitHub repositories
- Create GitHub releases (CLI, Isolated/MVP)
- Update Homebrew/Scoop package managers
- Update CPS properties
- Retag Docker images
- Delete GHCR images
- Update documentation sites

### ❌ Steps That CANNOT Be Automated via GitHub Actions

**Reason:** Require access to internal cicsk8s Kubernetes cluster (behind IBM firewall)

**Affected Steps:**
1. **26-run-cicsts-isolated-tests.sh** - Runs Tekton pipeline on cicsk8s
2. **27-run-prod1-ivts.sh** - Runs Tekton pipeline on cicsk8s
3. **28-run-prod1-integration-tests.sh** - Runs Tekton pipeline on cicsk8s
4. **Any ArgoCD operations** - If ArgoCD server is only accessible from within IBM network
5. **Manual test reruns** - Requires kubectl access to cicsk8s

**Options for These Steps:**
1. **Keep manual** - Continue running these scripts manually from within IBM network
2. **Internal automation** - Create separate Tekton/Jenkins pipeline within IBM network
3. **Hybrid approach** - GitHub Actions triggers internal automation via webhook/API, waits for completion

### ⚠️ Steps Requiring Manual Approval (Even if Automated)

1. **Maven Central publishing** - May require manual approval in Portal UI
2. **MEND security scanning** - May require manual review of results
3. **Version bumping** - May want manual review of generated PRs before auto-merge

---

## Automation Strategy

### Phase 1: Quick Wins (Weeks 1-2)
**Goal:** Automate the most time-consuming manual steps

1. **Automate Helm Release/Tag deletion**
   - Create script using `gh release delete` and `gh api` for tags
   - Already partially fixed in 05-helm-charts.sh

2. **Automate GitHub Release creation**
   - Script to create releases and upload CLI/Isolated artifacts
   - Use `gh release create` with asset uploads

3. **Automate GHCR image cleanup**
   - Script using GitHub API to delete package versions
   - Can be added to cleanup workflow

4. **Automate workflow monitoring**
   - Create reusable function to poll workflow status
   - Add to existing scripts that trigger workflows

### Phase 2: Core Automation (Weeks 3-6)
**Goal:** Create main GitHub Actions workflow

1. **Create orchestrator workflow** (`release-orchestrator.yaml`)
   - Inputs: version, release_type (prerelease/release)
   - Calls all existing scripts in sequence
   - Handles error reporting and notifications

2. **Automate Maven Central publishing**
   - Research Maven Central Publisher API
   - Create automated approval mechanism or notification

3. **Automate MVP testing**
   - Create Docker-based test script
   - Run in GitHub Actions runner

4. **Automate docs publishing**
   - Add branch sync and workflow trigger steps

### Phase 3: Advanced Automation (Weeks 7-10)
**Goal:** Eliminate remaining manual steps

1. **Automate version bumping**
   - Create workflow to generate PRs across repos
   - Use GitHub API to create branches, commit changes, create PRs

2. **Automate Homebrew/Scoop updates**
   - Create workflow to update tap/bucket repos
   - Generate PRs automatically

3. **Integrate MEND scanning**
   - Research MEND API integration
   - Create automated scan submission and result retrieval

4. **Create test retry mechanism**
   - Parameterized workflow for test reruns
   - Automated failure detection and retry

### Phase 4: Polish & Monitoring (Weeks 11-12)
**Goal:** Production-ready automation

1. **Add comprehensive logging**
   - Structured logging for all steps
   - Progress tracking dashboard

2. **Add notifications**
   - Slack/email notifications for key milestones
   - Failure alerts with actionable information

3. **Create rollback mechanisms**
   - Automated rollback for failed releases
   - Cleanup of partial releases

4. **Documentation**
   - Update all documentation
   - Create runbooks for edge cases

---

## Proposed GitHub Actions Workflow Structure

```
.github/workflows/
├── release-orchestrator.yaml          # Main workflow
├── release-prerelease.yaml            # Pre-release sub-workflow
├── release-build.yaml                 # Build sub-workflow
├── release-test.yaml                  # Testing sub-workflow
├── release-publish.yaml               # Publishing sub-workflow
├── release-cleanup.yaml               # Cleanup sub-workflow
├── release-version-bump.yaml          # Version bump sub-workflow
└── utilities/
    ├── monitor-workflow.yaml          # Reusable workflow monitoring
    ├── create-github-release.yaml     # Reusable release creation
    └── update-package-managers.yaml   # Reusable Homebrew/Scoop updates
```

### Main Orchestrator Workflow

```yaml
name: Galasa Release Orchestrator

on:
  workflow_dispatch:
    inputs:
      release_type:
        description: 'Release type'
        required: true
        type: choice
        options:
          - prerelease
          - release
      version:
        description: 'Version to release (optional, auto-detected if not provided)'
        required: false
        type: string
      skip_tests:
        description: 'Skip test execution (for debugging)'
        required: false
        type: boolean
        default: false

jobs:
  setup:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.detect-version.outputs.version }}
    steps:
      - name: Detect version
        id: detect-version
        run: |
          # Auto-detect version from development.galasa.dev
          # Or use provided version
          
  prerelease:
    needs: setup
    if: inputs.release_type == 'prerelease'
    uses: ./.github/workflows/release-prerelease.yaml
    with:
      version: ${{ needs.setup.outputs.version }}
      
  release:
    needs: setup
    if: inputs.release_type == 'release'
    uses: ./.github/workflows/release-build.yaml
    with:
      version: ${{ needs.setup.outputs.version }}
      skip_tests: ${{ inputs.skip_tests }}
```

---

## Key Automation Challenges & Solutions

### Challenge 1: ArgoCD CLI Authentication
**Problem:** Scripts require ArgoCD SSO login
**Solution:** 
- Use ArgoCD API tokens in GitHub Secrets
- Or run ArgoCD commands from a runner with pre-configured access

### Challenge 2: Internal Kubernetes Cluster Access (cicsk8s)
**Problem:** Scripts require kubectl access to internal cicsk8s cluster which is behind IBM firewall
**Solution:**
- **Cannot be automated via GitHub Actions** - cluster is not accessible from external runners
- **Keep these steps manual** or create separate internal automation:
  - 26-run-cicsts-isolated-tests.sh (Tekton pipeline on cicsk8s)
  - 27-run-prod1-ivts.sh (Tekton pipeline on cicsk8s)
  - 28-run-prod1-integration-tests.sh (Tekton pipeline on cicsk8s)
  - Any ArgoCD operations that require cicsk8s access
- **Alternative:** Create internal Jenkins/Tekton pipeline that GitHub Actions can trigger via webhook or API
- **Note:** External ibmcloud cluster operations CAN be automated if kubeconfig is available

### Challenge 3: Maven Central Manual Approval
**Problem:** Maven Central requires manual login and button click
**Solution:**
- Research Maven Central Publisher API for automated publishing
- If not available, create notification workflow that pauses for manual approval
- Use GitHub Actions environment protection rules

### Challenge 4: MEND Scanning
**Problem:** MEND scanning is manual via internal wiki
**Solution:**
- Integrate MEND API if available
- Create automated upload script
- Or create notification workflow for manual scan with automated result retrieval

### Challenge 5: Test Monitoring Across Multiple Systems
**Problem:** Tests run in GitHub Actions and Tekton
**Solution:**
- Create unified monitoring script
- Poll both GitHub Actions API and Tekton API
- Aggregate results in single dashboard

### Challenge 6: Multi-Repo Version Bumping
**Problem:** Version bumps require changes across 8+ repositories
**Solution:**
- Create workflow that uses GitHub API to:
  - Create branches
  - Commit changes
  - Create PRs
  - Monitor PR builds
  - Auto-merge when successful

---

## Prerequisites for Full Automation

### Required Secrets/Tokens
1. `ARGOCD_TOKEN` - ArgoCD API token
2. `GH_TOKEN` - GitHub token with repo, workflow, packages permissions
3. `KUBECONFIG_CICSK8S` - Kubeconfig for internal cluster
4. `KUBECONFIG_IBMCLOUD` - Kubeconfig for IBM Cloud cluster
5. `MAVEN_CENTRAL_TOKEN` - Maven Central Publisher API token (if available)
6. `MEND_API_TOKEN` - MEND API token (if available)
7. `SLACK_WEBHOOK` - For notifications
8. `IBMCLOUD_API_KEY` - For IBM Cloud Container Registry

### Required Tools in Runner
1. `gh` CLI
2. `kubectl`
3. `argocd` CLI
4. `tkn` CLI (Tekton)
5. `docker`
6. `jq`
7. `curl`
8. `galasactl`
9. `ibmcloud` CLI

### Infrastructure Requirements
1. **GitHub-hosted runners** (recommended for external operations)
   - Can access public GitHub APIs, external websites, and ibmcloud cluster
   - Cannot access internal cicsk8s cluster (behind IBM firewall)
   
2. **Self-hosted runners** (optional, for additional capabilities)
   - Can be used for operations that don't require cicsk8s access
   - Still cannot access cicsk8s cluster from outside IBM network

3. **Internal automation** (required for cicsk8s operations)
   - Separate Tekton/Jenkins pipeline within IBM network
   - Can be triggered by GitHub Actions via webhook/API
   - Handles all cicsk8s-dependent operations

---

## Success Metrics

### Time Savings
- **Current:** 1 day of manual work
- **Target:** 4-6 hours of automated execution + 1-2 hours of monitoring

### Error Reduction
- **Current:** High risk of human error in manual steps
- **Target:** Eliminate 90% of manual errors through automation

### Repeatability
- **Current:** Process varies based on who executes it
- **Target:** 100% consistent execution every time

### Auditability
- **Current:** Limited logging of manual steps
- **Target:** Complete audit trail of all actions

---

## Next Steps

1. **Review and approve this plan** with the team
2. **Prioritize automation phases** based on pain points
3. **Set up required infrastructure** (secrets, runners, etc.)
4. **Begin Phase 1 implementation** (Quick Wins)
5. **Iterate and improve** based on feedback

---

## Notes

- All automation must be compatible with GitHub Actions
- Scripts should remain runnable locally for debugging
- Maintain backward compatibility during transition
- Create comprehensive documentation for each automated step
- Include rollback procedures for each phase