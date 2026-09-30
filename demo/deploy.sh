#!/usr/bin/env bash
# Update the server to the latest commit on GitHub and rebuild what changed.
#
#   sudo demo/deploy.sh             pull, rebuild, then follow the first pipeline run
#   sudo demo/deploy.sh --check     only show what would be deployed
#   sudo demo/deploy.sh --no-follow deploy, but don't wait for the pipeline run
#
# Run it on the server, as root or as a user in the docker group. Git commands run as
# the owner of the checkout, so root never leaves root-owned files in the repo (and
# git's "dubious ownership" check never trips). It refuses to deploy over local
# changes, waits while a pipeline run is in progress, and only restarts containers
# whose image or configuration changed.
#
# Settings (environment): DEPLOY_BRANCH (main), WAIT_MAX (2700 s), WAIT_INTERVAL (30 s),
# FOLLOW_TIMEOUT (60m).
set -Eeuo pipefail   # -E: the ERR trap below also fires inside functions

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRANCH="${DEPLOY_BRANCH:-main}"
WAIT_MAX="${WAIT_MAX:-2700}"
WAIT_INTERVAL="${WAIT_INTERVAL:-30}"
FOLLOW_TIMEOUT="${FOLLOW_TIMEOUT:-60m}"
CONTAINER=railway-pipeline
SITE_INFO=https://railway.tonikiuru.com/build-info.json

CHECK=0
FOLLOW=1
for arg in "$@"; do
    case "$arg" in
        --check) CHECK=1 ;;
        --no-follow) FOLLOW=0 ;;
        -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option: $arg (see --help)" >&2; exit 2 ;;
    esac
done

log() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

# Run git as the owner of the checkout.
OWNER="$(stat -c %U "$REPO")"
OWNER_HOME="$(getent passwd "$OWNER" | cut -d: -f6)"
git_() {
    if [ "$(id -un)" = "$OWNER" ]; then
        git -C "$REPO" "$@"
    elif [ "$(id -u)" -eq 0 ]; then
        runuser -u "$OWNER" -- env HOME="$OWNER_HOME" git -C "$REPO" "$@"
    else
        die "Run this as root (sudo) or as $OWNER, the owner of $REPO."
    fi
}
compose() { docker compose -f "$REPO/docker-compose.demo.yml" "$@"; }

cd "$REPO"
docker info >/dev/null 2>&1 \
    || die "Docker is not reachable. Run as root (sudo) or as a user in the docker group."
[ -d "$REPO/.git" ] || die "$REPO is not a git checkout."

# Only deploy a clean checkout of the deploy branch.
current="$(git_ rev-parse --abbrev-ref HEAD)"
[ "$current" = "$BRANCH" ] || die "The checkout is on '$current', not '$BRANCH'."
if [ -n "$(git_ status --porcelain --untracked-files=no)" ]; then
    git_ status --short --untracked-files=no
    die "The checkout has local changes (listed above). Make changes in the repo and push them, then deploy; or revert them with 'git checkout -- <file>' as $OWNER."
fi

log "Fetching origin/$BRANCH"
git_ fetch --quiet origin "$BRANCH"
OLD="$(git_ rev-parse HEAD)"
NEW="$(git_ rev-parse "origin/$BRANCH")"
if [ "$OLD" = "$NEW" ]; then
    log "Already up to date: $(git_ log -1 --format='%h %s')"
    exit 0
fi
git_ merge-base --is-ancestor "$OLD" "$NEW" \
    || die "Local $BRANCH has commits that are not on origin/$BRANCH. Sort it out by hand."

log "Incoming commits"
git_ log --oneline "$OLD..$NEW"
CHANGED="$(git_ diff --name-only "$OLD" "$NEW")"
echo
echo "Files changed:"
echo "$CHANGED" | sed 's/^/  /'
if [ "$CHECK" -eq 1 ]; then
    log "Check only: nothing was changed."
    exit 0
fi

# Don't restart the pipeline in the middle of a run. flock exits 75 while the lock is
# held; any other failure (container not running) means there is nothing to wait for.
waited=0
while :; do
    rc=0
    docker exec "$CONTAINER" flock -n -E 75 /tmp/pipeline.lock true >/dev/null 2>&1 || rc=$?
    [ "$rc" -eq 75 ] || break
    [ "$waited" -lt "$WAIT_MAX" ] \
        || die "A pipeline run is still going after $((WAIT_MAX / 60)) min. Nothing was changed; try again later."
    [ "$waited" -eq 0 ] && log "A pipeline run is in progress; waiting for it to finish"
    sleep "$WAIT_INTERVAL"
    waited=$((waited + WAIT_INTERVAL))
done

log "Updating the checkout to $(git_ log -1 --format='%h' "$NEW")"
git_ merge --ff-only --quiet "$NEW"
trap 'echo "Deploy failed after the checkout was updated to ${NEW:0:7}. To go back: runuser -u $OWNER -- git -C $REPO reset --hard ${OLD:0:7}, then run docker compose -f docker-compose.demo.yml up -d --build" >&2' ERR

SINCE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
log "Rebuilding and restarting what changed"
compose up -d --build
if printf '%s\n' "$CHANGED" | grep -qx 'demo/nginx.conf'; then
    log "demo/nginx.conf changed: recreating the web container"
    compose up -d --force-recreate web
fi

log "Removing old images and build cache"
docker image prune -f | tail -n 1
docker builder prune -f | tail -n 1
trap - ERR

echo
echo "Deployed $(git_ log -1 --format='%h %s')."
echo "Previous version: ${OLD:0:7}. To go back: runuser -u $OWNER -- git -C $REPO reset --hard ${OLD:0:7}, then run 'docker compose -f docker-compose.demo.yml up -d --build'."

# The pipeline runs once whenever its container starts. If the image did not change,
# the container was not restarted and there is no run to follow.
started="$(docker inspect -f '{{.State.StartedAt}}' "$CONTAINER" 2>/dev/null || echo)"
if [ -z "$started" ] || [[ "${started:0:19}" < "${SINCE:0:19}" ]]; then
    log "The pipeline container was not restarted (its image did not change)."
    exit 0
fi
if [ "$FOLLOW" -eq 0 ]; then
    log "The pipeline run has started; follow it with: docker logs -f $CONTAINER"
    exit 0
fi

log "Following the first pipeline run (Ctrl+C stops following; the run carries on)"
# Read the log line by line and stop following at the scheduler's verdict. After it the
# log goes quiet until the next day, so a plain pipe would never notice that we left.
result=""
exec 3< <(timeout "$FOLLOW_TIMEOUT" docker logs -f --since "$SINCE" "$CONTAINER" 2>&1)
follower=$!
while IFS= read -r line <&3; do
    printf '%s\n' "$line"
    if [[ "$line" == "[scheduler] Pipeline "* ]]; then
        result="$line"
        break
    fi
done
kill "$follower" 2>/dev/null || true
exec 3<&-
case "$result" in
    *succeeded*)
        log "Pipeline run succeeded."
        if command -v curl >/dev/null; then
            echo "Site build info: $(curl -fsS --max-time 20 "$SITE_INFO" || echo 'not reachable yet')"
        fi
        ;;
    "")
        die "No result within $FOLLOW_TIMEOUT. Check: docker logs --tail 80 $CONTAINER" ;;
    *)
        die "Pipeline run did not succeed: $result See docs/OPERATIONS.md, Troubleshooting." ;;
esac
