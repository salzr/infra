#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

OUTPUT_SUBPATH="${OUTPUT_SUBPATH:-build/_output}"
OUTPUT="${ROOT}/${OUTPUT_SUBPATH}"

. "${ROOT}/hack/lib/golang.sh"
