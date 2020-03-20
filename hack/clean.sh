#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

ROOT=$(dirname "${BASH_SOURCE[0]}")/..

. "${ROOT}/hack/lib/init.sh"

salzr::golang::clean

