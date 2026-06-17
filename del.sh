#!/usr/bin/env bash
#==============================================================================================
#
# Function: Delete older releases and workflow runs
# Copyright (C) 2023- https://github.com/ophub/delete-releases-workflows
# Refer to the GitHub REST API official documentation:
# https://docs.github.com/en/rest/releases/releases?list-releases
# https://docs.github.com/en/rest/actions/workflow-runs?list-workflow-runs-for-a-repository
#
#======================================= Functions list =======================================
#
# error_msg           : Output error message and exit
# sanitize_log        : Strip workflow command prefixes (::) from user-controlled strings
# cleanup             : Remove temporary state files on script exit
# init_var            : Initialize and validate all parameters
#
# get_releases_list   : Fetch the releases list from GitHub API
# out_releases_list   : Filter and generate the releases deletion list
# del_releases_file   : Delete the target releases via API
# del_releases_tags   : Delete the tags associated with removed releases
#
# get_workflows_list  : Fetch the workflow runs list from GitHub API
# out_workflows_list  : Filter and generate the workflow runs deletion list
# del_workflows_runs  : Delete the target workflow runs via API
#
#================================= Set environment variables ==================================
#
# Set default values
delete_releases="false"
delete_tags="false"
prerelease_option="all"
releases_keep_latest="90"
releases_keep_keyword=()
delete_workflows="false"
workflows_keep_day="90"
workflows_keep_keyword=()
out_log="false"

# Set the API to return 100 results per page
github_per_page="100"
# Set the maximum limit for API queries to 100 pages
github_max_page="100"

# Set output color labels
STEPS="[\033[95m STEPS \033[0m]"
INFO="[\033[94m INFO \033[0m]"
NOTE="[\033[93m NOTE \033[0m]"
ERROR="[\033[91m ERROR \033[0m]"
SUCCESS="[\033[92m SUCCESS \033[0m]"
#
#==============================================================================================

error_msg() {
    echo -e "${ERROR} ${1}"
    exit 1
}

# sanitize_log <string>
# Strips GitHub Actions workflow command prefixes (::error::, ::warning::, etc.)
# from user-controlled strings before echoing them to stdout. This prevents
# log injection attacks where a malicious keyword or repo name could inject
# workflow commands like ::error:: or ::add-mask::.
sanitize_log() {
    local input="${1}"
    printf '%s' "${input//::/⁘⁘}"
}

cleanup() {
    rm -f \
        "/tmp/json_api_releases_$$" \
        "/tmp/json_keep_releases_keyword_list_$$" \
        "/tmp/json_keep_releases_list_$$" \
        "/tmp/json_api_workflows_$$" \
        "/tmp/json_keep_keyword_workflows_list_$$" \
        "/tmp/json_keep_workflows_list_$$" \
        "/tmp/json_release_ids_$$" \
        "/tmp/json_tag_names_$$" \
        "/tmp/json_workflow_ids_$$"
}

init_var() {
    echo -e "${STEPS} Initializing parameters..."

    # Install required dependencies (skip if already installed)
    local missing_pkgs=()
    command -v jq >/dev/null 2>&1 || missing_pkgs+=("jq")
    command -v curl >/dev/null 2>&1 || missing_pkgs+=("curl")
    if [[ "${#missing_pkgs[@]}" -gt 0 ]]; then
        echo -e "${INFO} Installing missing dependencies: [ ${missing_pkgs[*]} ]"
        sudo apt-get -qq update && sudo apt-get -qq install -y "${missing_pkgs[@]}"
    fi

    # ── Read inputs from INPUT_* environment variables ────────────────────
    # All inputs are injected by action.yml as INPUT_* env vars.
    # GH_TOKEN is kept separate and never exposed in INPUT_* to avoid leaking
    # the token value into the process list or shell history.
    gh_token="${GH_TOKEN:-}"

    # Mask the token in all GitHub Actions log output to prevent accidental exposure
    [[ -n "${gh_token}" ]] && echo "::add-mask::${gh_token}"

    repo="${INPUT_REPO:-}"
    delete_releases="${INPUT_DELETE_RELEASES:-false}"
    delete_tags="${INPUT_DELETE_TAGS:-false}"
    prerelease_option="${INPUT_PRERELEASE_OPTION:-all}"
    releases_keep_latest="${INPUT_RELEASES_KEEP_LATEST:-90}"
    delete_workflows="${INPUT_DELETE_WORKFLOWS:-false}"
    workflows_keep_day="${INPUT_WORKFLOWS_KEEP_DAY:-90}"
    out_log="${INPUT_OUT_LOG:-false}"

    # Split slash-separated keywords into arrays (without triggering shell glob expansion)
    if [[ -n "${INPUT_RELEASES_KEEP_KEYWORD:-}" ]]; then
        IFS='/' read -r -a releases_keep_keyword <<<"${INPUT_RELEASES_KEEP_KEYWORD}"
    fi
    if [[ -n "${INPUT_WORKFLOWS_KEEP_KEYWORD:-}" ]]; then
        IFS='/' read -r -a workflows_keep_keyword <<<"${INPUT_WORKFLOWS_KEEP_KEYWORD}"
    fi

    # ── Validate required parameters ─────────────────────────────────────
    [[ -z "${gh_token}" ]] && error_msg "[ gh_token ] is required (must be set via the GH_TOKEN environment variable)."

    # ── Validate boolean inputs ──────────────────────────────────────────
    # Only true/false are accepted (as documented). Guards against typos like
    # "yes", "True", or "1" that would silently disable destructive operations.
    local bool_pair bool_name bool_value
    for bool_pair in \
        "delete_releases:${delete_releases}" \
        "delete_tags:${delete_tags}" \
        "delete_workflows:${delete_workflows}" \
        "out_log:${out_log}"; do
        bool_name="${bool_pair%%:*}"
        bool_value="${bool_pair#*:}"
        [[ ! "${bool_value}" =~ ^(true|false)$ ]] &&
            error_msg "Invalid value for ${bool_name}: '${bool_value}' must be 'true' or 'false'."
    done

    # ── Validate prerelease_option (must be all/true/false) ──────────────
    [[ ! "${prerelease_option}" =~ ^(all|true|false)$ ]] &&
        error_msg "Invalid value for prerelease_option: '${prerelease_option}' must be 'all', 'true', or 'false'."

    # ── Validate integer parameters ──────────────────────────────────────
    # For destructive operations, invalid values must fail explicitly rather
    # than silently resetting — a typo could lead to unintended data loss.
    [[ ! "${releases_keep_latest}" =~ ^(0|[1-9][0-9]*)$ ]] &&
        error_msg "Invalid value for releases_keep_latest: '${releases_keep_latest}' must be a non-negative integer."
    [[ ! "${workflows_keep_day}" =~ ^(0|[1-9][0-9]*)$ ]] &&
        error_msg "Invalid value for workflows_keep_day: '${workflows_keep_day}' must be a non-negative integer."

    echo -e "${INFO} repo:                   [ $(sanitize_log "${repo}") ]"
    echo -e "${INFO} delete_releases:        [ ${delete_releases} ]"
    echo -e "${INFO} delete_tags:            [ ${delete_tags} ]"
    echo -e "${INFO} prerelease_option:      [ ${prerelease_option} ]"
    echo -e "${INFO} releases_keep_latest:   [ ${releases_keep_latest} ]"
    echo -e "${INFO} releases_keep_keyword:  [ $(sanitize_log "$(printf '%s ' "${releases_keep_keyword[@]}")") ]"
    echo -e "${INFO} delete_workflows:       [ ${delete_workflows} ]"
    echo -e "${INFO} workflows_keep_day:     [ ${workflows_keep_day} ]"
    echo -e "${INFO} workflows_keep_keyword: [ $(sanitize_log "$(printf '%s ' "${workflows_keep_keyword[@]}")") ]"
    echo -e "${INFO} out_log:                [ ${out_log} ]"
    echo -e ""
}

get_releases_list() {
    echo -e "${STEPS} Fetching releases list from GitHub API..."

    # Initialize API pagination
    github_page="1"

    # Create temporary file for storing results
    all_releases_list="/tmp/json_api_releases_$$"
    >"${all_releases_list}"

    # Fetch releases via paginated API calls
    while true; do
        # Retry API call on transient errors; abort fast on auth/not-found errors
        api_retry=0
        response=""
        api_success="false"
        while [[ "${api_retry}" -lt 3 ]]; do
            tmp_body="$(mktemp)"
            http_code=$(
                curl -s -L -o "${tmp_body}" -w '%{http_code}' \
                    -H "Accept: application/vnd.github+json" \
                    -H "Authorization: Bearer ${gh_token}" \
                    -H "X-GitHub-Api-Version: 2022-11-28" \
                    "${GITHUB_API_URL:-https://api.github.com}/repos/${repo}/releases?per_page=${github_per_page}&page=${github_page}"
            )
            response="$(cat "${tmp_body}")"
            rm -f "${tmp_body}"

            # Fail fast on non-retryable client errors
            if [[ "${http_code}" =~ ^(401|403|404)$ ]]; then
                api_error="$(echo "${response}" | jq -r '.message // "Unknown error"' 2>/dev/null)"
                echo -e "${ERROR} (1.1.${github_page}) API error (HTTP ${http_code}): ${api_error}"
                break
            fi

            response_type="$(echo "${response}" | jq -r 'type' 2>/dev/null)"
            if [[ "${http_code}" == "200" && "${response_type}" == "array" ]]; then
                api_success="true"
                break
            else
                api_error="$(echo "${response}" | jq -r '.message // "Unknown error"' 2>/dev/null)"
                api_retry=$((${api_retry} + 1))
                if [[ "${api_retry}" -lt 3 ]]; then
                    echo -e "${NOTE} (1.1.${github_page}) API error (HTTP ${http_code}, attempt ${api_retry}/3): ${api_error}, retrying in 30s..."
                    sleep 30
                else
                    echo -e "${ERROR} (1.1.${github_page}) API error after 3 attempts (HTTP ${http_code}): ${api_error}"
                fi
            fi
        done

        # Skip if API call failed
        [[ "${api_success}" != "true" ]] && break

        # Get the number of results returned by the current page
        get_results_length="$(echo "${response}" | jq '. | length')"
        echo -e "${INFO} (1.1.${github_page}) Queried page [ ${github_page} ], returned [ ${get_results_length} ] results."

        # Sort results by publish date in descending order
        echo "${response}" |
            jq -s '.[] | sort_by(.published_at)|reverse' |
            jq -c '.[] | {date: .published_at, id: .id, prerelease: .prerelease, tag_name: .tag_name}' \
                >>${all_releases_list}

        # Check if the current page has fewer results than the per_page limit
        if [[ "${get_results_length}" -lt "${github_per_page}" ]]; then
            break
        fi

        # Check if the current page is greater than the maximum page
        if [[ "${github_page}" -ge "${github_max_page}" ]]; then
            echo -e "${NOTE} (1.2.1) Reached the maximum page limit (${github_max_page}). If more releases exist, please run this action again."
            break
        else
            github_page="$((${github_page} + 1))"
        fi
    done

    if [[ -s "${all_releases_list}" ]]; then
        # Remove empty lines
        sed '/^[[:space:]]*$/d' "${all_releases_list}" >"${all_releases_list}.tmp" && mv "${all_releases_list}.tmp" "${all_releases_list}"

        # Global sort by date descending across all pages
        tmp_sort_file="$(mktemp)"
        jq -sc 'sort_by(.date) | reverse | .[]' "${all_releases_list}" >"${tmp_sort_file}" && mv "${tmp_sort_file}" "${all_releases_list}"

        # Print the result log
        echo -e "${INFO} (1.3.1) Releases list fetched successfully from GitHub API."
        [[ "${out_log}" == "true" ]] && {
            echo -e "${INFO} (1.3.2) Total releases found: [ $(cat ${all_releases_list} | wc -l) ]"
            echo -e "${INFO} (1.3.3) All releases list:\n$(cat ${all_releases_list})"
        }
    else
        echo -e "${NOTE} (1.3.4) No releases found, skipping."
    fi
}

out_releases_list() {
    echo -e "${STEPS} Filtering and preparing releases deletion list..."

    if [[ -s "${all_releases_list}" ]]; then
        # Filter based on the prerelease option(all/false/true)
        if [[ "${prerelease_option}" == "all" ]]; then
            echo -e "${NOTE} (1.4.1) Pre-release filter set to 'all', no filtering applied."
        elif [[ "${prerelease_option}" == "false" ]]; then
            echo -e "${INFO} (1.4.2) Filtering: retaining only non-pre-release items."
            tmp_prerelease="$(mktemp)"
            jq -c 'select(.prerelease == false)' "${all_releases_list}" >"${tmp_prerelease}" && mv "${tmp_prerelease}" "${all_releases_list}"
        elif [[ "${prerelease_option}" == "true" ]]; then
            echo -e "${INFO} (1.4.3) Filtering: retaining only pre-release items."
            tmp_prerelease="$(mktemp)"
            jq -c 'select(.prerelease == true)' "${all_releases_list}" >"${tmp_prerelease}" && mv "${tmp_prerelease}" "${all_releases_list}"
        fi
        [[ "${out_log}" == "true" ]] && echo -e "${INFO} (1.4.4) Releases list after pre-release filtering:\n$(cat ${all_releases_list})"
    else
        echo -e "${NOTE} (1.4.5) No releases found, skipping."
    fi

    # Filter releases by keyword exclusion
    keep_releases_keyword_list="/tmp/json_keep_releases_keyword_list_$$"
    >"${keep_releases_keyword_list}"
    if [[ "${#releases_keep_keyword[@]}" -ge "1" && -s "${all_releases_list}" ]]; then
        # Match tags containing specified keywords
        echo -e "${INFO} (1.5.1) Keyword filter for release tags: [ $(sanitize_log "$(printf '%s ' "${releases_keep_keyword[@]}")") ]"

        # Build JSON array of keywords for safe jq matching
        keywords_json="$(printf '%s\n' "${releases_keep_keyword[@]}" | jq -R . | jq -sc '.')"

        # Save matched releases (to retain) to keyword list
        jq -c --argjson kws "${keywords_json}" \
            'select(. as $item | any($kws[]; . as $k | $item.tag_name | contains($k)))' \
            "${all_releases_list}" >"${keep_releases_keyword_list}"

        [[ "${out_log}" == "true" && -s "${keep_releases_keyword_list}" ]] && {
            echo -e "${INFO} (1.5.2) Tags matching keyword filter (to be retained):\n$(cat ${keep_releases_keyword_list})"
        }

        # Exclude matched releases from deletion list
        if [[ -s "${keep_releases_keyword_list}" ]]; then
            tmp_keyword="$(mktemp)"
            jq -c --argjson kws "${keywords_json}" \
                'select(. as $item | any($kws[]; . as $k | $item.tag_name | contains($k)) | not)' \
                "${all_releases_list}" >"${tmp_keyword}" && mv "${tmp_keyword}" "${all_releases_list}"
            echo -e "${INFO} (1.5.3) Keyword-based tag filtering completed."
        fi

        # Remaining releases after keyword filtering
        [[ "${out_log}" == "true" ]] && echo -e "${INFO} (1.5.4) Releases list after keyword filtering:\n$(cat ${all_releases_list})"
    else
        echo -e "${NOTE} (1.5.5) No keyword filter specified, skipping."
    fi

    # Apply retention policy for latest releases
    keep_releases_list="/tmp/json_keep_releases_list_$$"
    >"${keep_releases_list}"
    if [[ -s "${all_releases_list}" ]]; then
        if [[ "${releases_keep_latest}" -eq "0" ]]; then
            echo -e "${INFO} (1.6.1) Retention count set to 0, no releases will be retained; all candidates will be deleted."
        else
            # Generate the list of latest releases to retain
            head -n "${releases_keep_latest}" "${all_releases_list}" >"${keep_releases_list}"
            echo -e "${INFO} (1.6.2) Retention list generated successfully."
            [[ "${out_log}" == "true" && -s "${keep_releases_list}" ]] && {
                echo -e "${INFO} (1.6.3) Releases to retain:\n$(cat ${keep_releases_list})"
            }

            # Remove retained releases from deletion candidates
            sed "1,${releases_keep_latest}d" "${all_releases_list}" >"${all_releases_list}.tmp" && mv "${all_releases_list}.tmp" "${all_releases_list}"
        fi
    else
        echo -e "${NOTE} (1.6.4) No releases found, skipping."
    fi

    # Delete list
    if [[ -s "${all_releases_list}" ]]; then
        [[ "${out_log}" == "true" ]] && echo -e "${INFO} (1.6.5) Releases scheduled for deletion:\n$(cat ${all_releases_list})"
    else
        echo -e "${NOTE} (1.6.6) No releases to delete, skipping."
    fi

    echo -e ""
}

del_releases_file() {
    echo -e "${STEPS} Deleting releases..."

    # Extract release IDs once to avoid redundant jq parsing
    local release_ids_file="/tmp/json_release_ids_$$"
    jq -r '.id // empty' "${all_releases_list}" >"${release_ids_file}" 2>/dev/null

    # Delete the target releases via API
    if [[ -s "${release_ids_file}" ]]; then
        local del_success=0
        local del_fail=0
        while IFS= read -r release_id; do
            retry=0
            while true; do
                http_code=$(
                    curl -s -o /dev/null -w '%{http_code}' \
                        -X DELETE \
                        -H "Accept: application/vnd.github+json" \
                        -H "Authorization: Bearer ${gh_token}" \
                        -H "X-GitHub-Api-Version: 2022-11-28" \
                        "${GITHUB_API_URL:-https://api.github.com}/repos/${repo}/releases/${release_id}"
                )
                if [[ "${http_code}" =~ ^(200|204)$ ]]; then
                    del_success=$((${del_success} + 1))
                    break
                elif [[ "${http_code}" == "404" ]]; then
                    # Already deleted (e.g. by a concurrent job) — treat as success
                    del_success=$((${del_success} + 1))
                    echo -e "${NOTE} Release [ ${release_id} ] not found (already deleted), skipping."
                    break
                elif [[ ("${http_code}" == "429" || "${http_code}" =~ ^5) && "${retry}" -lt 3 ]]; then
                    retry=$((${retry} + 1))
                    echo -e "${NOTE} HTTP ${http_code} (release ${release_id}), retry ${retry}/3, waiting 60s..."
                    sleep 60
                else
                    echo -e "${ERROR} Failed to delete release [ ${release_id} ] (HTTP ${http_code})"
                    del_fail=$((${del_fail} + 1))
                    break
                fi
            done
        done <"${release_ids_file}"
        echo -e "${SUCCESS} (1.7.1) Releases deletion completed: [ ${del_success} ] succeeded, [ ${del_fail} ] failed."
    else
        echo -e "${NOTE} (1.7.2) No releases to delete, skipping."
    fi

    echo -e ""
}

del_releases_tags() {
    echo -e "${STEPS} Deleting associated tags..."

    # Extract tag names once to avoid redundant jq parsing
    local tag_names_file="/tmp/json_tag_names_$$"
    jq -r '.tag_name // empty' "${all_releases_list}" >"${tag_names_file}" 2>/dev/null

    # Delete tags associated with the removed releases
    if [[ "${delete_tags}" == "true" && -s "${tag_names_file}" ]]; then
        local del_success=0
        local del_fail=0
        while IFS= read -r tag_name; do
            retry=0
            while true; do
                http_code=$(
                    curl -s -o /dev/null -w '%{http_code}' \
                        -X DELETE \
                        -H "Accept: application/vnd.github+json" \
                        -H "Authorization: Bearer ${gh_token}" \
                        -H "X-GitHub-Api-Version: 2022-11-28" \
                        "${GITHUB_API_URL:-https://api.github.com}/repos/${repo}/git/refs/tags/${tag_name}"
                )
                if [[ "${http_code}" =~ ^(200|204)$ ]]; then
                    del_success=$((${del_success} + 1))
                    break
                elif [[ "${http_code}" == "404" ]]; then
                    # Tag already deleted — treat as success
                    del_success=$((${del_success} + 1))
                    echo -e "${NOTE} Tag [ ${tag_name} ] not found (already deleted), skipping."
                    break
                elif [[ ("${http_code}" == "429" || "${http_code}" =~ ^5) && "${retry}" -lt 3 ]]; then
                    retry=$((${retry} + 1))
                    echo -e "${NOTE} HTTP ${http_code} (tag ${tag_name}), retry ${retry}/3, waiting 60s..."
                    sleep 60
                else
                    echo -e "${ERROR} Failed to delete tag [ ${tag_name} ] (HTTP ${http_code})"
                    del_fail=$((${del_fail} + 1))
                    break
                fi
            done
        done <"${tag_names_file}"
        echo -e "${SUCCESS} (1.8.1) Tags deletion completed: [ ${del_success} ] succeeded, [ ${del_fail} ] failed."
    else
        echo -e "${NOTE} (1.8.2) No tags to delete, skipping."
    fi

    echo -e ""
}

get_workflows_list() {
    echo -e "${STEPS} Fetching workflow runs list from GitHub API..."

    # Initialize API pagination
    github_page="1"

    # Create temporary file for storing results
    all_workflows_list="/tmp/json_api_workflows_$$"
    >"${all_workflows_list}"

    # Fetch workflow runs via paginated API calls
    while true; do
        # Retry API call on transient errors; abort fast on auth/not-found errors
        api_retry=0
        response=""
        api_success="false"
        while [[ "${api_retry}" -lt 3 ]]; do
            tmp_body="$(mktemp)"
            http_code=$(
                curl -s -L -o "${tmp_body}" -w '%{http_code}' \
                    -H "Accept: application/vnd.github+json" \
                    -H "Authorization: Bearer ${gh_token}" \
                    -H "X-GitHub-Api-Version: 2022-11-28" \
                    "${GITHUB_API_URL:-https://api.github.com}/repos/${repo}/actions/runs?per_page=${github_per_page}&page=${github_page}"
            )
            response="$(cat "${tmp_body}")"
            rm -f "${tmp_body}"

            # Fail fast on non-retryable client errors
            if [[ "${http_code}" =~ ^(401|403|404)$ ]]; then
                api_error="$(echo "${response}" | jq -r '.message // "Unknown error"' 2>/dev/null)"
                echo -e "${ERROR} (2.1.${github_page}) API error (HTTP ${http_code}): ${api_error}"
                break
            fi

            if [[ "${http_code}" == "200" && "$(echo "${response}" | jq 'has("workflow_runs")' 2>/dev/null)" == "true" ]]; then
                api_success="true"
                break
            else
                api_error="$(echo "${response}" | jq -r '.message // "Unknown error"' 2>/dev/null)"
                api_retry=$((${api_retry} + 1))
                if [[ "${api_retry}" -lt 3 ]]; then
                    echo -e "${NOTE} (2.1.${github_page}) API error (HTTP ${http_code}, attempt ${api_retry}/3): ${api_error}, retrying in 30s..."
                    sleep 30
                else
                    echo -e "${ERROR} (2.1.${github_page}) API error after 3 attempts (HTTP ${http_code}): ${api_error}"
                fi
            fi
        done

        # Skip if API call failed
        [[ "${api_success}" != "true" ]] && break

        # Get the number of results returned by the current page
        get_results_length="$(echo "${response}" | jq -r '.workflow_runs | length')"
        echo -e "${INFO} (2.1.${github_page}) Queried page [ ${github_page} ], returned [ ${get_results_length} ] results."

        # Extract completed workflow runs from response
        echo "${response}" |
            jq -c '.workflow_runs[] | select(.status == "completed") | {date: .updated_at, id: .id, name: .name}' \
                >>${all_workflows_list}

        # Check if the current page has fewer results than the per_page limit
        if [[ "${get_results_length}" -lt "${github_per_page}" ]]; then
            break
        fi

        # Check if the current page is greater than the maximum page
        if [[ "${github_page}" -ge "${github_max_page}" ]]; then
            echo -e "${NOTE} (2.2.1) Reached the maximum page limit (${github_max_page}). If more workflow runs exist, please run this action again."
            break
        else
            github_page="$((${github_page} + 1))"
        fi
    done

    if [[ -s "${all_workflows_list}" ]]; then
        # Remove empty lines
        sed '/^[[:space:]]*$/d' "${all_workflows_list}" >"${all_workflows_list}.tmp" && mv "${all_workflows_list}.tmp" "${all_workflows_list}"

        # Global sort by date descending across all pages
        tmp_sort_file="$(mktemp)"
        jq -sc 'sort_by(.date) | reverse | .[]' "${all_workflows_list}" >"${tmp_sort_file}" && mv "${tmp_sort_file}" "${all_workflows_list}"

        # Print the result log
        echo -e "${INFO} (2.3.1) Workflow runs list fetched successfully from GitHub API."
        [[ "${out_log}" == "true" ]] && {
            echo -e "${INFO} (2.3.2) Total workflow runs found: [ $(cat ${all_workflows_list} | wc -l) ]"
            echo -e "${INFO} (2.3.3) All workflow runs list:\n$(cat ${all_workflows_list})"
        }
    else
        echo -e "${NOTE} (2.3.4) No workflow runs found, skipping."
    fi
}

out_workflows_list() {
    echo -e "${STEPS} Filtering and preparing workflow runs deletion list..."

    # Store workflow runs matching keywords for retention
    keep_keyword_workflows_list="/tmp/json_keep_keyword_workflows_list_$$"
    >"${keep_keyword_workflows_list}"
    # Exclude keyword-matched workflow runs from deletion
    if [[ "${#workflows_keep_keyword[@]}" -ge "1" && -s "${all_workflows_list}" ]]; then
        # Match workflow names containing specified keywords
        echo -e "${INFO} (2.4.1) Keyword filter for workflow runs: [ $(sanitize_log "$(printf '%s ' "${workflows_keep_keyword[@]}")") ]"

        # Build JSON array of keywords for safe jq matching
        wf_keywords_json="$(printf '%s\n' "${workflows_keep_keyword[@]}" | jq -R . | jq -sc '.')"

        # Save matched workflow runs (to retain) to keyword list
        jq -c --argjson kws "${wf_keywords_json}" \
            'select(. as $item | any($kws[]; . as $k | $item.name | contains($k)))' \
            "${all_workflows_list}" >"${keep_keyword_workflows_list}"

        [[ "${out_log}" == "true" && -s "${keep_keyword_workflows_list}" ]] && {
            echo -e "${INFO} (2.4.2) Workflow runs matching keyword filter (to be retained):\n$(cat ${keep_keyword_workflows_list})"
        }

        # Exclude matched workflow runs from deletion list
        if [[ -s "${keep_keyword_workflows_list}" ]]; then
            tmp_wf_keyword="$(mktemp)"
            jq -c --argjson kws "${wf_keywords_json}" \
                'select(. as $item | any($kws[]; . as $k | $item.name | contains($k)) | not)' \
                "${all_workflows_list}" >"${tmp_wf_keyword}" && mv "${tmp_wf_keyword}" "${all_workflows_list}"
            echo -e "${INFO} (2.4.3) Keyword-based workflow filtering completed."
        fi

        # Remaining workflow runs after keyword filtering
        [[ "${out_log}" == "true" ]] && echo -e "${INFO} (2.4.4) Workflow runs list after keyword filtering:\n$(cat ${all_workflows_list})"
    else
        echo -e "${NOTE} (2.4.5) No keyword filter specified, skipping."
    fi

    # Store workflow runs to retain based on date
    keep_workflows_list="/tmp/json_keep_workflows_list_$$"
    >"${keep_workflows_list}"
    # Apply date-based retention policy for workflow runs
    if [[ -s "${all_workflows_list}" ]]; then
        if [[ "${workflows_keep_day}" -eq "0" ]]; then
            echo -e "${INFO} (2.5.1) Retention days set to 0, no workflow runs will be retained; all candidates will be deleted."
        else
            # Filter workflow runs within the retention period using a single jq pass for performance
            cutoff_second=$(($(date +%s) - workflows_keep_day * 86400))
            tmp_wf_date="$(mktemp)"
            jq -c --argjson c "${cutoff_second}" 'select((.date | fromdateiso8601) >= $c)' \
                "${all_workflows_list}" >"${keep_workflows_list}"
            jq -c --argjson c "${cutoff_second}" 'select((.date | fromdateiso8601) <  $c)' \
                "${all_workflows_list}" >"${tmp_wf_date}"
            mv "${tmp_wf_date}" "${all_workflows_list}"
            echo -e "${INFO} (2.5.2) Retention list generated successfully."

            [[ -s "${keep_workflows_list}" && "${out_log}" == "true" ]] && {
                echo -e "${INFO} (2.5.3) Workflow runs to retain:\n$(cat ${keep_workflows_list})"
            }
        fi
    else
        echo -e "${NOTE} (2.5.4) No workflow runs found, skipping."
    fi

    # Delete list
    if [[ -s "${all_workflows_list}" ]]; then
        [[ "${out_log}" == "true" ]] && echo -e "${INFO} (2.5.5) Workflow runs scheduled for deletion:\n$(cat ${all_workflows_list})"
    else
        echo -e "${NOTE} (2.5.6) No workflow runs to delete, skipping."
    fi

    echo -e ""
}

del_workflows_runs() {
    echo -e "${STEPS} Deleting workflow runs..."

    # Extract workflow run IDs once to avoid redundant jq parsing
    local workflow_ids_file="/tmp/json_workflow_ids_$$"
    jq -r '.id // empty' "${all_workflows_list}" >"${workflow_ids_file}" 2>/dev/null

    # Delete the target workflow runs via API
    if [[ -s "${workflow_ids_file}" ]]; then
        local del_success=0
        local del_fail=0
        while IFS= read -r run_id; do
            retry=0
            while true; do
                http_code=$(
                    curl -s -o /dev/null -w '%{http_code}' \
                        -X DELETE \
                        -H "Accept: application/vnd.github+json" \
                        -H "Authorization: Bearer ${gh_token}" \
                        -H "X-GitHub-Api-Version: 2022-11-28" \
                        "${GITHUB_API_URL:-https://api.github.com}/repos/${repo}/actions/runs/${run_id}"
                )
                if [[ "${http_code}" =~ ^(200|204)$ ]]; then
                    del_success=$((${del_success} + 1))
                    break
                elif [[ "${http_code}" == "404" ]]; then
                    # Workflow run already deleted — treat as success
                    del_success=$((${del_success} + 1))
                    echo -e "${NOTE} Workflow run [ ${run_id} ] not found (already deleted), skipping."
                    break
                elif [[ ("${http_code}" == "429" || "${http_code}" =~ ^5) && "${retry}" -lt 3 ]]; then
                    retry=$((${retry} + 1))
                    echo -e "${NOTE} HTTP ${http_code} (workflow run ${run_id}), retry ${retry}/3, waiting 60s..."
                    sleep 60
                else
                    echo -e "${ERROR} Failed to delete workflow run [ ${run_id} ] (HTTP ${http_code})"
                    del_fail=$((${del_fail} + 1))
                    break
                fi
            done
        done <"${workflow_ids_file}"
        echo -e "${SUCCESS} (2.6.1) Workflow runs deletion completed: [ ${del_success} ] succeeded, [ ${del_fail} ] failed."
    else
        echo -e "${NOTE} (2.6.2) No workflow runs to delete, skipping."
    fi

    echo -e ""
}

# Show welcome message
echo -e "${STEPS} Welcome! Starting cleanup of older releases and workflow runs."

# Bash 4.0+ is required for associative arrays and other bash-specific features
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo -e "${ERROR} bash 4.0+ required (current: ${BASH_VERSION})."
    echo -e "${NOTE} On macOS, install a newer bash: brew install bash"
    exit 1
fi

# Clean up temporary state files on exit
trap cleanup EXIT

# Execute operations in sequence
init_var

# Handle releases deletion
if [[ "${delete_releases}" == "true" ]]; then
    get_releases_list
    out_releases_list
    del_releases_file
    del_releases_tags
else
    echo -e "${STEPS} Releases and tags deletion is disabled, skipping."
fi

# Handle workflow runs deletion
if [[ "${delete_workflows}" == "true" ]]; then
    get_workflows_list
    out_workflows_list
    del_workflows_runs
else
    echo -e "${STEPS} Workflow runs deletion is disabled, skipping."
fi

# Show completion summary
echo -e "${SUCCESS} All cleanup operations completed successfully."
