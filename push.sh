#!/bin/bash
# Push script — run with: GITHUB_TOKEN=<token> sh push.sh
set -e
cd /home/runner/workspace/coopvest
git push "https://${GITHUB_TOKEN}@github.com/coopvestafrica-ops/Latest-Coopvest.git" main
echo "DONE"
