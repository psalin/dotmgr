#!/bin/bash

set -euo pipefail

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONFIG="dotfiles.conf"

DOTMGR_DIR=".dotmgr"
DOTMGR_BIN="dotmgr.sh"

cd "${BASEDIR}"
"${BASEDIR}/${DOTMGR_DIR}/${DOTMGR_BIN}" --conffile "${CONFIG}" "${@}"
