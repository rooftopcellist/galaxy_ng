#!/usr/bin/env bash


set -o nounset
set -o errexit


readonly GITHUB_PULL_REQUEST="${GITHUB_PULL_REQUEST:-}"
readonly GITHUB_BRANCH="${GITHUB_BRANCH:-}"

readonly MANIFESTS_GIT_USER="${MANIFESTS_GIT_USER:-}"
readonly MANIFESTS_GIT_EMAIL="${MANIFESTS_GIT_EMAIL:-}"
readonly MANIFESTS_GIT_TOKEN="${MANIFESTS_GIT_TOKEN:-}"
readonly MANIFESTS_GIT_URL="https://${MANIFESTS_GIT_USER}:${MANIFESTS_GIT_TOKEN}@github.com/RedHatInsights/manifests.git"

readonly MANIFESTS_DIR='/tmp/manifests'
readonly MANIFEST_FILE="${MANIFESTS_DIR}/automation-hub/automation-hub-api.txt"

readonly PREFIX='services-ansible-automation-hub:api'
readonly DOCKERFILE='Dockerfile'


log_message() {
    echo "$BASH_SOURCE:" "$@" >&2
}

generate_python_manifest() {
    python .github/workflows/scripts/generate_python_manifest.py \
        --requirements requirements/requirements.insights.txt
}

generate_docker_manifest() {
    base_image=$(sed -n -e 's/^FROM //p' "${DOCKERFILE}")
    if [[ "$base_image" != */* ]]; then
        base_image="docker.io/${base_image}"
    fi
    echo "${PREFIX}/Dockerfile-FROM-${base_image}"
}

if [[ "$GITHUB_PULL_REQUEST" != 'false' ]]; then
    log_message 'Ignoring manifest update for pull request.'
    exit 0
fi

if [[ "${GITHUB_BRANCH}" == 'master' || "${GITHUB_BRANCH}" == 'stable' ]]; then
    manifests_branch="${GITHUB_BRANCH}"
else
    log_message "Ignoring manifest update for branch '${GITHUB_BRANCH}'."
    exit 0
fi

git clone --depth=10 --branch="${manifests_branch}" \
    "${MANIFESTS_GIT_URL}" "${MANIFESTS_DIR}" &>/dev/null

mkdir -p "$(dirname "${MANIFEST_FILE}")"

# Generate Docker dependencies
generate_docker_manifest > "${MANIFEST_FILE}"
# Generate python dependencies
generate_python_manifest >> "${MANIFEST_FILE}"

cd "${MANIFESTS_DIR}"
git config user.name "${MANIFESTS_GIT_USER}"
git config user.email "${MANIFESTS_GIT_EMAIL}"

git add "${MANIFEST_FILE}"

if ! git diff-index --quiet HEAD; then
    git commit --message "Update manifest for Automation Hub UI"
    if ! git push origin "${manifests_branch}" &>/dev/null; then
        log_message "Error: git push to branch '${manifests_branch}' failed."
        exit 1
    fi
else
    log_message "Nothing to commit."
fi
