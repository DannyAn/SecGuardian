// SecGuardian Indexer — Semantic code indexer for AI-augmented security analysis
//
// Builds a structured index (symbols, call graph, alloc/free pairs, lock usage)
// from source code. Called by AI agent commands before scan/audit/review.
//
// Usage:
//   secguardian-index --path ./src --output .codeagent/index.json
//   secguardian-index --health
//   secguardian-index --version

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

const version = "0.14.0"

func main() {
	runIndex(os.Args[1:])
}

func runIndex(args []string) {
	fs := flag.NewFlagSet("secguardian-index", flag.ExitOnError)
	pathFlag := fs.String("path", ".", "Source directory to index")
	langFlag := fs.String("lang", "auto", "Language: c, cpp, python, java, go, javascript, auto")
	outputFlag := fs.String("output", ".codeagent/index.json", "Output file path")
	versionFlag := fs.Bool("version", false, "Print version and exit")
	healthFlag := fs.Bool("health", false, "Smoke test: can we parse a known file?")
	fs.Parse(args)

	if *versionFlag {
		fmt.Printf("secguardian-index %s\n", version)
		os.Exit(0)
	}

	if *healthFlag {
		files, err := collectFiles(*pathFlag, *langFlag)
		if err != nil {
			fmt.Printf("HEALTH:FAIL %v\n", err)
			os.Exit(1)
		}
		if len(files) == 0 {
			fmt.Println("HEALTH:WARN no source files found (but binary is executable)")
			os.Exit(0)
		}
		_, err = parser.ParseFile(files[0], detectLanguage(files[0], *langFlag))
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
			fmt.Fprintf(os.Stderr, "  [WARN] Failed to parse %s: %v\n", filepath.Base(f), err)
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


	// Determine primary language
	primaryLang := *langFlag
	if primaryLang == "auto" {
		extCount := make(map[string]int)
		for _, f := range files {
			extCount[detectLanguage(f, "auto")]++
		}
		maxCount := 0
		for lang, count := range extCount {
			if count > maxCount {
				maxCount = count
				primaryLang = lang
			}
		}
		if primaryLang == "auto" {
			primaryLang = "c"
		}
	}

	// Phase 6: Assemble and write context
	ctx := context.AnalysisContext{
		Path:            *pathFlag,
		FileCount:       len(files),
		FunctionCount:   len(symbols.Functions),
		CallEdgeCount:   len(cg.Edges),
		PrimaryLanguage: primaryLang,
		Files:           files,
		Symbols:         symbols,
		CallGraph:       cg,
		AllocFree:       af,
		LockGraph:       lg,
	}

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
		"c":          {".c", ".h"},
		"cpp":        {".c", ".cpp", ".cc", ".cxx", ".h", ".hpp", ".hh"},
		"python":     {".py"},
		"java":       {".java"},
		"go":         {".go"},
		"javascript": {".js", ".jsx", ".mjs", ".cjs"},
	}

	var exts []string
	if lang == "auto" {
		exts = []string{".c", ".cpp", ".cc", ".cxx", ".h", ".hpp", ".hh", ".py", ".java", ".go", ".js", ".jsx", ".mjs", ".cjs"}
	} else if e, ok := extMap[lang]; ok {
		exts = e
	} else {
		return nil, fmt.Errorf("unsupported language: %s (use: c, cpp, python, java, go, javascript, auto)", lang)
	}

	err := filepath.Walk(path, func(p string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			base := filepath.Base(p)
			if base == ".git" || base == ".claude" || base == ".codeagent" || base == ".gemini" || base == ".opencode" || base == "node_modules" || base == "dist" || base == "target" || base == "build" || base == "static" || base == "public" {
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
	case ".js", ".jsx", ".mjs", ".cjs":
		return "javascript"
	}
	return "c"
}
