# CodePlan: Packaging, Installation & Indexer Integration Architecture

> Status: **Proposed for Review**
> Focus: Fixing packaging, relative paths, cross-platform binary wrappers, agent-based indexer invocation, and installation scripts.

---

## 1. Comprehensive Problem Definition & Rationale

SecGuardian is an **AI-native white-box security scanner**. Unlike traditional SAST tools, the "scanning engine" is the AI Agent itself (e.g. Claude Code, OpenCode, Gemini CLI), which reasons about vulnerabilities by reading code, applying security concepts, and writing findings.

To do this effectively, the Agent needs:
1. **The Prompts & Knowledge**: Command files (`commands/`), skill methodology (`skills/`), and the rule base (`knowledge/`).
2. **Structural Code Context**: A tree-sitter generated symbol index, call graph, and alloc/free map (`index.json`), produced by the Go binary `secguardian-index`.

Currently, this system fails outside the development repository due to two fatal logical gaps:

### Gap 1: Commands do not call `secguardian-index`
- **Symptom**: Looking at `commands/secguard.md`, `commands/secaudit.md`, and `commands/secreview.md`, there is no instruction directing the AI Agent to run `secguardian-index`.
- **Consequence**: When a user runs `/secguard` or `/secaudit` inside Claude Code or OpenCode, the Agent does not run the indexer. It either falls back to scanning raw files recursively (highly expensive, slow, and prone to hallucinations) or fails because `index.json` is missing.
- **Resolution**: Add explicit "Execution Instructions" to all command markdown entry points directing the Agent to run the wrapper `secguardian-index` binary to generate `<output_dir>/index.json`, read it, and use it as structural context.

### Gap 2: Incomplete Zip Packaging & Deployment
- **Symptom**: `release.sh` and `deploy.sh` only copy/pack the `commands/` directory for OpenCode.
- **Consequence**: The OpenCode zip lacks the skills, the knowledge base, and the indexer binary. The Agent cannot locate rule definitions or the indexer executable.
- **Resolution**: Standardize the package structure of all three platforms to be complete and self-contained, enclosing `commands/`, `skills/`, `knowledge/`, and `scripts/` (containing cross-platform binaries + wrappers).

### Gap 3: Broken Relative Paths in Prompts
- **Symptom**: Prompts use `../../knowledge/` to reference rules, which breaks when installed in a target workspace.
- **Resolution**: Standardize all relative paths in prompts to `../knowledge/...` and ensure the target installation directory mirrors this structure.

### Gap 4: Cross-Platform Precompiled Binaries
- **Symptom**: Packaging copies the natively compiled host binary, making ZIP packages platform-dependent.
- **Resolution**: Cross-compile the indexer binary for all platforms (`darwin-arm64`, `darwin-amd64`, `linux-amd64`, `windows-amd64`) and include them in a `bin/` subfolder. Provide a smart shell wrapper (`secguardian-index`) and PowerShell wrapper (`secguardian-index.ps1`) that detects the host environment and invokes the correct binary.

---

## 2. Target Directory & Package Structure

We will standardize the directory layout for all three platforms. This allows all prompts to use `../knowledge/` and `../skills/` relative to their execution contexts.

### 2.1 Unified Claude Code Layout (`~/.claude/extensions/<ext-name>/`)
```
~/.claude/extensions/secguard-secguardian/
├── extension.json
├── .claude-plugin/plugin.json
├── commands/
│   └── secguard.md
├── skills/
│   └── secguard-cpp/
├── knowledge/
│   ├── concepts/
│   ├── detectors/
│   └── protocols/
└── scripts/
    ├── secguardian-index (shell script wrapper)
    └── bin/
        ├── secguardian-index-darwin-amd64
        ├── secguardian-index-darwin-arm64
        └── secguardian-index-linux-amd64
```

### 2.2 Unified OpenCode Layout (`<project-root>/.opencode/`)
```
<project-root>/.opencode/
├── commands/
│   ├── secaudit.md
│   ├── secguard.md
│   └── secreview.md
├── skills/
│   ├── secaudit-taint-analysis/
│   ├── secguard-cpp/
│   └── ... (all 25 skills)
├── knowledge/
│   ├── concepts/
│   ├── detectors/
│   ├── languages/
│   └── protocols/
└── scripts/
    ├── secguardian-index (shell script wrapper)
    ├── secguardian-index.ps1 (powershell wrapper)
    └── bin/
        ├── secguardian-index-darwin-amd64
        ├── secguardian-index-darwin-arm64
        ├── secguardian-index-linux-amd64
        └── secguardian-index-windows-amd64.exe
```

### 2.3 Unified Gemini CLI Layout (`<project-root>/.gemini/`)
```
<project-root>/.gemini/
├── GEMINI.md
├── commands/
│   ├── secaudit.toml
│   ├── secguard.toml
│   └── secreview.toml
├── skills/
│   ├── secaudit-taint-analysis/
│   ├── secguard-cpp/
│   └── ... (all 25 skills)
├── knowledge/
│   ├── concepts/
│   ├── detectors/
│   ├── languages/
│   └── protocols/
└── scripts/
    ├── secguardian-index (shell script wrapper)
    ├── secguardian-index.ps1 (powershell wrapper)
    └── bin/
        ├── secguardian-index-darwin-amd64
        ├── secguardian-index-darwin-arm64
        ├── secguardian-index-linux-amd64
        └── secguardian-index-windows-amd64.exe
```

---

## 3. Detailed Execution Plan

### Step 1: Fix Go CLI Command Routing (`internal/main.go`)
- Modify `main()` in `internal/main.go` to check the executable name.
- If the binary name is `secguardian-index` (or `secguardian-index.exe`), or if the first argument is a flag (starts with `-`) and not a known command, delegate execution directly to `runIndex(os.Args[1:])`.

### Step 2: Add Cross-Platform Wrapper Scripts
- **`scripts/secguardian-index` (Shell Script Wrapper)**:
  - Detects OS using `uname -s` and CPU architecture using `uname -m`.
  - Determines the target binary in the package `bin/` folder (e.g. `bin/secguardian-index-darwin-arm64`).
  - Executes the target binary passing all arguments via `exec "$TARGET" "$@"`.
- **`scripts/secguardian-index.ps1` (PowerShell Wrapper)**:
  - Wrapper for Windows delegating to `bin/secguardian-index-windows-amd64.exe`.

### Step 3: Integrate Indexer Invocation in Commands
- Update `commands/secguard.md`, `commands/secaudit.md`, and `commands/secreview.md` to add the following **Execution Instructions**:
  1. Determine or create the output directory `.codeagent/<ext>/scans/<scan-id>/`.
  2. Locate the wrapper script `secguardian-index` in the plugin directory.
  3. Execute: `<indexer_path> --path <target_path> --output <output_dir>/index.json`.
  4. Read the generated `index.json` and use it as the structural codebase context for scanning.
- Update all path references from `../../knowledge/` to `../knowledge/`.

### Step 4: Refactor Build & Packaging Scripts
- **Update `scripts/package.sh`**:
  - Build/cross-compile the indexer binary for all platforms if Go is available, placing them in `dist/<ext>/scripts/bin/`.
  - Copy wrapper scripts (`secguardian-index` and `secguardian-index.ps1`) to `dist/<ext>/scripts/`.
  - Copy the entire `knowledge/` directory into `dist/<ext>/knowledge/`.
- **Update `scripts/deploy.sh`**:
  - `deploy_opencode()`: Deploy `commands/`, `skills/`, `knowledge/`, and `scripts/` directly to `.opencode/`.
  - `deploy_gemini()`: Deploy `commands/`, `skills/`, `knowledge/`, and `scripts/` directly to `.gemini/`.
- **Update `scripts/release.sh`**:
  - Package the complete layout structure for OpenCode and Gemini CLI ZIPs.
- **Update `scripts/gen-toml.sh`**:
  - Automatically replace `../../knowledge/` with `../knowledge/` when copying markdown commands to TOML prompt strings.

### Step 5: Implement Installer Scripts
- **`install.sh` (macOS/Linux)**:
  - Automates copying/cloning files into `.claude/`, `.opencode/`, or `.gemini/` in a target workspace.
  - Automatically selects or compiles the appropriate binary.
  - Validates using `--health`.
- **`install.ps1` (Windows)**:
  - Implements the equivalent PowerShell installer for Windows platforms.

---

## 4. Verification Plan

### Automated Tests
1. Run `bash scripts/build.sh all --zip` to verify the build process compiles and packages successfully.
2. Confirm the zipped file sizes and check their internal folder structures.
3. Run `go test ./...` in the `internal/` directory.

### Manual Verification
1. Extract `secguardian-0.3.1-opencode.zip` into a dummy project `.opencode/`.
2. Run `./.opencode/scripts/secguardian-index --health` to verify wrapper routing.
3. Run `/secguard` via Claude Code / OpenCode in the dummy project and watch it invoke the indexer, read `index.json`, and successfully execute the scan.
