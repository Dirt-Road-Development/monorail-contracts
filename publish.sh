#!/bin/bash

set -e

echo "Preparing Publishable Package"

cd deployments

npm version minor

version=$(npm pkg get version | sed 's/"//g')

npm publish --access public

cd ../

git add .
git commit -am "Publish Version $version"