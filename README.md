Code Navigator
===============

This package is a tool for analyzing and visualizing Julia code bases. It provides a way to scan Julia files in a directory, analyze function calls, and create a UML diagram to visualize the relationships between functions. This is a static call graph.

This is useful for understanding the structure and dependencies of your Julia codebase. It can help developers identify complex relationships between functions, detect potential issues, and improve code organization.

How to use it
--------------

To use Code Navigator, simply include the package in your Julia project and call the `scan_julia_files_in_directory` function, passing in the directory you want to analyze.

Here's a basic example:

```julia
using CodeNavigator

functions = scan_julia_files_in_directory("src")
```

Advanced Usage
-------------

The function supports several optional parameters for customizing the analysis:

```julia
functions = scan_julia_files_in_directory(
    "src",
    exclude_folders=["test", "docs"],  # Skip these folders during scanning
    include_external_functions=false,   # Only show functions defined in your codebase
    save_to_file=true,                 # Save results to "functions.json"
    create_diagram=true,               # Generate UML diagram as "code_diagram.uml"
    exclude_files=["generated.jl"]     # Skip specific files during scanning
)
```

The function returns a dictionary mapping function names to vectors of function names they call, which can be used for further analysis.

LLM Configuration
----------------

CodeNavigator uses Large Language Models for code analysis. You can configure the LLM settings using a `config.yml` file in your project root:

```yaml
model: qwen2.5-coder:14b    # Model name
api_key: ""                 # API key (if using hosted services)
base_url: http://127.0.0.1:11434  # URL for your LLM API
```

### Local Setup with Ollama

1. Install Ollama from https://ollama.ai
2. Pull the Qwen model:
```bash
ollama pull qwen2.5-coder:14b
```
3. Start Ollama server
4. Create `config.yml` in your project root with the above configuration

### Using Other LLMs

You can use any LLM that's compatible with PromptingTools.jl. Simply update the `config.yml` with appropriate settings:

```yaml
# For OpenAI
model: gpt-4
api_key: your_api_key
base_url: https://api.openai.com/v1

# For Anthropic
model: claude-3-opus
api_key: your_api_key
base_url: https://api.anthropic.com/v1
```
