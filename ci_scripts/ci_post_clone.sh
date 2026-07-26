#!/bin/bash
set -e

brew install carthage swiftformat swiftgen

carthage update --use-xcframeworks --cache-builds

# Swiftfin 1.5 pulls swift-case-paths, StatefulMacro, Engine and Defaults as
# macro packages. Xcode fingerprints those and refuses to run them until a human
# clicks "Trust & Enable", which a CI runner has no way to do.
#
# UNVERIFIED: this key has not been confirmed against an actual Xcode Cloud run.
# If the build still fails on macro validation, that's the first thing to check.
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
