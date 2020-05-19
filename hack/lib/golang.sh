#!/usr/bin/env bash

salzr::golang::lambda_targets() {
  local targets=(
    aws/lambda/cmd/spotfleetrequestcontrol
    aws/lambda/cmd/s3eventcertronhandler
  )
  echo "${targets[@]}"
}

IFS=" " read -ra TARGETS <<<"$(salzr::golang::lambda_targets)"
readonly TARGETS

salzr::golang::build() {
  export GOOS="linux"
  for pkg in "${TARGETS[@]}"; do
    local project="${pkg##*/}"
    local project_path="${OUTPUT}/bin/${project}"
    go build -mod=vendor -o "${project_path}/main" "${pkg}/main.go"
    chmod +x "${project_path}/main"
    salzr::golang::generate_artifacts "${project_path}" "${project}"
  done
}

salzr::golang::generate_artifacts() {
  local project_path=$1
  local project=$2
  local artifacts_path="${OUTPUT}/artifacts"
  local artifact="${project}.zip"

  mkdir -p "$artifacts_path"

  pushd "${project_path}" || exit 1
    zip "${artifact}" "main"
  popd || exit 1

  mv "${project_path}/${artifact}" "${artifacts_path}"
}

salzr::golang::clean() {
  rm -rf "${OUTPUT:?}/bin"
}
