// SecGuardian CLI — Security Analysis Engine
//
// Usage:
//   secguardian --version
//   secguardian --health --path ./src
//   secguardian index --path ./src --output .codeagent/index.json
//   secguardian detectors
//
// Build: go build -o secguardian .

package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/secguardian/internal/context"
	"github.com/secguardian/internal/indexer"
	"github.com/secguardian/internal/parser"
)

const version = "0.2.0"

// Detector definition for the CLI's built-in registry
type DetectorInfo struct {
	ID       string `json:"id"`
	CWE      string `json:"cwe"`
	Severity string `json:"severity"`
	Language string `json:"language"`
	Category string `json:"category"`
}

var detectorRegistry = []DetectorInfo{
	// Memory (13)
	{ID: "memory.null-dereference", CWE: "CWE-476", Severity: "High", Language: "c,cpp", Category: "memory"},
	{ID: "memory.double-free", CWE: "CWE-415", Severity: "Critical", Language: "c,cpp", Category: "memory"},
	{ID: "memory.use-after-free", CWE: "CWE-416", Severity: "Critical", Language: "c,cpp", Category: "memory"},
	{ID: "memory.buffer-overflow", CWE: "CWE-120", Severity: "Critical", Language: "c,cpp", Category: "bounds"},
	{ID: "memory.heap-buffer-overflow", CWE: "CWE-122", Severity: "Critical", Language: "c,cpp", Category: "bounds"},
	{ID: "memory.format-string", CWE: "CWE-134", Severity: "Critical", Language: "c,cpp", Category: "memory"},
	{ID: "memory.integer-overflow", CWE: "CWE-190", Severity: "High", Language: "c,cpp", Category: "bounds"},
	{ID: "memory.uninitialized-memory", CWE: "CWE-457", Severity: "Medium", Language: "c,cpp", Category: "memory"},
	{ID: "memory.memory-leak", CWE: "CWE-401", Severity: "Medium", Language: "c,cpp", Category: "memory"},
	{ID: "memory.mismatched-free", CWE: "CWE-762", Severity: "High", Language: "c,cpp", Category: "memory"},
	{ID: "memory.off-by-one", CWE: "CWE-193", Severity: "High", Language: "c,cpp", Category: "bounds"},
	{ID: "memory.bad-cast", CWE: "CWE-704", Severity: "Medium", Language: "c,cpp", Category: "memory"},
	{ID: "memory.oob-read", CWE: "CWE-125", Severity: "High", Language: "c,cpp", Category: "memory"},
	// Concurrency (4)
	{ID: "concurrency.race-condition", CWE: "CWE-362", Severity: "High", Language: "c,cpp", Category: "concurrency"},
	{ID: "concurrency.deadlock", CWE: "CWE-833", Severity: "Medium", Language: "c,cpp", Category: "concurrency"},
	{ID: "concurrency.data-race", CWE: "CWE-366", Severity: "High", Language: "c,cpp", Category: "concurrency"},
	{ID: "concurrency.thread-unsafe-signal", CWE: "CWE-479", Severity: "Medium", Language: "c,cpp", Category: "concurrency"},
	// System (6)
	{ID: "system.command-injection", CWE: "CWE-77", Severity: "Critical", Language: "c,cpp", Category: "system"},
	{ID: "system.path-traversal", CWE: "CWE-22", Severity: "High", Language: "c,cpp", Category: "system"},
	{ID: "system.toctou", CWE: "CWE-367", Severity: "High", Language: "c,cpp", Category: "system"},
	{ID: "system.insecure-temp-file", CWE: "CWE-377", Severity: "Medium", Language: "c,cpp", Category: "system"},
	{ID: "system.symlink-attack", CWE: "CWE-61", Severity: "Medium", Language: "c,cpp", Category: "system"},
	{ID: "system.privilege-escalation", CWE: "CWE-269", Severity: "High", Language: "c,cpp", Category: "system"},
	// Crypto (4)
	{ID: "crypto.hardcoded-secrets", CWE: "CWE-798", Severity: "High", Language: "c,cpp", Category: "crypto"},
	{ID: "crypto.weak-random", CWE: "CWE-338", Severity: "High", Language: "c,cpp", Category: "crypto"},
	{ID: "crypto.weak-crypto-algorithm", CWE: "CWE-327", Severity: "High", Language: "c,cpp", Category: "crypto"},
	{ID: "crypto.insufficient-key-length", CWE: "CWE-326", Severity: "Medium", Language: "c,cpp", Category: "crypto"},
	// Web (11)
	{ID: "web.xss", CWE: "CWE-79", Severity: "Critical", Language: "java,python,go", Category: "web"},
	{ID: "web.ssrf", CWE: "CWE-918", Severity: "High", Language: "java,python,go", Category: "web"},
	{ID: "web.csrf", CWE: "CWE-352", Severity: "High", Language: "java,python,go", Category: "web"},
	{ID: "web.auth-bypass", CWE: "CWE-287", Severity: "Critical", Language: "java,python,go", Category: "web"},
	{ID: "web.idor", CWE: "CWE-639", Severity: "High", Language: "java,python,go", Category: "web"},
	{ID: "web.xxe", CWE: "CWE-611", Severity: "Critical", Language: "java,python,go", Category: "web"},
	{ID: "web.jwt-misuse", CWE: "CWE-347", Severity: "High", Language: "java,python,go", Category: "web"},
	{ID: "web.open-redirect", CWE: "CWE-601", Severity: "Medium", Language: "java,python,go", Category: "web"},
	{ID: "web.missing-authentication", CWE: "CWE-306", Severity: "Critical", Language: "java,python,go", Category: "web"},
	{ID: "web.missing-authorization", CWE: "CWE-862", Severity: "High", Language: "java,python,go", Category: "web"},
	{ID: "web.unrestricted-upload", CWE: "CWE-434", Severity: "Critical", Language: "java,python,go", Category: "web"},
	// General (3)
	{ID: "general.input-validation", CWE: "CWE-20", Severity: "High", Language: "c,cpp,java,python,go", Category: "general"},
	{ID: "general.insecure-permissions", CWE: "CWE-276", Severity: "Medium", Language: "c,cpp,java,python,go", Category: "general"},
	{ID: "general.resource-exhaustion", CWE: "CWE-400", Severity: "Medium", Language: "c,cpp,java,python,go", Category: "general"},
	// Language-specific (4)
	{ID: "java.sql-injection", CWE: "CWE-89", Severity: "Critical", Language: "java", Category: "language"},
	{ID: "java.deserialization", CWE: "CWE-502", Severity: "Critical", Language: "java", Category: "language"},
	{ID: "python.code-injection", CWE: "CWE-94", Severity: "Critical", Language: "python", Category: "language"},
	{ID: "go.sql-injection", CWE: "CWE-89", Severity: "Critical", Language: "go", Category: "language"},
}

func main() {
	// Subcommand routing
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "detectors", "list":
			listDetectors()
			return
		case "index":
			runIndex(os.Args[2:])
			return
		case "version":
			fmt.Printf("secguardian %s\n", version)
			return
		}
	}

	// Default: backward-compatible index mode with --path
	runIndex(os.Args[1:])
}

func listDetectors() {
	fmt.Printf("SecGuardian v%s — 45 Detectors\n", version)
	fmt.Println(strings.Repeat("─", 70))
	fmt.Printf("%-30s %-10s %-10s %s\n", "DETECTOR", "CWE", "SEVERITY", "LANG")
	fmt.Println(strings.Repeat("─", 70))

	categories := []string{"memory", "concurrency", "system", "crypto", "web", "general", "language"}
	for _, cat := range categories {
		hasHeader := false
		for _, d := range detectorRegistry {
			if d.Category != cat {
				continue
			}
			if !hasHeader {
				hasHeader = true
				fmt.Printf("\n── %s ──\n", strings.ToUpper(cat))
			}
			fmt.Printf("  %-28s %-10s %-10s %s\n", d.ID, d.CWE, d.Severity, d.Language)
		}
	}

	fmt.Println(strings.Repeat("─", 70))
	fmt.Printf("CWE Top 25: 22/25 (88%%)  |  OWASP Top 10: 9/10 (90%%)\n")
	fmt.Printf("Docs & audit skills: secguardian --help\n")
}

func runIndex(args []string) {
	fs := flag.NewFlagSet("secguardian", flag.ExitOnError)
	pathFlag := fs.String("path", ".", "Source directory to index")
	langFlag := fs.String("lang", "auto", "Language: c, cpp, python, java, go, auto")
	outputFlag := fs.String("output", ".codeagent/index.json", "Output file path")
	versionFlag := fs.Bool("version", false, "Print version and exit")
	healthFlag := fs.Bool("health", false, "Smoke test: can we parse a known file?")
	fs.Parse(args)

	if *versionFlag {
		fmt.Printf("secguardian %s\n", version)
		os.Exit(0)
	}

	if *healthFlag {
		files, _ := collectFiles(*pathFlag, *langFlag)
		if len(files) == 0 {
			fmt.Println("HEALTH:WARN no source files found (but binary is executable)")
			os.Exit(0)
		}
		_, err := parser.ParseFile(files[0], detectLanguage(files[0], *langFlag))
		if err != nil {
			fmt.Printf("HEALTH:FAIL parser error: %v\n", err)
			os.Exit(1)
		}
		fmt.Printf("HEALTH:OK (%d source files available)\n", len(files))
		os.Exit(0)
	}

	// Collect source files
	files, err := collectFiles(*pathFlag, *langFlag)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	if len(files) == 0 {
		fmt.Fprintf(os.Stderr, "Error: no source files found in %s\n", *pathFlag)
		os.Exit(1)
	}

	fmt.Printf("Indexing %d files in %s...\n", len(files), *pathFlag)

	// Phase 1: Parse all files
	parsed := make(map[string]*parser.ParseResult)
	for _, f := range files {
		lang := detectLanguage(f, *langFlag)
		result, err := parser.ParseFile(f, lang)
		if err != nil {
			fmt.Fprintf(os.Stderr, "  [WARN] Failed to parse %s: %v\n", f, err)
			continue
		}
		parsed[f] = result
		fmt.Printf("  Parsed: %s (%d functions, %d vars)\n", filepath.Base(f), len(result.Functions), len(result.Variables))
	}

	// Phase 2: Build symbol index
	symbols := indexer.ExtractSymbols(parsed)
	fmt.Printf("  Symbols: %d functions, %d variables, %d types\n",
		len(symbols.Functions), len(symbols.Variables), len(symbols.Types))

	// Phase 3: Build call graph
	cg := indexer.BuildCallGraph(parsed, symbols)
	fmt.Printf("  Call graph: %d edges\n", len(cg.Edges))

	// Phase 4: Match alloc/free pairs
	af := indexer.MatchAllocFree(parsed)
	fmt.Printf("  Alloc/free: %d pairs\n", len(af.Pairs))

	// Phase 5: Build lock usage graph
	lg := indexer.BuildLockGraph(parsed)
	fmt.Printf("  Lock usage: %d mutexes\n", len(lg.Mutexes))

	// Phase 6: Assemble context
	ctx := context.AnalysisContext{
		Path:      *pathFlag,
		Files:     files,
		Symbols:   symbols,
		CallGraph: cg,
		AllocFree: af,
		LockGraph: lg,
	}

	// Write output
	if err := os.MkdirAll(filepath.Dir(*outputFlag), 0755); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	data, err := json.MarshalIndent(ctx, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	if err := os.WriteFile(*outputFlag, data, 0644); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Index written to %s (%d bytes)\n", *outputFlag, len(data))
}

func collectFiles(path, lang string) ([]string, error) {
	var files []string
	extMap := map[string][]string{
		"c":      {".c", ".h"},
		"cpp":    {".c", ".cpp", ".cc", ".cxx", ".h", ".hpp", ".hh"},
		"python": {".py"},
		"java":   {".java"},
		"go":     {".go"},
	}

	var exts []string
	if lang == "auto" {
		exts = []string{".c", ".cpp", ".cc", ".cxx", ".h", ".hpp", ".hh", ".py", ".java", ".go"}
	} else if e, ok := extMap[lang]; ok {
		exts = e
	} else {
		return nil, fmt.Errorf("unsupported language: %s (use: c, cpp, python, java, go, auto)", lang)
	}

	err := filepath.Walk(path, func(p string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			base := filepath.Base(p)
			if strings.HasPrefix(base, ".") || base == "node_modules" || base == "dist" {
				return filepath.SkipDir
			}
			return nil
		}
		for _, ext := range exts {
			if strings.HasSuffix(p, ext) {
				files = append(files, p)
				break
			}
		}
		return nil
	})
	return files, err
}

func detectLanguage(file, langFlag string) string {
	if langFlag != "auto" {
		return langFlag
	}
	ext := filepath.Ext(file)
	switch ext {
	case ".c", ".h":
		return "c"
	case ".cpp", ".cc", ".cxx", ".hpp", ".hh":
		return "cpp"
	case ".py":
		return "python"
	case ".java":
		return "java"
	case ".go":
		return "go"
	}
	return "c"
}
