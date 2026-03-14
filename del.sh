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

init_var() {
    echo -e "${STEPS} Initializing parameters..."

    # Install required dependencies
    sudo apt-get -qq update && sudo apt-get -qq install -y jq curl

    # Options followed by [ : ] require a parameter value
    local options="r:a:t:p:l:w:s:d:k:o:g:"
    parsed_args=$(getopt -o "${options}" -- "${@}")
    [[ ${?} -ne 0 ]] && error_msg "Failed to parse command-line parameters."
    eval set -- "${parsed_args}"

    while true; do
        case "${1}" in
        -r | --repo)
            if [[ -n "${2}" ]]; then
                repo="${2}"
                shift 2
            else
                error_msg "Missing value for -r (repo) parameter [ ${2} ]!"
            fi
            ;;
        -a | --delete_releases)
            if [[ -n "${2}" ]]; then
                delete_releases="${2}"
                shift 2
            else
                error_msg "Missing value for -a (delete_releases) parameter [ ${2} ]!"
            fi
            ;;
        -t | --delete_tags)
            if [[ -n "${2}" ]]; then
                delete_tags="${2}"
                shift 2
            else
                error_msg "Missing value for -t (delete_tags) parameter [ ${2} ]!"
            fi
            ;;
        -p | --prerelease_option)
            if [[ -n "${2}" ]]; then
                prerelease_option="${2}"
                shift 2
            else
                error_msg "Missing value for -p (prerelease_option) parameter [ ${2} ]!"
            fi
            ;;
        -l | --releases_keep_latest)
            if [[ -n "${2}" ]]; then
                releases_keep_latest="${2}"
                shift 2
            else
                error_msg "Missing value for -l (releases_keep_latest) parameter [ ${2} ]!"
            fi
            ;;
        -w | --releases_keep_keyword)
            if [[ -n "${2}" ]]; then
                oldIFS="${IFS}"
                IFS="/"
                releases_keep_keyword=(${2})
                IFS="${oldIFS}"
                shift 2
            else
                error_msg "Missing value for -w (releases_keep_keyword) parameter [ ${2} ]!"
            fi
            ;;
        -s | --delete_workflows)
            if [[ -n "${2}" ]]; then
                delete_workflows="${2}"
                shift 2
            else
                error_msg "Missing value for -s (delete_workflows) parameter [ ${2} ]!"
            fi
            ;;
        -d | --workflows_keep_day)
            if [[ -n "${2}" ]]; then
                workflows_keep_day="${2}"
                shift 2
            else
                error_msg "Missing value for -d (workflows_keep_day) parameter [ ${2} ]!"
            fi
            ;;
        -k | --workflows_keep_keyword)
            if [[ -n "${2}" ]]; then
                oldIFS="${IFS}"
                IFS="/"
                workflows_keep_keyword=(${2})
                IFS="${oldIFS}"
                shift 2
            else
                error_msg "Missing value for -k (workflows_keep_keyword) parameter [ ${2} ]!"
            fi
            ;;
        -o | --out_log)
            if [[ -n "${2}" ]]; then
                out_log="${2}"
                shift 2
            else
                error_msg "Missing value for -o (out_log) parameter [ ${2} ]!"
            fi
            ;;
        -g | --gh_token)
            if [[ -n "${2}" ]]; then
                gh_token="${2}"
                shift 2
            else
                error_msg "Missing value for -g (gh_token) parameter [ ${2} ]!"
            fi
            ;;
        --)
            shift
            break
            ;;
        *)
            [[ -n "${1}" ]] && error_msg "Unrecognized option [ ${1} ]!"
            break
            ;;
        esac
    done

    echo -e "${INFO} repo: [ ${repo} ]"
    echo -e "${INFO} delete_releases: [ ${delete_releases} ]"
    echo -e "${INFO} delete_tags: [ ${delete_tags} ]"
    echo -e "${INFO} prerelease_option: [ ${prerelease_option} ]"
    echo -e "${INFO} releases_keep_latest: [ ${releases_keep_latest} ]"
    echo -e "${INFO} releases_keep_keyword: [ $(echo ${releases_keep_keyword[@]} | xargs) ]"
    echo -e "${INFO} delete_workflows: [ ${delete_workflows} ]"
    echo -e "${INFO} workflows_keep_day: [ ${workflows_keep_day} ]"
    echo -e "${INFO} workflows_keep_keyword: [ $(echo ${workflows_keep_keyword[@]} | xargs) ]"
    echo -e "${INFO} out_log: [ ${out_log} ]"
    echo -e ""
}

get_releases_list() {
    echo -e "${STEPS} Fetching releases list from GitHub API..."

    # Initialize API pagination
    github_page="1"

    # Create temporary file for storing results
    all_releases_list="josn_api_releases"
    echo "" >${all_releases_list}

    # Fetch releases via paginated API calls
    while true; do
        response="$(
            curl -s -L \
                -H "Accept: application/vnd.github+json" \
                -H "Authorization: Bearer ${gh_token}" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                "https://api.github.com/repos/${repo}/releases?per_page=${github_per_page}&page=${github_page}"
        )"

        # Check if the response is empty or an error occurred
        if [[ -z "${response}" ]] || [[ "${response}" == *"Not Found"* ]]; then
            break
        else
            # Get the number of results returned by the current page
            get_results_length="$(echo "${response}" | jq '. | length')"
            echo -e "${INFO} (1.1.${github_page}) Queried page [ ${github_page} ], returned [ ${get_results_length} ] results."

            # Sort results by publish date in descending order
            echo "${response}" |
                jq -s '.[] | sort_by(.published_at)|reverse' |
                jq -c '.[] | {date: .published_at, id: .id, prerelease: .prerelease, tag_name: .tag_name}' \
                    >>${all_releases_list}
        fi

        # Check if the current page has fewer results than the per_page limit
        if [[ "${get_results_length}" -lt "${github_per_page}" ]]; then
            break
        fi

        # Check if the current page is greater than the maximum page
        if [[ "${github_page}" -ge "${github_max_page}" ]]; then
            echo -e "${NOTE} (1.2.1) Reached the maximum page limit (${github_max_page}), stopping pagination."
            break
        else
            github_page="$((github_page + 1))"
        fi
    done

    if [[ -s "${all_releases_list}" ]]; then
        # Remove empty lines
        sed -i '/^[[:space:]]*$/d' "${all_releases_list}"

        # Print the result log
        echo -e "${INFO} (1.3.1) Releases list fetched successfully from GitHub API."
        [[ "${out_log}" =~ ^(true|yes)$ ]] && {
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
        elif [[ "${prerelease_option}" =~ ^(false|no)$ ]]; then
            echo -e "${INFO} (1.4.2) Filtering: retaining only non-pre-release items."
            cat ${all_releases_list} | jq -r '.prerelease' | grep -w "true" | while read line; do sed -i "/${line}/d" ${all_releases_list}; done
        elif [[ "${prerelease_option}" =~ ^(true|yes)$ ]]; then
            echo -e "${INFO} (1.4.3) Filtering: retaining only pre-release items."
            cat ${all_releases_list} | jq -r '.prerelease' | grep -w "false" | while read line; do sed -i "/${line}/d" ${all_releases_list}; done
        else
            error_msg "Invalid prerelease option [ ${prerelease_option} ]!"
        fi
        [[ "${out_log}" =~ ^(true|yes)$ ]] && echo -e "${INFO} (1.4.4) Releases list after pre-release filtering:\n$(cat ${all_releases_list})"
    else
        echo -e "${NOTE} (1.4.5) No releases found, skipping."
    fi

    # Filter releases by keyword exclusion
    keep_releases_keyword_list="josn_keep_releases_keyword_list"
    if [[ "${#releases_keep_keyword[@]}" -ge "1" && -s "${all_releases_list}" ]]; then
        # Match tags containing specified keywords
        echo -e "${INFO} (1.5.1) Keyword filter for release tags: [ $(echo ${releases_keep_keyword[@]} | xargs) ]"
        for ((i = 0; i < ${#releases_keep_keyword[@]}; i++)); do
            cat ${all_releases_list} | jq -r .tag_name | grep -E "${releases_keep_keyword[$i]}" >>${keep_releases_keyword_list}
        done
        [[ "${out_log}" =~ ^(true|yes)$ && -s "${keep_releases_keyword_list}" ]] && {
            echo -e "${INFO} (1.5.2) Tags matching keyword filter (to be retained):\n$(cat ${keep_releases_keyword_list})"
        }

        # Exclude matched tags from deletion list
        [[ -s "${keep_releases_keyword_list}" ]] && {
            cat ${keep_releases_keyword_list} | while read line; do sed -i "/${line}/d" ${all_releases_list}; done
            echo -e "${INFO} (1.5.3) Keyword-based tag filtering completed."
        }

        # Remaining releases after keyword filtering
        [[ "${out_log}" =~ ^(true|yes)$ ]] && echo -e "${INFO} (1.5.4) Releases list after keyword filtering:\n$(cat ${all_releases_list})"
    else
        echo -e "${NOTE} (1.5.5) No keyword filter specified, skipping."
    fi

    # Apply retention policy for latest releases
    keep_releases_list="josn_keep_releases_list"
    if [[ -s "${all_releases_list}" ]]; then
        if [[ "${releases_keep_latest}" -eq "0" ]]; then
            echo -e "${INFO} (1.6.1) Retention count set to 0, all releases will be deleted."
        else
            # Generate the list of latest releases to retain
            cat ${all_releases_list} | head -n ${releases_keep_latest} >${keep_releases_list}
            echo -e "${INFO} (1.6.2) Retention list generated successfully."
            [[ "${out_log}" =~ ^(true|yes)$ && -s "${keep_releases_list}" ]] && {
                echo -e "${INFO} (1.6.3) Releases to retain:\n$(cat ${keep_releases_list})"
            }

            # Remove retained releases from deletion candidates
            sed -i "1,${releases_keep_latest}d" ${all_releases_list}
        fi
    else
        echo -e "${NOTE} (1.6.4) No releases found, skipping."
    fi

    # Delete list
    if [[ -s "${all_releases_list}" ]]; then
        [[ "${out_log}" =~ ^(true|yes)$ ]] && echo -e "${INFO} (1.6.5) Releases scheduled for deletion:\n$(cat ${all_releases_list})"
    else
        echo -e "${NOTE} (1.6.6) No releases to delete, skipping."
    fi

    echo -e ""
}

del_releases_file() {
    echo -e "${STEPS} Deleting releases..."

    # Delete the target releases via API
    if [[ -s "${all_releases_list}" && -n "$(cat ${all_releases_list} | jq -r .id)" ]]; then
        cat ${all_releases_list} | jq -r .id | while read release_id; do
            {
                curl -s \
                    -X DELETE \
                    -H "Accept: application/vnd.github+json" \
                    -H "Authorization: Bearer ${gh_token}" \
                    -H "X-GitHub-Api-Version: 2022-11-28" \
                    https://api.github.com/repos/${repo}/releases/${release_id}
            }
        done
        echo -e "${SUCCESS} (1.7.1) Releases deleted successfully."
    else
        echo -e "${NOTE} (1.7.2) No releases to delete, skipping."
    fi

    echo -e ""
}

del_releases_tags() {
    echo -e "${STEPS} Deleting associated tags..."

    # Delete tags associated with the removed releases
    if [[ "${delete_tags}" =~ ^(true|yes)$ && -s "${all_releases_list}" && -n "$(cat ${all_releases_list} | jq -r .tag_name)" ]]; then
        cat ${all_releases_list} | jq -r .tag_name | while read tag_name; do
            {
                curl -s \
                    -X DELETE \
                    -H "Accept: application/vnd.github+json" \
                    -H "Authorization: Bearer ${gh_token}" \
                    -H "X-GitHub-Api-Version: 2022-11-28" \
                    https://api.github.com/repos/${repo}/git/refs/tags/${tag_name}
            }
        done
        echo -e "${SUCCESS} (1.8.1) Tags deleted successfully."
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
    all_workflows_list="josn_api_workflows"
    echo "" >${all_workflows_list}

    # Fetch workflow runs via paginated API calls
    while true; do
        response="$(
            curl -s -L \
                -H "Accept: application/vnd.github+json" \
                -H "Authorization: Bearer ${gh_token}" \
                -H "X-GitHub-Api-Version: 2022-11-28" \
                "https://api.github.com/repos/${repo}/actions/runs?per_page=${github_per_page}&page=${github_page}"
        )"

        # Check if the response is empty or an error occurred
        if [[ -z "${response}" ]] || [[ "${response}" == *"Not Found"* ]]; then
            break
        else
            # Get the number of results returned by the current page
            get_results_length="$(echo "${response}" | jq -r '.workflow_runs | length')"
            echo -e "${INFO} (2.1.${github_page}) Queried page [ ${github_page} ], returned [ ${get_results_length} ] results."

            # Extract completed workflow runs from response
            echo "${response}" |
                jq -c '.workflow_runs[] | select(.status == "completed") | {date: .updated_at, id: .id, name: .name}' \
                    >>${all_workflows_list}
        fi

        # Check if the current page has fewer results than the per_page limit
        if [[ "${get_results_length}" -lt "${github_per_page}" ]]; then
            break
        fi

        # Check if the current page is greater than the maximum page
        if [[ "${github_page}" -ge "${github_max_page}" ]]; then
            echo -e "${NOTE} (2.2.1) Reached the maximum page limit (${github_max_page}), stopping pagination."
            break
        else
            github_page="$((github_page + 1))"
        fi
    done

    if [[ -s "${all_workflows_list}" ]]; then
        # Remove empty lines
        sed -i '/^[[:space:]]*$/d' "${all_workflows_list}"

        # Print the result log
        echo -e "${INFO} (2.3.1) Workflow runs list fetched successfully from GitHub API."
        [[ "${out_log}" =~ ^(true|yes)$ ]] && {
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
    keep_keyword_workflows_list="josn_keep_keyword_workflows_list"
    # Exclude keyword-matched workflow runs from deletion
    if [[ "${#workflows_keep_keyword[@]}" -ge "1" && -s "${all_workflows_list}" ]]; then
        # Match workflow names containing specified keywords
        echo -e "${INFO} (2.4.1) Keyword filter for workflow runs: [ $(echo ${workflows_keep_keyword[@]} | xargs) ]"
        for ((i = 0; i < ${#workflows_keep_keyword[@]}; i++)); do
            cat ${all_workflows_list} | jq -r .name | grep -E "${workflows_keep_keyword[$i]}" >>${keep_keyword_workflows_list}
        done
        [[ "${out_log}" =~ ^(true|yes)$ && -s "${keep_keyword_workflows_list}" ]] && {
            echo -e "${INFO} (2.4.2) Workflow runs matching keyword filter (to be retained):\n$(cat ${keep_keyword_workflows_list})"
        }

        # Exclude matched workflow runs from deletion list
        [[ -s "${keep_keyword_workflows_list}" ]] && {
            cat ${keep_keyword_workflows_list} | while read line; do sed -i "/${line}/d" ${all_workflows_list}; done
            echo -e "${INFO} (2.4.3) Keyword-based workflow filtering completed."
        }

        # Remaining workflow runs after keyword filtering
        [[ "${out_log}" =~ ^(true|yes)$ ]] && echo -e "${INFO} (2.4.4) Workflow runs list after keyword filtering:\n$(cat ${all_workflows_list})"
    else
        echo -e "${NOTE} (2.4.5) No keyword filter specified, skipping."
    fi

    # Temporary file for workflow run dates
    all_workflows_date_list="josn_all_workflows_date_list"
    # Store workflow runs to retain based on date
    keep_workflows_list="josn_keep_workflows_list"
    # Temporary JSON file for deduplication
    tmp_josn_file="$(mktemp)"
    # Apply date-based retention policy for workflow runs
    if [[ -s "${all_workflows_list}" ]]; then
        if [[ "${workflows_keep_day}" -eq "0" ]]; then
            echo -e "${INFO} (2.5.1) Retention days set to 0, all workflow runs will be deleted."
        else
            # Filter workflow runs within the retention period
            today_second=$(date -d "$(date +"%Y%m%d")" +%s)
            cat ${all_workflows_list} | jq -r '.date' | awk -F'T' '{print $1}' | tr ' ' '\n' >${all_workflows_date_list}
            cat ${all_workflows_date_list} | while read line; do
                line_second="$(date -d "${line//-/}" +%s)"
                day_diff="$(((${today_second} - ${line_second}) / 86400))"
                [[ "${day_diff}" -lt "${workflows_keep_day}" ]] && {
                    grep "${line}T" ${all_workflows_list} >>${keep_workflows_list}
                    sed -i "/${line}T/d" ${all_workflows_list}
                }
            done
            echo -e "${INFO} (2.5.2) Retention list generated successfully."

            # Remove duplicate entries from retention list
            [[ -s "${keep_workflows_list}" ]] && {
                awk '!a[$0]++' ${keep_workflows_list} >${tmp_josn_file} && mv -f ${tmp_josn_file} ${keep_workflows_list}
                [[ "${out_log}" =~ ^(true|yes)$ ]] && echo -e "${INFO} (2.5.3) Workflow runs to retain:\n$(cat ${keep_workflows_list})"
            }
        fi
    else
        echo -e "${NOTE} (2.5.4) No workflow runs found, skipping."
    fi

    # Delete list
    if [[ -s "${all_workflows_list}" ]]; then
        [[ "${out_log}" =~ ^(true|yes)$ ]] && echo -e "${INFO} (2.5.5) Workflow runs scheduled for deletion:\n$(cat ${all_workflows_list})"
    else
        echo -e "${NOTE} (2.5.6) No workflow runs to delete, skipping."
    fi

    echo -e ""
}

del_workflows_runs() {
    echo -e "${STEPS} Deleting workflow runs..."

    # Delete the target workflow runs via API
    if [[ -s "${all_workflows_list}" && -n "$(cat ${all_workflows_list} | jq -r .id)" ]]; then
        cat ${all_workflows_list} | jq -r .id | while read run_id; do
            {
                curl -s \
                    -X DELETE \
                    -H "Accept: application/vnd.github+json" \
                    -H "Authorization: Bearer ${gh_token}" \
                    -H "X-GitHub-Api-Version: 2022-11-28" \
                    https://api.github.com/repos/${repo}/actions/runs/${run_id}
            }
        done
        echo -e "${SUCCESS} (2.6.1) Workflow runs deleted successfully."
    else
        echo -e "${NOTE} (2.6.2) No workflow runs to delete, skipping."
    fi

    echo -e ""
}

# Show welcome message
echo -e "${STEPS} Welcome! Starting cleanup of older releases and workflow runs."

# Execute operations in sequence
init_var "${@}"

# Handle releases deletion
if [[ "${delete_releases}" =~ ^(true|yes)$ ]]; then
    get_releases_list
    out_releases_list
    del_releases_file
    del_releases_tags
else
    echo -e "${STEPS} Releases and tags deletion is disabled, skipping."
fi

# Handle workflow runs deletion
if [[ "${delete_workflows}" =~ ^(true|yes)$ ]]; then
    get_workflows_list
    out_workflows_list
    del_workflows_runs
else
    echo -e "${STEPS} Workflow runs deletion is disabled, skipping."
fi

# Show completion summary
echo -e "${SUCCESS} All cleanup operations completed successfully."
