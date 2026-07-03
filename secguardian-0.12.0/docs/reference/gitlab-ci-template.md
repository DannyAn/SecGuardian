# .gitlab-ci.yml — SecGuardian Security Scan
# GitLab SAST-compatible pipeline with SARIF output

stages:
  - security

variables:
  SECGUARDIAN_OUTPUT_DIR: ".codeagent"

secguardian-scan:
  stage: security
  image: ubuntu:22.04
  before_script:
    - apt-get update -qq && apt-get install -y -qq jq go golang 2>/dev/null || true
    - if command -v go &>/dev/null; then
        cd internal && go build -o ../scripts/secguardian-index . && cd ..;
      fi
  script:
    - bash scripts/secguardian.sh scan --path src/ --sarif
    - SCAN_DIR="$SECGUARDIAN_OUTPUT_DIR/secguard-secguardian/scans/latest"
    - EXIT=$(jq -r '.exit_code' "$SCAN_DIR/status.json" 2>/dev/null || echo "2")
    - echo "Security scan complete (exit: $EXIT)"
    - cat "$SCAN_DIR/manifest.json" | jq '{score, findings: .summary.findings}'
  artifacts:
    paths:
      - .codeagent/
    reports:
      sast: .codeagent/secguard-secguardian/scans/latest/results.sarif
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH == "main" || $CI_COMMIT_BRANCH == "develop"'
