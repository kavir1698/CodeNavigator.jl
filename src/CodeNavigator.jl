module CodeNavigator

export get_function_dict, scan_julia_files_in_directory, create_uml_diagram
export get_ai_config, configure_ai
export get_func_names, get_func_definition

using PromptingTools
using PromptingTools.Experimental.AgentTools
using JSON
using YAML
using Glob

PT = PromptingTools
AT = PromptingTools.Experimental.AgentTools

include("create_diagram.jl")
include("aiconfig.jl")

function get_func_names(code_content::String, config)

  ptext = """
  Extract all function names defined in the provided code and return them as a single comma-separated list.

    Rules:
    1. Include:
      - Standard function definitions
      - Compact function definitions
      - Method overloads (list base name only once)
      
      2. Exclude:
      - Anonymous functions
      - Macro names
      - Function names from imports/using statements
      - Type constructors

    Output format: name1,name2,name3

    Note: Return ONLY the comma-separated list, with no spaces after commas, no quotes, no additional text or formatting.
  """

  prompt = [
    PT.SystemMessage(ptext),
    PT.UserMessage("Code contents:\n```julia\n$code_content\n```")
  ]

  analysis_call = AT.AIGenerate(config.schema, prompt; config.base_config...)
  result = AT.run!(analysis_call)

  # check if the result has any explanations other than the function names
  AT.airetry!(x -> !isempty(AT.last_output(x)) && !occursin(":", AT.last_output(x)) && !occursin(".", AT.last_output(x)),
    result,
    "The result should only contain function names separated by commas")


  return result
end

function get_func_calls(code_content, target_function, config)

  ptext = """
    You are a code analyzer that finds function calls within function definitions.

    TASK:
    List ALL function calls that occur ONLY WITHIN the target function's body.
    Exclude calls from outside the target function's scope.

    OUTPUT:
    Return only comma-separated function names without spaces/quotes/brackets.
    Example: fib,readline,parse,sum
    If there is only one function call, return it as a single name without commas. If there are no calls, return an empty string.
    """

  prompt = [
    PT.SystemMessage(ptext),
    PT.UserMessage("""
    Function to analyze: `$target_function`

    Code contents:
    ```julia
    $code_content
    ```
    """)
  ]

  analysis_call = AT.AIGenerate(config.schema, prompt; config.base_config...)
  result = AT.run!(analysis_call)

  # check if the result has any explanations other than the function names
  AT.airetry!(x -> !isempty(AT.last_output(x)) && !occursin(":", AT.last_output(x)) && !occursin(". ", AT.last_output(x)) && !occursin(";", AT.last_output(x)) && !occursin(r"\.\s*$", AT.last_output(x)),
    result,
    "The result should only contain function names separated by commas without any additional text and explanations!")

  return result
end

function get_called_functions(code_content, target_function, config)
  output = get_func_calls(code_content, target_function, config)
  response = AT.last_output(output)
  # parse the response into a list of function names
  call_names = split(response, ",")
  call_names = [strip(f) for f in call_names]
  call_names = unique(call_names)
  return call_names
end

function get_func_definition(code_content::String, target_function::AbstractString, config)
  ptext = """
  Extract the complete function definition(s) for the specified target function from the provided code.
  Include all method definitions if there are multiple.
  
  Rules:
  1. Return only the function definition(s), including the body
  2. Exclude any docstrings or comments
  3. Preserve exact indentation
  4. If multiple method definitions exist, include all of them
  
  Output format: Return only the raw function definition(s), no additional text or formatting.
  """

  prompt = [
    PT.SystemMessage(ptext),
    PT.UserMessage("""
    Function to extract: `$target_function`
    
    Code contents:
    ```julia
    $code_content
    ```
    """)
  ]

  analysis_call = AT.AIGenerate(config.schema, prompt; config.base_config...)
  result = AT.run!(analysis_call)
  
  return AT.last_output(result)
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
  config = get_ai_config()
  output = get_func_names(content, config)
  response = AT.last_output(output)
  if isempty(response)
    println("No functions found in $filepath")
  end

  function_names = split(response, ",")
  function_names = [strip(f) for f in function_names]
  function_names = unique(function_names)

  function_dict = Dict{String,Vector{String}}()
  for function_name in function_names
    function_dict[function_name] = []
  end
  
  for target_function in function_names
    @info "Analyzing function calls in $target_function"
    # First get the function definition
    func_def = get_func_definition(content, target_function, config)
    # Then analyze calls within this definition
    call_names = get_func_calls(func_def, target_function, config)
    if !call_names.success
      # try again
      func_def = get_func_definition(content, target_function, config)
      call_names = get_func_calls(func_def, target_function, config)
    end
    if !call_names.success
      @warn "Failed to analyze function calls for $target_function"
    else
      # parse the response into a list of function names
      response = AT.last_output(call_names)
      call_names = split(response, ",")
      call_names = [strip(f) for f in call_names]
      call_names = unique(call_names)
      function_dict[target_function] = call_names
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

end # module