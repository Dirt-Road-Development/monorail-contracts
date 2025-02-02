#!/bin/bash

set -e

echo "Preparing Publishable Package"

npm version minor

git push

npm publish deployments