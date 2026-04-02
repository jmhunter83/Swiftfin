#!/bin/bash
set -e

brew install carthage swiftformat swiftgen

carthage update --use-xcframeworks --cache-builds
