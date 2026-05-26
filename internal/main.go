// SecGuardian Internal — Semantic Index Engine
//
// This module provides the "scan once" code understanding layer.
// tree-sitter parses source files; the indexer extracts symbols, builds
// a lightweight call graph, and identifies alloc/free pairs and lock usage.
//
// Usage:
//   secguardian-index --path ./src --output .codeagent/index.json
//   secguardian-index --path ./src --lang cpp --output index.json

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

func main() {
	pathFlag := flag.String("path", ".", "Source directory to index")
	langFlag := flag.String("lang", "auto", "Language: c, cpp, python, java, go, auto")
	outputFlag := flag.String("output", ".codeagent/index.json", "Output file path")
	flag.Parse()

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
		Path:       *pathFlag,
		Files:      files,
		Symbols:    symbols,
		CallGraph:  cg,
		AllocFree:  af,
		LockGraph:  lg,
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
