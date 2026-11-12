# shellcheck shell=bash disable=SC2034
# Sourced by the release scripts: the game's name, its name in file names, and the label its files carry.
GAME_NAME="Mosaicus Maximus"
SLUG="${GAME_NAME// /-}"
if [ "${GITHUB_REF_TYPE:-}" = tag ]; then
  LABEL="$GITHUB_REF_NAME"
else
  LABEL="dev-$(git rev-parse --short=7 HEAD)"
fi
