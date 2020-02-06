# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

BRANCH="update-modules"

pushd $TRAVIS_BUILD_DIR

#debug
pwd
ls

# remove any update-modules branch
git branch -D "${BRANCH}" 2>/dev/null

git remote add upstream https://github.com/apache/mynewt-mcumgr-cli
[[ $? -ne 0 ]] && exit 1

git fetch upstream
[[ $? -ne 0 ]] && exit 1

# must be running on master to find modules that were updated!
git reset --hard upstream/master

is_mod=0
modules=()
while read line; do
    if [[ "${line}" == "require (" ]]; then
        is_mod=1
    elif [[ $is_mod -eq 1 && "${line}" == ")" ]]; then
        is_mod=0
        break
    elif [[ $is_mod -eq 1 ]]; then
        module="$(echo ${line} | cut -d' ' -f1)"
        modules[${#modules[*]}]=$module
    fi
done <go.mod

pushd mcumgr
for module in ${modules[*]}; do
    go get -v -u $module
done
popd

git diff --quiet
if [[ $? -eq 0 ]]; then
    echo "No changes detected."
    exit 0
fi

# Check that still builds...
pushd mcumgr
go build -v
[[ $? -ne 0 ]] && exit 1
popd

git checkout -b "${BRANCH}"
[[ $? -ne 0 ]] && exit 1

git commit -m "Update dependencies (automated)" go.mod go.sum

# Add new repo that has a valid write permission token
git remote add writable https://${GH_TOKEN}@github.com/apache-mynewt-bot/mynewt-mcumgr-cli.git
git push writable ${BRANCH} --force
[[ $? -ne 0 ]] && exit 1

# Create PR through GH API
curl -H "Content-Type: application/json" \
     -H "Authorization: token ${GH_TOKEN}" \
     --data '{"title":"Update dependencies","body":"New dependencies found!","head":"apache-mynewt-bot:update-modules","base":"master"}' \
     https://api.github.com/repos/apache/mynewt-mcumgr-cli/pulls
