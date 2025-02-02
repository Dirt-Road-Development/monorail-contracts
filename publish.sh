#!/bin/bash

set -e

echo "Preparing Publishable Package"

npm version minor

version=$(npm pkg get version)

git checkout -b deployments/$version

gh pr create

npm publish deployments