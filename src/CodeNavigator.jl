module CodeNavigator

export analyze_function_calls, scan_julia_files_in_directory, create_uml_diagram

using CSTParser
using JSON

include("create_diagram.jl")

# TODO: handle function broadcasts f.()
# TODO: remove dot . from broadcasted functions
function analyze_function_calls(filepath::String)
  if !isfile(filepath)
    error("File not found: $filepath")
  end

  content = read(filepath, String)
  if isempty(content)
    # println("Warning: File is empty")
    return Dict{String,Vector{String}}()
  end

  parsed = CSTParser.parse(content, true)

  functions = Dict{String,Vector{String}}()
  current_function = nothing

  function traverse(expr)
    if CSTParser.defines_function(expr)
      name = get_function_name(expr)
      if name !== nothing
        current_function = name
        if haskey(functions, current_function)
          functions[current_function] = vcat(functions[current_function], String[])  # Append to existing calls
        else
          functions[current_function] = String[]  # Create new list of calls
        end
        # println("Found function: $name")
      else
        # println("Function name not found for expression: $(typeof(expr))")
        # println("Expression details: $(expr)")
      end
    elseif CSTParser.iscall(expr) && current_function !== nothing
      call_name = get_call_name(expr)
      if call_name !== nothing
        push!(functions[current_function], call_name)
        # println("Found call in $current_function: $call_name")
      end
    end

    if expr.args !== nothing
      for arg in expr.args
        traverse(arg)
      end
    end
  end

  traverse(parsed)

  if isempty(functions)
    println("No functions found in $filepath")
  end

  # Always remove self-references
  for (func, calls) in functions
    functions[func] = filter(c -> c != func, calls)
  end

  # Remove duplicates in calls
  for (func, calls) in functions
    functions[func] = unique(calls)
  end

  return functions
end

function get_function_name(expr)
  # Check if expr is valid and has the necessary properties
  if expr === nothing || !hasproperty(expr, :args) || expr.args === nothing
    return nothing
  end

  # Check for the specific structure we're dealing with
  if length(expr.args) >= 2 &&
     hasproperty(expr.args[1], :head) &&
     expr.args[1].head === :call

    lhs = expr.args[1]  # The function call on the left-hand side of the assignment
    if length(lhs.args) > 0 && CSTParser.isidentifier(lhs.args[1])
      return lhs.args[1].val
    end
  end

  # If not found, recursively search through the args
  for arg in expr.args
    name = get_function_name(arg)
    if name !== nothing
      return name
    end
  end

  # Handle inline function definitions (with or without docstrings):
  for arg in expr.args
    if hasproperty(arg, :head) && hasproperty(arg.head, :val) && arg.head.val == "="
      lhs = arg.args[1]  # Left-hand side of the assignment
      if CSTParser.iscall(lhs) && length(lhs.args) > 0 && CSTParser.isidentifier(lhs.args[1])
        return lhs.args[1].val
      end
    end
  end

  return nothing
end

function get_call_name(expr)
  if expr.args !== nothing && length(expr.args) >= 1
    if CSTParser.isidentifier(expr.args[1])
      return expr.args[1].val
    elseif CSTParser.isoperator(expr.args[1])
      return expr.args[1].val
    end
  end
  return nothing
end

function filter_external_functions!(functions::Dict{String,Vector{String}})
  keys_set = Set(keys(functions))
  for (key, calls) in functions
    functions[key] = filter(call -> call ∈ keys_set, calls)
  end
end

function scan_julia_files_in_directory(directory::String; exclude_folders::Vector{String}=String[], include_external_functions::Bool=false,
  save_to_file::Bool=false,
  create_diagram::Bool=false)
  functions = Dict{String,Vector{String}}()

  for file in readdir(directory, join=true)
    if isdir(file)
      if basename(file) ∉ exclude_folders
        merge!(functions, scan_julia_files_in_directory(file; exclude_folders=exclude_folders, include_external_functions=true))
      end
    elseif occursin(r"\.jl$", file)
      merge!(functions, analyze_function_calls(file))
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

end # module