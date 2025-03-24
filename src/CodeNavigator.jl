module CodeNavigator

export get_function_dict, scan_julia_files_in_directory, create_uml_diagram, scan_julia_file
export get_function_definitions, get_function_calls, scan_julia_file

using JSON
using YAML
using Glob
using JuliaSyntax

PT = PromptingTools
AT = PromptingTools.Experimental.AgentTools

include("create_diagram.jl")
include("aiconfig.jl")

function get_function_definitions(node)
  functions = String[]

  if node isa Expr
    if node.head == :function
      # Get function name from the first argument
      fname = if node.args[1] isa Expr
        string(node.args[1].args[1])
      else
        string(node.args[1])
      end
      push!(functions, fname)
    end

    # Recursively search in all arguments
    for arg in node.args
      append!(functions, get_function_definitions(arg))
    end
  end

  return functions
end

function get_function_calls(node)
  calls = String[]

  if node isa Expr
    if node.head == :call
      # Get the function name from the first argument
      fname = string(node.args[1])
      push!(calls, fname)
    end

    # Recursively search in all arguments
    for arg in node.args
      append!(calls, get_function_calls(arg))
    end
  end

  return unique(calls)
end


function find_function_node(node, target_name)
  if node isa Expr
    if node.head == :function
      current_fname = if node.args[1] isa Expr
        string(node.args[1].args[1])
      else
        string(node.args[1])
      end

      if current_fname == target_name
        return node
      end
    end

    # Search recursively in all arguments
    for arg in node.args
      result = find_function_node(arg, target_name)
      if result !== nothing
        return result
      end
    end
  end
  return nothing
end


function get_function_dict(filepath::String)
  if !isfile(filepath)
    error("File not found: $filepath")
  end

  content = read(filepath, String)
  if isempty(content)
    return Dict{String,Vector{String}}()
  end

  @info "Finding function definitions in $filepath"

  # Parse the code into a syntax tree
  expr = JuliaSyntax.parseall(Expr, content)
  function_names = get_function_definitions(expr)
  if isempty(function_names)
    println("No functions found in $filepath")
  end

  function_names = [strip(f) for f in function_names]
  # remove arguments from function names
  function_names = [split(f, "(")[1] for f in function_names]
  unique!(function_names)

  function_dict = Dict{String,Vector{String}}()
  for function_name in function_names
    function_dict[function_name] = []
  end
  
  for func_name in function_names
      func_node = find_function_node(expr, func_name)
      if func_node !== nothing
          for call in get_function_calls(func_node.args[2])
              function_dict[func_name] = [function_dict[func_name]..., call]
          end
      end
  end

  return function_dict
end

function filter_external_functions!(functions::Dict{String,Vector{String}})
  keys_set = Set(keys(functions))
  for (key, calls) in functions
    functions[key] = filter(call -> call ∈ keys_set, calls)
  end
end

"""
    scan_julia_files_in_directory(directory::String; 
        exclude_folders::Vector{String}=String[],
        include_external_functions::Bool=true,
        save_to_file::Bool=true,
        create_diagram::Bool=true,
        exclude_files::Vector{String}=String[]) -> Dict{String,Vector{String}}

Recursively scan a directory for Julia files and analyze function calls within them.

# Arguments
- `directory::String`: The root directory to start scanning from
- `exclude_folders::Vector{String}`: List of folder names to skip during scanning
- `include_external_functions::Bool`: If false, only keep function calls that are defined within the scanned files
- `save_to_file::Bool`: If true, save the results to "functions.json"
- `create_diagram::Bool`: If true, create a UML diagram of the function calls
- `exclude_files::Vector{String}`: List of file names to skip during scanning

# Returns
A dictionary mapping function names to vectors of function names they call.

# Example
```julia
# Scan all Julia files in current directory
funcs = scan_julia_files_in_directory(".")

# Scan with exclusions
funcs = scan_julia_files_in_directory("src", 
    exclude_folders=["test", "docs"],
    include_external_functions=false)
```
"""
function scan_julia_files_in_directory(directory::String; exclude_folders::Vector{String}=String[], include_external_functions::Bool=false,
  save_to_file::Bool=true,
  create_diagram::Bool=true, exclude_files::Vector{String}=String[])
  functions = Dict{String,Vector{String}}()

  for file in readdir(directory, join=true)
    if isdir(file)
      if basename(file) ∉ exclude_folders
        merge!(functions, scan_julia_files_in_directory(file; exclude_folders=exclude_folders, include_external_functions=true))
      end
    elseif occursin(r"\.jl$", file) && basename(file) ∉ exclude_files
      merge!(functions, get_function_dict(file))
    end
  end

  if !include_external_functions
    filter_external_functions!(functions)
  end

  if save_to_file
    open("functions.json", "w") do f
      JSON.print(f, functions)
    end
  end

  if create_diagram
    create_uml_diagram(functions, filepath="code_diagram.uml")
  end

  return functions
end

"""
    scan_julia_file(filepath::String; 
        include_external_functions::Bool=false,
        save_to_file::Bool=true,
        create_diagram::Bool=true) -> Dict{String,Vector{String}}

Analyze function calls within a single Julia file.

# Arguments
- `filepath::String`: The Julia file to analyze
- `include_external_functions::Bool`: If false, only keep function calls that are defined within the file
- `save_to_file::Bool`: If true, save the results to "functions.json"
- `create_diagram::Bool`: If true, create a UML diagram of the function calls

# Returns
A dictionary mapping function names to vectors of function names they call.

# Example
```julia
# Analyze a single Julia file
funcs = scan_julia_file("src/myfile.jl")
```
"""
function scan_julia_file(filepath::String; 
    include_external_functions::Bool=false,
    save_to_file::Bool=true,
    create_diagram::Bool=true)

    file_name = basename(filepath)
    
    if !isfile(filepath) || !occursin(r"\.jl$", filepath)
        error("Not a valid Julia file: $filepath")
    end

    functions = get_function_dict(filepath)

    if !include_external_functions
        filter_external_functions!(functions)
    end

    if save_to_file
        open("functions_$(file_name).json", "w") do f
            JSON.print(f, functions)
        end
    end

    if create_diagram
        create_uml_diagram(functions, filepath="code_diagram_$(file_name).uml")
    end

    return functions
end

end # module