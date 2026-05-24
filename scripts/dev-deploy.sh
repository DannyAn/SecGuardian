#!/bin/bash
# SecGuardian — 一键构建 + 三平台部署
# 等价于 bash scripts/build.sh all
exec bash "$(dirname "$0")/deploy.sh" all