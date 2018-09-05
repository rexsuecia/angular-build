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
  LOW_CACHE="index.html *.json *.js"

  # Wy do I disable globing?

  set -f
  echo "Uploading HIGH_CACHE to S3"
  for INCLUDE in ${HIGH_CACHE}; do
    echo ${INCLUDE}
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

  aws s3 sync dist/ s3://www."${TARGET}"."${DOMAIN}"/ --quiet
}
