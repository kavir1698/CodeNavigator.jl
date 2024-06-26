module CodeNavigator

using CSTParser

export analyze_function_calls, scan_julia_files_in_directory, create_uml_diagram


function analyze_function_calls(filepath::String, include_external_functions::Bool=false)
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
        functions[current_function] = String[]
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

  if !include_external_functions
    filter_external_functions!(functions)
  end

  return functions
end

# TODO: it doesn't recognize some functions
function get_function_name(expr)
  # Check if expr is valid
  if expr !== nothing && hasproperty(expr, :head) && expr.head === :function
    # Directly attempt to extract the function name from the first argument if it's an identifier
    if hasproperty(expr, :args) && length(expr.args) > 0
      for arg in expr.args
        if CSTParser.isidentifier(arg)
          return arg.val
        elseif CSTParser.iscall(arg) && length(arg.args) > 0
          if CSTParser.isidentifier(arg.args[1])
            return arg.args[1].val
          else
            # Recursively search within nested calls
            name = get_function_name(arg.args[1])
            if name !== nothing
              return name
            end
          end
        end
      end
    end
  end

  # Fallback if no name is found
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

function create_uml_diagram(functions_and_calls::Dict{String,Vector{String}}; filepath::String="code_diagram.uml")
  uml = ["@startuml"]

  # Helper function to create a valid PlantUML state name
  function clean_state_name(name::String)
    return replace(name, r"[^a-zA-Z0-9_]" => "_")
  end

  # Process each function
  for (func, calls) in functions_and_calls
    push!(uml, "state $(clean_state_name(func)) {")

    # Add nested states for each unique function call
    unique_calls = unique(calls)
    for call in unique_calls
      if call in keys(functions_and_calls)  # Only add if it's a known function
        push!(uml, "    state $(clean_state_name(call))")
      end
    end

    # Add transitions between calls in the order they appear
    for i in 1:(length(calls)-1)
      if calls[i] in keys(functions_and_calls) && calls[i+1] in keys(functions_and_calls)
        push!(uml, "    $(clean_state_name(calls[i])) --> $(clean_state_name(calls[i+1]))")
      end
    end

    push!(uml, "}")
  end

  push!(uml, "@enduml")
  save_uml_diagram(filepath, join(uml, "\n"))
  return join(uml, "\n")
end

function save_uml_diagram(filepath::String, uml::String)
  open(filepath, "w") do f
    write(f, uml)
  end
end

function filter_external_functions!(functions::Dict{String,Vector{String}})
  keys_set = Set(keys(functions))
  for (key, calls) in functions
    functions[key] = filter(call -> call ∈ keys_set, calls)
  end
end

function scan_julia_files_in_directory(directory::String; exclude_folders::Vector{String}=String[], include_external_functions::Bool=false)
  functions = Dict{String,Vector{String}}()

  for file in readdir(directory, join=true)
    if isdir(file)
      if basename(file) ∉ exclude_folders
        merge!(functions, scan_julia_files_in_directory(file; exclude_folders=exclude_folders, include_external_functions=include_external_functions))
      end
    elseif occursin(r"\.jl$", file)
      merge!(functions, analyze_function_calls(file, include_external_functions))
    end
  end

  return functions
end

end # module