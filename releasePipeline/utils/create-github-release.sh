#!/bin/bash

#
# Copyright contributors to the Galasa project
#
# SPDX-License-Identifier: EPL-2.0
#
#-----------------------------------------------------------------------------------------
#
# Objectives: Automate creation of GitHub releases with asset uploads
#
# This script automates the manual steps from:
# - 42-upload-cli-release.md
# - 43-upload-isolated-release.md
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
    info "Syntax: create-github-release.sh [OPTIONS]"
    cat << EOF
Options are:
--repo <owner/repo>     : (required) Repository in format owner/repo (e.g., galasa-dev/galasa)
--tag <tag>             : (required) Tag name (e.g., v0.36.0)
--title <title>         : (optional) Release title (defaults to tag name)
--notes <notes>         : (optional) Release notes/description
--notes-file <file>     : (optional) File containing release notes
--asset <file>          : (optional) Asset file to upload (can be specified multiple times)
--asset-url <url>       : (optional) Download asset from URL before uploading (can be specified multiple times)
--draft                 : (optional) Create as draft release
--prerelease            : (optional) Mark as pre-release
--generate-notes        : (optional) Auto-generate release notes from commits

Examples:
  # Create release with local assets
  create-github-release.sh --repo galasa-dev/galasa --tag v0.36.0 --asset galasactl-linux-x86_64 --asset galasactl-darwin-arm64

  # Create release with assets downloaded from URL
  create-github-release.sh --repo galasa-dev/isolated --tag v0.36.0 \\
    --asset-url https://development.galasa.dev/release/maven-repo/isolated/dev/galasa/galasa-isolated/0.36.0/galasa-isolated-0.36.0.zip

  # Create draft release with custom notes
  create-github-release.sh --repo galasa-dev/galasa --tag v0.36.0 --draft --notes-file RELEASE_NOTES.md
EOF
}

function get_galasa_version {
    h2 "Detecting Galasa version from development.galasa.dev..."
    
    mkdir -p ${WORKSPACE_DIR}/temp
    
    url="https://development.galasa.dev/main/maven-repo/obr/dev/galasa/dev.galasa.uber.obr/"
    curl $url > ${WORKSPACE_DIR}/temp/galasa-version.txt -s
    rc=$?
    if [[ "${rc}" != "0" ]]; then 
        error "Failed to get galasa version from ${url}"
        return 1
    fi

    # Extract version from HTML
    galasa_version=$(cat ${WORKSPACE_DIR}/temp/galasa-version.txt | grep "<a href" | head -2 | tail -1 | cut -f2 -d'"' | cut -f1 -d'/')
    
    if [[ -z "$galasa_version" ]]; then
        error "Failed to extract galasa version"
        return 1
    fi
    
    success "Detected Galasa version: ${galasa_version}"
    echo "$galasa_version"
}

function download_asset {
    local url=$1
    local output_dir=$2
    
    info "Downloading asset from ${url}..."
    
    # Extract filename from URL
    local filename=$(basename "$url")
    local output_path="${output_dir}/${filename}"
    
    curl -L "$url" -o "$output_path" -s --fail
    rc=$?
    if [[ "${rc}" != "0" ]]; then 
        error "Failed to download asset from ${url}"
        return 1
    fi
    
    success "Downloaded ${filename}"
    echo "$output_path"
}

function create_release {
    local repo=$1
    local tag=$2
    local title=$3
    local notes=$4
    local draft=$5
    local prerelease=$6
    local generate_notes=$7
    shift 7
    local assets=("$@")
    
    h1 "Creating GitHub release for ${repo}"
    info "Tag: ${tag}"
    info "Title: ${title}"
    
    # Build gh release create command
    local cmd="gh release create \"${tag}\" --repo \"${repo}\" --title \"${title}\""
    
    if [[ "$draft" == "true" ]]; then
        cmd="$cmd --draft"
        info "Creating as draft release"
    fi
    
    if [[ "$prerelease" == "true" ]]; then
        cmd="$cmd --prerelease"
        info "Marking as pre-release"
    fi
    
    if [[ "$generate_notes" == "true" ]]; then
        cmd="$cmd --generate-notes"
        info "Auto-generating release notes"
    elif [[ -n "$notes" ]]; then
        cmd="$cmd --notes \"${notes}\""
    fi
    
    # Add assets
    for asset in "${assets[@]}"; do
        if [[ -f "$asset" ]]; then
            cmd="$cmd \"${asset}\""
            info "Will upload asset: $(basename ${asset})"
        else
            warn "Asset file not found, skipping: ${asset}"
        fi
    done
    
    # Execute command
    info "Executing: gh release create..."
    eval $cmd
    rc=$?
    
    if [[ "${rc}" != "0" ]]; then
        error "Failed to create release"
        return 1
    fi
    
    success "Release created successfully!"
    info "View release at: https://github.com/${repo}/releases/tag/${tag}"
    return 0
}

#-----------------------------------------------------------------------------------------
# Process parameters
#-----------------------------------------------------------------------------------------
repo=""
tag=""
title=""
notes=""
notes_file=""
draft="false"
prerelease="false"
generate_notes="false"
assets=()
asset_urls=()

while [ "$1" != "" ]; do
    case $1 in
        --repo )                shift
                                repo=$1
                                ;;
        --tag )                 shift
                                tag=$1
                                ;;
        --title )               shift
                                title=$1
                                ;;
        --notes )               shift
                                notes=$1
                                ;;
        --notes-file )          shift
                                notes_file=$1
                                ;;
        --asset )               shift
                                assets+=("$1")
                                ;;
        --asset-url )           shift
                                asset_urls+=("$1")
                                ;;
        --draft )               draft="true"
                                ;;
        --prerelease )          prerelease="true"
                                ;;
        --generate-notes )      generate_notes="true"
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
if [[ -z "$repo" ]]; then
    error "Missing required parameter: --repo"
    usage
    exit 1
fi

if [[ -z "$tag" ]]; then
    error "Missing required parameter: --tag"
    usage
    exit 1
fi

# Set default title if not provided
if [[ -z "$title" ]]; then
    title="$tag"
fi

# Read notes from file if provided
if [[ -n "$notes_file" ]]; then
    if [[ -f "$notes_file" ]]; then
        notes=$(cat "$notes_file")
    else
        error "Notes file not found: ${notes_file}"
        exit 1
    fi
fi

#-----------------------------------------------------------------------------------------
# Main logic
#-----------------------------------------------------------------------------------------
mkdir -p ${WORKSPACE_DIR}/temp/release-assets

# Download assets from URLs
for url in "${asset_urls[@]}"; do
    downloaded_asset=$(download_asset "$url" "${WORKSPACE_DIR}/temp/release-assets")
    if [[ $? -eq 0 ]]; then
        assets+=("$downloaded_asset")
    else
        error "Failed to download asset from ${url}"
        exit 1
    fi
done

# Create the release
create_release "$repo" "$tag" "$title" "$notes" "$draft" "$prerelease" "$generate_notes" "${assets[@]}"
rc=$?

# Cleanup
rm -rf ${WORKSPACE_DIR}/temp/release-assets

exit $rc

# Made with Bob
