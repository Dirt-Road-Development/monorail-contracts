#!/bin/bash

set -e

echo "Preparing Publishable Package"

cd deployments

npm version minor

npm publish