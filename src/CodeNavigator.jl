module CodeNavigator

using CSTParser
using JSON

export analyze_function_calls, scan_julia_files_in_directory, create_uml_diagram

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

function create_uml_diagram(functions_and_calls::Dict{String,Vector{String}}; filepath::String="code_diagram.uml")
  uml = ["@startuml"]
  call_locations = Dict{String,Set{String}}()
  defined_functions = Dict{String,Bool}()  # Tracks if a function has been defined
  added_transitions = Set{String}()  # Tracks added transitions to avoid duplicates and self-links


  # Track call locations
  for (func, calls) in functions_and_calls
    for call in calls
      if !haskey(call_locations, call)
        call_locations[call] = Set{String}()
      end
      push!(call_locations[call], func)
    end
  end

  # Determine single and multiple calls
  single_calls = Dict{String,String}()
  multiple_calls = Dict{String,String}()
  for (call, locations) in call_locations
    _, cleaned_call = clean_state_name(call)  # Use cleaned name
    if length(locations) == 1
      single_calls[cleaned_call] = first(locations)  # Use cleaned name
    else
      multiple_calls[cleaned_call] = call  # Map cleaned name to original
    end
  end

  # Define functions at level 0 for multiple calls
  for (cleaned_func, func) in multiple_calls
    original_name, _ = clean_state_name(func)
    if !haskey(defined_functions, cleaned_func)
      push!(uml, "state $original_name")
      defined_functions[cleaned_func] = true
    end
  end

  # Process each function
  for (func, calls) in functions_and_calls
    original_name, cleaned_func = clean_state_name(func)
    if !(cleaned_func in values(multiple_calls)) && !haskey(defined_functions, cleaned_func)
      push!(uml, "state $original_name {")
      defined_functions[cleaned_func] = true
      for call in unique(calls)
        _, cleaned_call = clean_state_name(call)
        if cleaned_call in keys(single_calls) && single_calls[cleaned_call] == func && !haskey(defined_functions, cleaned_call)
          original_call_name, _ = clean_state_name(call)
          push!(uml, "    state $original_call_name")
          defined_functions[cleaned_call] = true
        end
      end
      push!(uml, "}")
    end

    # Add transitions with checks for self-links and duplicates
    for i in 1:(length(calls)-1)
      _, cleaned_call_i = clean_state_name(calls[i])
      _, cleaned_call_next = clean_state_name(calls[i+1])
      transition = "$cleaned_call_i --> $cleaned_call_next"
      if cleaned_call_i != cleaned_call_next && !in(transition, added_transitions) && haskey(defined_functions, cleaned_call_i) && haskey(defined_functions, cleaned_call_next)
        push!(uml, "    $transition")
        push!(added_transitions, transition)
      end
    end
  end

  push!(uml, "@enduml")
  save_uml_diagram(filepath, join(uml, "\n"))
  return join(uml, "\n")
end

function clean_state_name(name::String)::Tuple{String,String}
  cleaned_name = replace(name, r"[^\w]" => "_")
  if cleaned_name != name
    return ("\"$name\" as $cleaned_name", cleaned_name)
  else
    return (name, name)
  end
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