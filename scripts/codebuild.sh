#!/bin/bash -e

function create_version_file {

    CODEBUILD_BUILD_ID=${CODEBUILD_BUILD_ID}
    CURRENT_COMMIT=$(git rev-parse HEAD)
    CURRENT_BUILD_DATE=$(date --iso-8601=seconds)

    CURRENT_VERSION=$(jq .version ./package.json | tr -d \")

    GIT_BRANCH=$(git branch -a --contains HEAD | sed -n 2p | awk '{ printf $1 }')
    GIT_BRANCH=${GIT_BRANCH#remotes/origin/}

    cat <<EOF > ./src/assets/version.json
{
  "version" : "${CURRENT_VERSION}",
  "commit" : "${CURRENT_COMMIT:0:10}",
  "branch" : "${GIT_BRANCH}",
  "build" : "${CODEBUILD_BUILD_ID}",
  "time" : "${CURRENT_BUILD_DATE}"
}
EOF
    cat ./src/assets/version.json
}

function export_build_info {

    CODEBUILD_SOURCE_VERSION=${CODEBUILD_SOURCE_VERSION}

    GIT_BRANCH=$(git branch -a --contains HEAD | sed -n 2p | awk '{ printf $1 }')
    GIT_BRANCH=${GIT_BRANCH#remotes/origin/}

    PR_BUILD=false
    PR_NUMBER=${CODEBUILD_SOURCE_VERSION}
    CODEBUILD_SOURCE_VERSION=${CODEBUILD_SOURCE_VERSION}

    if [[ "${CODEBUILD_SOURCE_VERSION}" =~ ^pr/[0-9]*$ ]]; then
        PR_BUILD=true
        PR_NUMBER=$(echo "${PR_NUMBER}" | tr "/"  "-")
        PR_NUMBER=${PR_NUMBER^^}
    fi

    TAG="develop"

    if [ ${PR_BUILD} = true ]; then
        TAG=${PR_NUMBER}
    elif [[ "${GIT_BRANCH}" =~ ^release_v[0-9] ]]; then
        TAG="${GIT_BRANCH#release_}"
    fi

    BUILD_ID=$(git rev-parse HEAD)
    BUILD_ID=${BUILD_ID:0:10}

    export PR_BUILD
    export PR_NUMBER
    export GIT_BRANCH
    export BUILD_ID
    export TAG
}

function upload_to_s3 {

  TARGET="${1}"
  DOMAIN="${DOMAIN}" # NB This has to be exported from somewhere (example.com)

  HIGH_CACHE="*.bundle.css *.bundle.js"
  MEDIUM_CACHE="*.png *.svg *.gif *.mp3"
  LOW_CACHE="index.html"
  JSON="*.json"
  JAVASCRIPT="*.js"

  # Wy do I disable globing?

  set -f
  echo "Uploading HIGH_CACHE to S3"
  for INCLUDE in ${HIGH_CACHE}; do
    echo "${INCLUDE}"
    aws s3 sync dist/ s3://www."${TARGET}"."${DOMAIN}"/ \
      --exclude "*" \
      --include "${INCLUDE}" \
      --cache-control="public,max-age=31536000" \
      --quiet

  done

  echo "Uploading MEDIUM_CACHE to S3"
  for INCLUDE in ${MEDIUM_CACHE}; do
    aws s3 sync dist/ s3://www."${TARGET}"."${DOMAIN}"/ \
      --exclude "*" \
      --include "$INCLUDE" \
      --cache-control="public,max-age=86400" \
      --quiet
  done
  echo "Uploading LOW_CACHE to S3"
  for INCLUDE in ${LOW_CACHE}; do
    aws s3 sync dist/ s3://www."${TARGET}"."${DOMAIN}"/ \
      --exclude "*" \
      --include "$INCLUDE" \
      --cache-control="public,max-age=3600" \
      --quiet
  done

  echo "Uploading JaVaScRiPt to S3"
  for INCLUDE in ${JAVASCRIPT}; do
    aws s3 sync dist/ s3://www."${TARGET}".aiten.com/ \
      --exclude "*" \
      --include "$INCLUDE" \
      --content-type="text/javascript" \
      --cache-control="public,max-age=3600" \
      --quiet
  done

  echo "Uploading JSON to S3"
  for INCLUDE in ${JSON}; do
    aws s3 sync dist/ s3://www."${TARGET}".aiten.com/ \
      --exclude "*" \
      --include "$INCLUDE" \
      --content-type="application/json" \
      --cache-control="public,max-age=3600" \
      --quiet
  done

  aws s3 sync dist/ s3://www."${TARGET}"."${DOMAIN}"/ --quiet
}

function switch_role {

    # The role to assume typically, arn:aws:iam::123456789012:role/SOME_ROLE_NAME
    ROLE="${1}"

    CREDS=$(aws sts assume-role \
        --role-arn "${ROLE}" \
        --role-session-name Temprole --region eu-west-1 --output text \
        --query 'Credentials.[AccessKeyId, SecretAccessKey, SessionToken]'
    )

    # shellcheck disable=SC2086
    AWS_ACCESS_KEY_ID=$(echo ${CREDS} | awk '{print $1}')
    # shellcheck disable=SC2086
    AWS_SECRET_ACCESS_KEY=$(echo ${CREDS} | awk '{print $2}')
    # shellcheck disable=SC2086
    AWS_SESSION_TOKEN=$(echo ${CREDS} | awk '{print $3}')


    # Must be exported so that aws cli can get them
    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    export AWS_SESSION_TOKEN
}

function run_sonar {
    # $1 the role to assume to get the secrets
    # $2 the secret key e.g. accomplish/sonarcloud
    SONAR_OPTIONS=${SONAR_OPTIONS} # Externally set -Dsonar.x=y -Dsonar.a=b options
    switch_role "${1}"
    SONAR_SECRET=$(aws secretsmanager get-secret-value --secret-id "${2}" --query SecretString --output text)
    sonar-scanner -Dsonar.login="${SONAR_SECRET}" "${SONAR_OPTIONS}"
}

#
# Copies the 3rd party licence extracted file to assets.
#
function thirdPartyCopy {
  if [[ -e "./dist/3rdpartylicenses.txt" ]]; then
    echo "copying"
    cp ./dist/3rdpartylicenses.txt ./dist/assets/
  fi
}

function validate_bash {
    # find shell scripts that are not generated by terraform and that are not in vendor etc
    files=$(find . -name '*.sh' -not -path "*.terraform*" \
                                -not -path "*vendor*" \
                                -not -path "*node_modules*" \
                                -not -path "*bower_components*" \
                                -not -path "*.cache*" )

    # loop through each file
    for file in ${files};
    do
        # -x to follow any included files
        # SC2155 - avoid masking return values.
        printf "Validating file: %s"... "$file"
        shellcheck -x -e SC2155 "$file";
        echo "OK"
    done
}

function validate_terraform {
    find "./$1" -name "*.tf" -exec terraform fmt -check {} \;
}