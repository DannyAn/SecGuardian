package reflection

import (
	"encoding/json"
	"os"
	"strings"
)

// SymbolValidator checks that referenced symbols exist in the index.
type SymbolValidator struct {
	KnownSymbols map[string]bool
}

// NewSymbolValidator loads a symbol index JSON and builds a lookup table.
func NewSymbolValidator(indexPath string) (*SymbolValidator, error) {
	data, err := os.ReadFile(indexPath)
	if err != nil {
		return nil, err
	}
	var idx struct {
		Symbols struct {
			Functions []struct{ Name string `json:"name"` } `json:"functions"`
		} `json:"symbols"`
	}
	if err := json.Unmarshal(data, &idx); err != nil {
		return nil, err
	}
	sv := &SymbolValidator{KnownSymbols: make(map[string]bool)}
	for _, fn := range idx.Symbols.Functions {
		sv.KnownSymbols[fn.Name] = true
	}
	return sv, nil
}

// Validate checks if a symbol name exists in the known symbol table.
func (sv *SymbolValidator) Validate(symbolName string) (bool, string) {
	if sv.KnownSymbols[symbolName] {
		return true, ""
	}
	// Fuzzy fallback: check if symbol is referenced in index JSON as substring
	return false, "symbol not found in index: " + symbolName
}

// ValidateSource checks if a symbol string appears in a source file.
func (sv *SymbolValidator) ValidateSource(file string, symbolName string) (bool, string) {
	content, err := os.ReadFile(file)
	if err != nil {
		return false, err.Error()
	}
	if strings.Contains(string(content), symbolName+"(") || strings.Contains(string(content), symbolName+" ") {
		return true, ""
	}
	return false, "symbol " + symbolName + " not found in " + file
}
