#!/bin/bash

#
# Copyright contributors to the Galasa project
#
# SPDX-License-Identifier: EPL-2.0
#
#-----------------------------------------------------------------------------------------
#
# Objectives: Reusable function to monitor GitHub Actions workflow runs
#
# Usage: source this file and call monitor_workflow function
#
#-----------------------------------------------------------------------------------------

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
# Function: monitor_workflow
# 
# Monitors a GitHub Actions workflow run until completion
#
# Parameters:
#   $1 - run_id: The workflow run ID to monitor
#   $2 - repo: The repository in format "owner/repo" (e.g., "galasa-dev/galasa")
#   $3 - max_wait_minutes: Maximum time to wait in minutes (default: 120)
#   $4 - poll_interval_seconds: How often to check status (default: 30)
#
# Returns:
#   0 - Workflow completed successfully
#   1 - Workflow failed, was cancelled, or timed out
#
# Example:
#   monitor_workflow "12345678" "galasa-dev/galasa" 60 30
#-----------------------------------------------------------------------------------------
function monitor_workflow {
    local run_id=$1
    local repo=$2
    local max_wait_minutes=${3:-120}
    local poll_interval_seconds=${4:-30}
    
    if [[ -z "$run_id" ]] || [[ -z "$repo" ]]; then
        error "Usage: monitor_workflow <run_id> <repo> [max_wait_minutes] [poll_interval_seconds]"
        return 1
    fi
    
    h2 "Monitoring workflow run ${run_id} in repository ${repo}"
    info "Maximum wait time: ${max_wait_minutes} minutes"
    info "Poll interval: ${poll_interval_seconds} seconds"
    info "View workflow at: https://github.com/${repo}/actions/runs/${run_id}"
    
    local max_iterations=$((max_wait_minutes * 60 / poll_interval_seconds))
    local counter=0
    local elapsed_minutes=0
    
    while [[ $counter -lt $max_iterations ]]; do
        # Get workflow status
        local status=$(gh run view "$run_id" --repo "$repo" --json conclusion,status --jq '.conclusion // .status')
        local workflow_status=$(gh run view "$run_id" --repo "$repo" --json status --jq '.status')
        
        if [[ $? -ne 0 ]]; then
            error "Failed to get workflow status. Check that gh CLI is authenticated and the run_id is correct."
            return 1
        fi
        
        elapsed_minutes=$((counter * poll_interval_seconds / 60))
        
        # Check if workflow is still running
        if [[ "$workflow_status" == "completed" ]]; then
            case "$status" in
                "success")
                    success "Workflow completed successfully after ${elapsed_minutes} minutes!"
                    return 0
                    ;;
                "failure")
                    error "Workflow failed after ${elapsed_minutes} minutes."
                    error "Check the workflow run for details: https://github.com/${repo}/actions/runs/${run_id}"
                    return 1
                    ;;
                "cancelled")
                    error "Workflow was cancelled after ${elapsed_minutes} minutes."
                    return 1
                    ;;
                "skipped")
                    warn "Workflow was skipped."
                    return 1
                    ;;
                "timed_out")
                    error "Workflow timed out after ${elapsed_minutes} minutes."
                    return 1
                    ;;
                *)
                    error "Workflow completed with unknown status: ${status}"
                    return 1
                    ;;
            esac
        fi
        
        # Still running, wait and check again
        info "Workflow status: ${workflow_status} (${elapsed_minutes}/${max_wait_minutes} minutes elapsed)"
        sleep $poll_interval_seconds
        ((counter++))
    done
    
    # Timed out
    error "⏳ Timed out waiting for workflow ${run_id} to complete after ${max_wait_minutes} minutes."
    error "The workflow may still be running. Check: https://github.com/${repo}/actions/runs/${run_id}"
    return 1
}

#-----------------------------------------------------------------------------------------
# Function: trigger_and_monitor_workflow
# 
# Triggers a GitHub Actions workflow and monitors it until completion
#
# Parameters:
#   $1 - workflow_file: The workflow filename (e.g., "build.yaml")
#   $2 - repo: The repository in format "owner/repo"
#   $3 - ref: The git ref to run the workflow on (e.g., "main", "release")
#   $4+ - Additional gh workflow run parameters (e.g., "--field key=value")
#
# Returns:
#   0 - Workflow completed successfully
#   1 - Workflow failed or could not be triggered
#
# Example:
#   trigger_and_monitor_workflow "build.yaml" "galasa-dev/galasa" "release" "--field version=0.36.0"
#-----------------------------------------------------------------------------------------
function trigger_and_monitor_workflow {
    local workflow_file=$1
    local repo=$2
    local ref=$3
    shift 3
    local additional_params="$@"
    
    if [[ -z "$workflow_file" ]] || [[ -z "$repo" ]] || [[ -z "$ref" ]]; then
        error "Usage: trigger_and_monitor_workflow <workflow_file> <repo> <ref> [additional_params...]"
        return 1
    fi
    
    h1 "Triggering workflow ${workflow_file} in ${repo} on ref ${ref}"
    
    # Trigger the workflow
    local trigger_output=$(gh workflow run "$workflow_file" --repo "$repo" --ref "$ref" $additional_params 2>&1)
    local trigger_rc=$?
    
    if [[ $trigger_rc -ne 0 ]]; then
        error "Failed to trigger workflow: $trigger_output"
        return 1
    fi
    
    success "Workflow triggered successfully"
    
    # Wait a moment for the workflow to start
    info "Waiting 5 seconds for workflow to start..."
    sleep 5
    
    # Get the run ID of the most recent workflow run
    local run_id=$(gh run list --repo "$repo" --workflow "$workflow_file" --limit 1 --json databaseId --jq '.[0].databaseId')
    
    if [[ -z "$run_id" ]] || [[ "$run_id" == "null" ]]; then
        error "Failed to get workflow run ID"
        return 1
    fi
    
    success "Workflow started with Run ID: ${run_id}"
    
    # Monitor the workflow
    monitor_workflow "$run_id" "$repo"
    return $?
}

# Export functions if this script is sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f monitor_workflow
    export -f trigger_and_monitor_workflow
fi

# Made with Bob
