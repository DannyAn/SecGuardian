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

const version = "0.18.0"

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
	fmt.Printf("  Parser mode: %s\n", parser.ParserMode)

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

	// Phase 2.5: Collect all signal types from parsed results (Signal Matrix)
	allCallSites := make([]parser.CallSite, 0)
	allStrings := make([]parser.StringLiteral, 0)
	allDecls := make([]parser.Declaration, 0)
	allValues := make([]parser.ValueConstant, 0)
	allImports := make([]parser.Import, 0)
	allConfigs := make([]parser.ConfigPattern, 0)
	allFlow := make([]parser.ControlFlowSignal, 0)
	allPtrValidations := make([]parser.PointerValidation, 0)
	allStructInits := make([]parser.StructInit, 0)
	allVarWrites := make([]parser.VariableWrite, 0)
	allCFGs := make([]parser.FunctionCFG, 0)
	for _, result := range parsed {
		allCallSites = append(allCallSites, result.CallSites...)
		allStrings = append(allStrings, result.StringLiterals...)
		allDecls = append(allDecls, result.Declarations...)
		allValues = append(allValues, result.ValueConstants...)
		allImports = append(allImports, result.Imports...)
		allConfigs = append(allConfigs, result.ConfigPatterns...)
		allFlow = append(allFlow, result.ControlFlow...)
		allPtrValidations = append(allPtrValidations, result.PointerValidations...)
		allStructInits = append(allStructInits, result.StructInits...)
		allVarWrites = append(allVarWrites, result.VariableWrites...)
		allCFGs = append(allCFGs, result.CFGs...)
	}

	// Phase 2.6: Run prescreener to filter deterministically-safe signals
	// before passing the remainder to the LLM (EPIC-009).
	before := len(allCallSites)
	allCallSites, pa := indexer.PrescreenCallSites(allCallSites, allDecls)
	if pa.SafeCount > 0 {
		pct := 0.0
		if before > 0 {
			pct = float64(pa.SafeCount) / float64(before) * 100
		}
		fmt.Printf("  Prescreener: %d safe filtered (%.1f%%), %d remaining for LLM\n",
			pa.SafeCount, pct, len(allCallSites))
	}

	// Phase 3: Build call graph (V2 if call_sites available, else V1 fallback)
	var cg indexer.CallGraph
	if len(allCallSites) > 0 {
		cg = indexer.BuildCallGraphV2(allCallSites, symbols)
	} else {
		cg = indexer.BuildCallGraph(parsed, symbols)
	}
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
		Path:              *pathFlag,
		FileCount:         len(files),
		FunctionCount:     len(symbols.Functions),
		CallEdgeCount:     len(cg.Edges),
		PrimaryLanguage:   primaryLang,
		Files:             files,
		Symbols:           symbols,
		CallGraph:         cg,
		AllocFree:         af,
		LockGraph:         lg,
		CallSites:         allCallSites,
		StringLiterals:    allStrings,
		Declarations:      allDecls,
		ValueConstants:    allValues,
		Imports:           allImports,
		ConfigPatterns:    allConfigs,
		ControlFlow:       allFlow,
		PointerValidations: allPtrValidations,
		StructInits:       allStructInits,
		VariableWrites:    allVarWrites,
		CFGs:              allCFGs,
	}

	ptrSig := ""
	if len(allPtrValidations) > 0 {
		ptrSig = fmt.Sprintf(", %d ptr-valid", len(allPtrValidations))
	}
	structSig := ""
	if len(allStructInits) > 0 {
		structSig = fmt.Sprintf(", %d struct-init", len(allStructInits))
	}
	varSig := ""
	if len(allVarWrites) > 0 {
		varSig = fmt.Sprintf(", %d var-write", len(allVarWrites))
	}
	fmt.Printf("  Signals: %d calls, %d strings, %d decls, %d values, %d imports, %d configs, %d flow%s%s%s\n",
		len(allCallSites), len(allStrings), len(allDecls), len(allValues), len(allImports), len(allConfigs), len(allFlow),
		ptrSig, structSig, varSig)

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
