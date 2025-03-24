Code Navigator
===============

This package is a tool for analyzing and visualizing Julia code bases. It provides a way to scan Julia files in a directory, analyze function calls, and create a UML diagram to visualize the relationships between functions. This is a static call graph.

This is useful for understanding the structure and dependencies of your Julia codebase. It can help developers identify complex relationships between functions, detect potential issues, and improve code organization.

Features
--------
- Static analysis of Julia function calls and definitions
- Support for both regular and inline function definitions
- Generation of function dependency diagrams in UML format
- JSON output of function relationships
- Single file or directory-wide analysis

How to Use
----------

### Analyzing a Directory

```julia
using CodeNavigator

# Scan all Julia files in a directory
functions = scan_julia_files_in_directory("src")

# Scan with advanced options
functions = scan_julia_files_in_directory(
    "src",
    exclude_folders=["test", "docs"],     # Skip these folders during scanning
    include_external_functions=false,      # Only show functions defined in your codebase
    save_to_file=true,                    # Save results to "functions.json"
    create_diagram=true,                  # Generate UML diagram
    exclude_files=["generated.jl"]        # Skip specific files
)
```

### Analyzing a Single File

```julia
# Analyze a specific Julia file
functions = scan_julia_file(
    "src/myfile.jl",
    include_external_functions=false,
    save_to_file=true,
    create_diagram=true
)
```

Output
------

The functions return a dictionary mapping function names to vectors of function names they call. Additionally:

- JSON output is saved as "functions.json" (for directory scan) or "functions_filename.jl.json" (for single file)
- UML diagrams are saved as "code_diagram.uml" or "code_diagram_filename.jl.uml"
  - You can use a tool like [PlantUML](https://plantuml.com/) to render the UML diagram. For example, `plantuml code_diagram.uml` will generate a PNG file. For very large diagrams, use `plantuml -DPLANTUML_LIMIT_SIZE=8192 code_diagram.uml` to increase the size limit. Alternatively, you can use `-tsvg` to generate SVG file `plantuml -tsvg code_diagram.uml`.
