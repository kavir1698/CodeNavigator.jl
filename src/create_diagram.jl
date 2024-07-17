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

function save_uml_diagram(filepath::String, uml::String)
  open(filepath, "w") do f
    write(f, uml)
  end
end

function clean_state_name(name::String)::Tuple{String,String}
  cleaned_name = replace(name, r"[^\w]" => "_")
  if cleaned_name != name
    return ("\"$name\" as $cleaned_name", cleaned_name)
  else
    return (name, name)
  end
end