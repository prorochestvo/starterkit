#!/usr/bin/env bash
# Print approved skill-incubator trial triggers at session start.
command -v incubator >/dev/null 2>&1 || exit 0
incubator triggers || exit 0
