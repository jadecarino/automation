#!/bin/bash

#
# Copyright contributors to the Galasa project
#
# SPDX-License-Identifier: EPL-2.0
#
#-----------------------------------------------------------------------------------------
#
# Objectives: Automate cleanup of GitHub Container Registry (GHCR) images
#
# This script automates the manual step from release.md lines 152-166
# Deletes images tagged with 'release' or 'prerelease' from GHCR
#
#-----------------------------------------------------------------------------------------

# Where is this script executing from ?
BASEDIR=$(dirname "$0");pushd $BASEDIR 2>&1 >> /dev/null ;BASEDIR=$(pwd);popd 2>&1 >> /dev/null
export ORIGINAL_DIR=$(pwd)

cd "${BASEDIR}/../.."
WORKSPACE_DIR=$(pwd)

#-----------------------------------------------------------------------------------------
# Set Colors
#-----------------------------------------------------------------------------------------
bold=$(tput bold)
underline=$(tput sgr 0 1)
reset=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 76)
white=$(tput setaf 7)
tan=$(tput setaf 202)
blue=$(tput setaf 25)

#-----------------------------------------------------------------------------------------
# Headers and Logging
#-----------------------------------------------------------------------------------------
underline() { printf "${underline}${bold}%s${reset}\n" "$@" ;}
h1() { printf "\n${underline}${bold}${blue}%s${reset}\n" "$@" ;}
h2() { printf "\n${underline}${bold}${white}%s${reset}\n" "$@" ;}
debug() { printf "${white}%s${reset}\n" "$@" ;}
info() { printf "${white}➜ %s${reset}\n" "$@" ;}
success() { printf "${green}✔ %s${reset}\n" "$@" ;}
error() { printf "${red}✖ %s${reset}\n" "$@" ;}
warn() { printf "${tan}➜ %s${reset}\n" "$@" ;}
bold() { printf "${bold}%s${reset}\n" "$@" ;}
note() { printf "\n${underline}${bold}${blue}Note:${reset} ${blue}%s${reset}\n" "$@" ;}

#-----------------------------------------------------------------------------------------
# Functions
#-----------------------------------------------------------------------------------------

function usage {
    info "Syntax: cleanup-ghcr-images.sh [OPTIONS]"
    cat << EOF
Options are:
--org <org>             : (required) GitHub organization (e.g., galasa-dev)
--tag <tag>             : (required) Tag to delete (e.g., release, prerelease)
--package <name>        : (optional) Specific package name to clean (can be specified multiple times)
--all-packages          : (optional) Clean all known Galasa packages
--dry-run               : (optional) Show what would be deleted without actually deleting
--yes                   : (optional) Skip confirmation prompts

Examples:
  # Delete 'release' tag from all known packages
  cleanup-ghcr-images.sh --org galasa-dev --tag release --all-packages

  # Delete 'prerelease' tag from specific packages
  cleanup-ghcr-images.sh --org galasa-dev --tag prerelease --package galasa-boot-embedded --package webui

  # Dry run to see what would be deleted
  cleanup-ghcr-images.sh --org galasa-dev --tag release --all-packages --dry-run
EOF
}

# List of all Galasa GHCR packages that need cleanup
GALASA_PACKAGES=(
    "obr-maven-artefacts"
    "obr-generic"
    "galasa-boot-embedded"
    "galasa-ibm-boot-embedded"
    "galasactl-x86_64"
    "galasactl-ibm-x86_64"
    "galasactl-executables"
    "galasa-isolated"
    "galasa-isolated-zip"
    "galasa-mvp"
    "galasa-mvp-zip"
    "buildutils-executables"
    "simplatform-maven-artefacts"
    "galasa-docs-site"
    "webui"
)

function delete_package_version {
    local org=$1
    local package=$2
    local tag=$3
    local dry_run=$4
    
    info "Processing package: ${package}"
    
    # Get all versions with the specified tag
    local versions=$(gh api \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "/orgs/${org}/packages/container/${package}/versions" \
        --jq ".[] | select(.metadata.container.tags[] | contains(\"${tag}\")) | .id" 2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        warn "Failed to get versions for package ${package} (package may not exist or no access)"
        return 0
    fi
    
    if [[ -z "$versions" ]]; then
        info "No versions found with tag '${tag}' for package ${package}"
        return 0
    fi
    
    # Delete each version
    local count=0
    for version_id in $versions; do
        if [[ "$dry_run" == "true" ]]; then
            info "[DRY RUN] Would delete version ${version_id} of ${package}"
        else
            info "Deleting version ${version_id} of ${package}..."
            gh api \
                --method DELETE \
                -H "Accept: application/vnd.github+json" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                "/orgs/${org}/packages/container/${package}/versions/${version_id}" 2>/dev/null
            
            if [[ $? -eq 0 ]]; then
                success "Deleted version ${version_id}"
                ((count++))
            else
                error "Failed to delete version ${version_id}"
            fi
        fi
    done
    
    if [[ $count -gt 0 ]]; then
        success "Deleted ${count} version(s) from ${package}"
    fi
    
    return 0
}

function cleanup_packages {
    local org=$1
    local tag=$2
    local dry_run=$3
    shift 3
    local packages=("$@")
    
    h1 "Cleaning up GHCR packages in organization: ${org}"
    info "Tag to delete: ${tag}"
    
    if [[ "$dry_run" == "true" ]]; then
        warn "DRY RUN MODE - No actual deletions will be performed"
    fi
    
    info "Packages to process: ${#packages[@]}"
    
    local total_processed=0
    local total_failed=0
    
    for package in "${packages[@]}"; do
        delete_package_version "$org" "$package" "$tag" "$dry_run"
        if [[ $? -eq 0 ]]; then
            ((total_processed++))
        else
            ((total_failed++))
        fi
    done
    
    h2 "Cleanup Summary"
    success "Packages processed: ${total_processed}"
    if [[ $total_failed -gt 0 ]]; then
        warn "Packages failed: ${total_failed}"
    fi
    
    return 0
}

#-----------------------------------------------------------------------------------------
# Process parameters
#-----------------------------------------------------------------------------------------
org=""
tag=""
packages=()
all_packages="false"
dry_run="false"
skip_confirm="false"

while [ "$1" != "" ]; do
    case $1 in
        --org )                 shift
                                org=$1
                                ;;
        --tag )                 shift
                                tag=$1
                                ;;
        --package )             shift
                                packages+=("$1")
                                ;;
        --all-packages )        all_packages="true"
                                ;;
        --dry-run )             dry_run="true"
                                ;;
        --yes )                 skip_confirm="true"
                                ;;
        -h | --help )           usage
                                exit 0
                                ;;
        * )                     error "Unexpected argument $1"
                                usage
                                exit 1
    esac
    shift
done

#-----------------------------------------------------------------------------------------
# Validate parameters
#-----------------------------------------------------------------------------------------
if [[ -z "$org" ]]; then
    error "Missing required parameter: --org"
    usage
    exit 1
fi

if [[ -z "$tag" ]]; then
    error "Missing required parameter: --tag"
    usage
    exit 1
fi

if [[ "$all_packages" == "true" ]]; then
    packages=("${GALASA_PACKAGES[@]}")
elif [[ ${#packages[@]} -eq 0 ]]; then
    error "Must specify either --all-packages or at least one --package"
    usage
    exit 1
fi

#-----------------------------------------------------------------------------------------
# Confirmation
#-----------------------------------------------------------------------------------------
if [[ "$skip_confirm" != "true" ]] && [[ "$dry_run" != "true" ]]; then
    warn "This will delete all versions tagged '${tag}' from ${#packages[@]} package(s) in ${org}"
    warn "This action cannot be undone!"
    read -p "Are you sure you want to continue? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        info "Cleanup cancelled"
        exit 0
    fi
fi

#-----------------------------------------------------------------------------------------
# Main logic
#-----------------------------------------------------------------------------------------
cleanup_packages "$org" "$tag" "$dry_run" "${packages[@]}"
exit $?

# Made with Bob
