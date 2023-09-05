#!/usr/bin/env bash

# Copyright 2023 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# The local git repo must have a remote "upstream" pointing
# to upstream sigstore/rekor, and a remote "origin"
# pointing to securesign/rekor

# Synchs the release-next branch to either the upstream `main` branch
# or a provided git-ref (typically an upstream release tag) and then triggers CI.
#
# NOTE: This requires a corresponding midstream branch to exist in the securesign fork
#       with the same name as the upstream branch/ref, but prefixed with "midstream-".
#
# Usage: update-to-head.sh [<git-ref>]

if [ "$#" -ne 1 ]; then
    upstream_ref="main"
    midstream_ref="main"
else
    upstream_ref=$1
    midstream_ref="midstream-${upstream_ref}"
    redhat_ref="redhat-${upstream_ref}"
fi

echo "Synchronizing release-next to upstream/${upstream_ref}..."

set -e
REPO_NAME=$(basename $(git rev-parse --show-toplevel))

# Custom files
custom_files=$(cat <<EOT | tr '\n' ' '
redhat
OWNERS
EOT
)
redhat_files_msg=":open_file_folder: update Red Hat specific files"
robot_trigger_msg=":robot: triggering CI on branch 'release-next' after synching from upstream/${upstream_ref}"

# Reset release-next to upstream main or <git-ref>.
git fetch upstream $upstream_ref
if [[ "$upstream_ref" == "main" ]]; then
  git checkout upstream/main -B release-next
else
  git checkout $upstream_ref -B release-next
fi

# Update redhat's main and take all needed files from there.
git fetch origin $midstream_ref
git checkout origin/$midstream_ref $custom_files

# Apply midstream patches
if [[ -d redhat/patches ]]; then
  git apply redhat/patches/*
fi

# Move .tekton files to root
if [[ -d redhat/.tekton ]]; then
  git mv redhat/.tekton .
fi

# Move overlays to root
if [[ -d redhat/overlays ]]; then
  git mv redhat/overlays .
fi

git add . # Adds applied patches
git add $custom_files # Adds custom files
git commit -m "${redhat_files_msg}"

# Push the release-next branch
git push -f origin release-next

# Copy and push the release-next branch to $redhat_ref we're not working with main
if [[ "$redhat_ref" != "" ]]; then
  git push -f origin release-next:$redhat_ref
fi

# Trigger CI
# TODO: Set up openshift or github CI to run on release-next-ci
git checkout release-next -B release-next-ci
date > ci
git add ci
git commit -m "${robot_trigger_msg}"
git push -f origin release-next-ci

if hash hub 2>/dev/null; then
   # Test if there is already a sync PR in
   COUNT=$(hub api -H "Accept: application/vnd.github.v3+json" repos/securesign/${REPO_NAME}/pulls --flat \
    | grep -c "${robot_trigger_msg}") || true
   if [ "$COUNT" = "0" ]; then
      hub pull-request --no-edit -l "kind/sync-fork-to-upstream" -b securesign/${REPO_NAME}:release-next -h securesign/${REPO_NAME}:release-next-ci -m "${robot_trigger_msg}"
   fi
else
   echo "hub (https://github.com/github/hub) is not installed, so you'll need to create a PR manually."
fi
