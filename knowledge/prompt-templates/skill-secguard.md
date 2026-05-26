# secguard — AI-guided code vulnerability scan

## Execution Instructions

1. Determine the target language by scanning file extensions:
   - `.c/.cpp/.cc/.h/.hpp` → C/C++ (30 detectors)
   - `.py` → Python (detector set)
   - `.java` → Java (detector set)
   - `.go` → Go (detector set)

2. Load the detector index from `skills/secguard-cpp/references/detector-index.md`
3. Filter detectors by namespace pattern (e.g., `memory.*` → keep memory detectors)
4. Sort matched detectors by severity: Critical → High → Medium
5. For each detector, load `knowledge/detectors/<name>.md` for detection logic
6. Execute each detector's 4-step detection logic against the target scope

## Detection Logic (4 steps)

Each detector has:
- **Step 1**: Search for danger API calls / patterns
- **Step 2**: Analyze the context (arguments, pre-conditions)
- **Step 3**: Apply False Positive exclusion rules
- **Step 4**: If confirmed, generate a finding with CWE/CVSS

## Git Diff Mode

In `git diff` mode:
1. Parse the git diff output to find changed files and line ranges
2. Only analyze `+` (new/modified) lines
3. Each finding MUST include `diff_status` with `in_diff`, `diff_line`, and `is_new_code`

## Output Format

Write findings to `findings/<id>.json` using the schema from the system prompt.
Write `manifest.json` summarizing all findings.
