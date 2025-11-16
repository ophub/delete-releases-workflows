#!/usr/bin/env bash
#==============================================================================================
#
# Function: Delete older releases and workflow runs
# Copyright (C) 2023- https://github.com/ophub/delete-releases-workflows
# Use api.github.com official documentation
# https://docs.github.com/en/rest/releases/releases?list-releases
# https://docs.github.com/en/rest/actions/workflow-runs?list-workflow-runs-for-a-repository
#
#======================================= Functions list =======================================
#
# error_msg           : Output error message
# init_var            : Initialize all variables
#
# get_releases_list   : Get the release list
# out_releases_list   : Output the release list
# del_releases_file   : Delete releases files
# del_releases_tags   : Delete releases tags
#
# get_workflows_list  : Get the workflows list
# out_workflows_list  : Output the workflows list
# del_workflows_runs  : Delete workflows runs
#
#=============================== Set make environment variables ===============================
#
# Set default value
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

# Set font color
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
    echo -e "${STEPS} Start Initializing Variables..."

    # Install the necessary dependent packages
    sudo apt-get -qq update && sudo apt-get -qq install -y jq curl

    # If it is followed by [ : ], it means that the option requires a parameter value
    local options="r:a:t:p:l:w:s:d:k:o:g:"
    parsed_args=$(getopt -o "${options}" -- "${@}")
    [[ ${?} -ne 0 ]] && error_msg "Parameter parsing failed."
    eval set -- "${parsed_args}"

    while true; do
        case "${1}" in
        -r | --repo)
            if [[ -n "${2}" ]]; then
                repo="${2}"
                shift 2
            else
                error_msg "Invalid -r parameter [ ${2} ]!"
            fi
            ;;
        -a | --delete_releases)
            if [[ -n "${2}" ]]; then
                delete_releases="${2}"
                shift 2
            else
                error_msg "Invalid -a parameter [ ${2} ]!"
            fi
            ;;
        -t | --delete_tags)
            if [[ -n "${2}" ]]; then
                delete_tags="${2}"
                shift 2
            else
                error_msg "Invalid -t parameter [ ${2} ]!"
            fi
            ;;
        -p | --prerelease_option)
            if [[ -n "${2}" ]]; then
                prerelease_option="${2}"
                shift 2
            else
                error_msg "Invalid -p parameter [ ${2} ]!"
            fi
            ;;
        -l | --releases_keep_latest)
            if [[ -n "${2}" ]]; then
                releases_keep_latest="${2}"
                shift 2
            else
                error_msg "Invalid -l parameter [ ${2} ]!"
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
                error_msg "Invalid -w parameter [ ${2} ]!"
            fi
            ;;
        -s | --delete_workflows)
            if [[ -n "${2}" ]]; then
                delete_workflows="${2}"
                shift 2
            else
                error_msg "Invalid -s parameter [ ${2} ]!"
            fi
            ;;
        -d | --workflows_keep_day)
            if [[ -n "${2}" ]]; then
                workflows_keep_day="${2}"
                shift 2
            else
                error_msg "Invalid -d parameter [ ${2} ]!"
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
                error_msg "Invalid -k parameter [ ${2} ]!"
            fi
            ;;
        -o | --out_log)
            if [[ -n "${2}" ]]; then
                out_log="${2}"
                shift 2
            else
                error_msg "Invalid -o parameter [ ${2} ]!"
            fi
            ;;
        -g | --gh_token)
            if [[ -n "${2}" ]]; then
                gh_token="${2}"
                shift 2
            else
                error_msg "Invalid -g parameter [ ${2} ]!"
            fi
            ;;
        --)
            shift
            break
            ;;
        *)
            [[ -n "${1}" ]] && error_msg "Invalid option [ ${1} ]!"
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
    echo -e "${STEPS} Start querying the releases list..."

    # Set github API default page
    github_page="1"

    # Create a file to store the results
    all_releases_list="josn_api_releases"
    echo "" >${all_releases_list}

    # Get the release list
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
            echo -e "${INFO} (1.1.${github_page}) Query the [ ${github_page}th ] page and return [ ${get_results_length} ] results."

            # Sort the results
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
            echo -e "${NOTE} (1.2.1) Reach the maximum page number (${github_max_page}) in the query. skip."
            break
        else
            github_page="$((github_page + 1))"
        fi
    done

    if [[ -s "${all_releases_list}" ]]; then
        # Remove empty lines
        sed -i '/^[[:space:]]*$/d' "${all_releases_list}"

        # Print the result log
        echo -e "${INFO} (1.3.1) The api.github.com for releases request successfully."
        [[ "${out_log}" =~ ^(true|yes)$ ]] && {
            echo -e "${INFO} (1.3.2) Count of releases list: [ $(cat ${all_releases_list} | wc -l) ]"
            echo -e "${INFO} (1.3.3) All releases list:\n$(cat ${all_releases_list})"
        }
    else
        echo -e "${NOTE} (1.3.4) The releases list is empty. skip."
    fi
}

out_releases_list() {
    echo -e "${STEPS} Start outputting the releases list..."

    if [[ -s "${all_releases_list}" ]]; then
        # Filter based on the prerelease option(all/false/true)
        if [[ "${prerelease_option}" == "all" ]]; then
            echo -e "${NOTE} (1.4.1) Do not filter the prerelease option. skip."
        elif [[ "${prerelease_option}" =~ ^(false|no)$ ]]; then
            echo -e "${INFO} (1.4.2) Filter the prerelease option: [ false ]"
            cat ${all_releases_list} | jq -r '.prerelease' | grep -w "true" | while read line; do sed -i "/${line}/d" ${all_releases_list}; done
        elif [[ "${prerelease_option}" =~ ^(true|yes)$ ]]; then
            echo -e "${INFO} (1.4.3) Filter the prerelease option: [ true ]"
            cat ${all_releases_list} | jq -r '.prerelease' | grep -w "false" | while read line; do sed -i "/${line}/d" ${all_releases_list}; done
        else
            error_msg "Invalid prerelease option [ ${prerelease_option} ]!"
        fi
        [[ "${out_log}" =~ ^(true|yes)$ ]] && echo -e "${INFO} (1.4.4) Current releases list:\n$(cat ${all_releases_list})"
    else
        echo -e "${NOTE} (1.4.5) The releases list is empty. skip."
    fi

    # Match tags that need to be filtered
    keep_releases_keyword_list="josn_keep_releases_keyword_list"
    if [[ "${#releases_keep_keyword[@]}" -ge "1" && -s "${all_releases_list}" ]]; then
        # Match tags that meet the criteria
        echo -e "${INFO} (1.5.1) Filter tags keywords: [ $(echo ${releases_keep_keyword[@]} | xargs) ]"
        for ((i = 0; i < ${#releases_keep_keyword[@]}; i++)); do
            cat ${all_releases_list} | jq -r .tag_name | grep -E "${releases_keep_keyword[$i]}" >>${keep_releases_keyword_list}
        done
        [[ "${out_log}" =~ ^(true|yes)$ && -s "${keep_releases_keyword_list}" ]] && {
            echo -e "${INFO} (1.5.2) List of tags that meet the criteria:\n$(cat ${keep_releases_keyword_list})"
        }

        # Remove the tags that need to be kept
        [[ -s "${keep_releases_keyword_list}" ]] && {
            cat ${keep_releases_keyword_list} | while read line; do sed -i "/${line}/d" ${all_releases_list}; done
            echo -e "${INFO} (1.5.3) The tags keywords filtering successfully."
        }

        # List of remaining tags after filtering.
        [[ "${out_log}" =~ ^(true|yes)$ ]] && echo -e "${INFO} (1.5.4) Current releases list:\n$(cat ${all_releases_list})"
    else
        echo -e "${NOTE} (1.5.5) The filter keyword is empty. skip."
    fi

    # Match the latest tags that need to be kept
    keep_releases_list="josn_keep_releases_list"
    if [[ -s "${all_releases_list}" ]]; then
        if [[ "${releases_keep_latest}" -eq "0" ]]; then
            echo -e "${INFO} (1.6.1) Delete all releases."
        else
            # Generate a list of tags that need to be kept
            cat ${all_releases_list} | head -n ${releases_keep_latest} >${keep_releases_list}
            echo -e "${INFO} (1.6.2) The keep tags list is generated successfully."
            [[ "${out_log}" =~ ^(true|yes)$ && -s "${keep_releases_list}" ]] && {
                echo -e "${INFO} (1.6.3) The keep tags list:\n$(cat ${keep_releases_list})"
            }

            # Remove releases that need to be kept from the full list
            sed -i "1,${releases_keep_latest}d" ${all_releases_list}
        fi
    else
        echo -e "${NOTE} (1.6.4) The releases list is empty. skip."
    fi

    # Delete list
    if [[ -s "${all_releases_list}" ]]; then
        [[ "${out_log}" =~ ^(true|yes)$ ]] && echo -e "${INFO} (1.6.5) Delete releases list:\n$(cat ${all_releases_list})"
    else
        echo -e "${NOTE} (1.6.6) The delete releases list is empty. skip."
    fi

    echo -e ""
}

del_releases_file() {
    echo -e "${STEPS} Start deleting releases files..."

    # Delete releases
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
        echo -e "${NOTE} (1.7.2) No releases need to be deleted. skip."
    fi

    echo -e ""
}

del_releases_tags() {
    echo -e "${STEPS} Start deleting tags..."

    # Delete the tags associated with releases
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
        echo -e "${NOTE} (1.8.2) No tags need to be deleted. skip."
    fi

    echo -e ""
}

get_workflows_list() {
    echo -e "${STEPS} Start querying the workflows list..."

    # Set github API default page
    github_page="1"

    # Create a file to store the results
    all_workflows_list="josn_api_workflows"
    echo "" >${all_workflows_list}

    # Get the workflows list
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
            echo -e "(2.1.${github_page}) ${INFO} Query the [ ${github_page}th ] page and return [ ${get_results_length} ] results."

            # Sort the results
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
            echo -e "${NOTE} (2.2.1) Reach the maximum page number (${github_max_page}) in the query. skip."
            break
        else
            github_page="$((github_page + 1))"
        fi
    done

    if [[ -s "${all_workflows_list}" ]]; then
        # Remove empty lines
        sed -i '/^[[:space:]]*$/d' "${all_workflows_list}"

        # Print the result log
        echo -e "${INFO} (2.3.1) The api.github.com for workflows request successfully."
        [[ "${out_log}" =~ ^(true|yes)$ ]] && {
            echo -e "${INFO} (2.3.2) Count of workflow runs: [ $(cat ${all_workflows_list} | wc -l) ]"
            echo -e "${INFO} (2.3.3) All workflows runs list:\n$(cat ${all_workflows_list})"
        }
    else
        echo -e "${NOTE} (2.3.4) The workflows list is empty. skip."
    fi
}

out_workflows_list() {
    echo -e "${STEPS} Start outputting the workflows list..."

    # The workflows containing keywords that need to be keep
    keep_keyword_workflows_list="josn_keep_keyword_workflows_list"
    # Remove workflows that match keywords and need to be kept
    if [[ "${#workflows_keep_keyword[@]}" -ge "1" && -s "${all_workflows_list}" ]]; then
        # Match the list of workflows that meet the keywords
        echo -e "${INFO} (2.4.1) Filter Workflows runs keywords: [ $(echo ${workflows_keep_keyword[@]} | xargs) ]"
        for ((i = 0; i < ${#workflows_keep_keyword[@]}; i++)); do
            cat ${all_workflows_list} | jq -r .name | grep -E "${workflows_keep_keyword[$i]}" >>${keep_keyword_workflows_list}
        done
        [[ "${out_log}" =~ ^(true|yes)$ && -s "${keep_keyword_workflows_list}" ]] && {
            echo -e "${INFO} (2.4.2) List of Workflows runs that meet the criteria:\n$(cat ${keep_keyword_workflows_list})"
        }

        # Remove the workflows that need to be kept
        [[ -s "${keep_keyword_workflows_list}" ]] && {
            cat ${keep_keyword_workflows_list} | while read line; do sed -i "/${line}/d" ${all_workflows_list}; done
            echo -e "${INFO} (2.4.3) The keyword filtering successfully."
        }

        # List of remaining workflows after filtering by keywords
        [[ "${out_log}" =~ ^(true|yes)$ ]] && echo -e "${INFO} (2.4.4) Current workflows runs list:\n$(cat ${all_workflows_list})"
    else
        echo -e "${NOTE} (2.4.5) The filter keyword is empty. skip."
    fi

    # Generate a date list of workflows
    all_workflows_date_list="josn_all_workflows_date_list"
    # Generate a keep list of workflows
    keep_workflows_list="josn_keep_workflows_list"
    # Temporary josn file
    tmp_josn_file="$(mktemp)"
    # Sort and generate a keep list of workflows
    if [[ -s "${all_workflows_list}" ]]; then
        if [[ "${workflows_keep_day}" -eq "0" ]]; then
            echo -e "${INFO} (2.5.1) Delete all workflows runs."
        else
            # Remove workflows that meet the retention time
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
            echo -e "${INFO} (2.5.2) The keep workflows runs list is generated successfully."

            # Remove duplicate lines
            [[ -s "${keep_workflows_list}" ]] && {
                awk '!a[$0]++' ${keep_workflows_list} >${tmp_josn_file} && mv -f ${tmp_josn_file} ${keep_workflows_list}
                [[ "${out_log}" =~ ^(true|yes)$ ]] && echo -e "${INFO} (2.5.3) Keep workflows list:\n$(cat ${keep_workflows_list})"
            }
        fi
    else
        echo -e "${NOTE} (2.5.4) The workflows runs list is empty. skip."
    fi

    # Delete list
    if [[ -s "${all_workflows_list}" ]]; then
        [[ "${out_log}" =~ ^(true|yes)$ ]] && echo -e "${INFO} (2.5.5) Delete workflows list:\n$(cat ${all_workflows_list})"
    else
        echo -e "${NOTE} (2.5.6) The delete workflows list is empty. skip."
    fi

    echo -e ""
}

del_workflows_runs() {
    echo -e "${STEPS} Start deleting workflows runs..."

    # Delete workflows runs
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
        echo -e "${SUCCESS} (2.6.1) Workflows runs deleted successfully."
    else
        echo -e "${NOTE} (2.6.2) No Workflows runs need to be deleted. skip."
    fi

    echo -e ""
}

# Show welcome message
echo -e "${STEPS} Welcome to use the delete older releases and workflow runs tool!"

# Perform related operations in sequence
init_var "${@}"

# Delete release
if [[ "${delete_releases}" =~ ^(true|yes)$ ]]; then
    get_releases_list
    out_releases_list
    del_releases_file
    del_releases_tags
else
    echo -e "${STEPS} Do not delete releases and tags."
fi

# Delete workflows
if [[ "${delete_workflows}" =~ ^(true|yes)$ ]]; then
    get_workflows_list
    out_workflows_list
    del_workflows_runs
else
    echo -e "${STEPS} Do not delete workflows."
fi

# Show all process completion prompts
echo -e "${SUCCESS} All process completed successfully."
