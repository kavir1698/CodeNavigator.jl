module CodeNavigator

export analyze_function_calls, scan_julia_files_in_directory, create_uml_diagram
export get_ai_config, configure_ai

using PromptingTools
using PromptingTools.Experimental.AgentTools
using JSON
using YAML
using Glob

PT = PromptingTools
AT = PromptingTools.Experimental.AgentTools

include("create_diagram.jl")
include("aiconfig.jl")

function get_func_defs(code_content::String, config)

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
    You are a code analysis assistant specialized in identifying function calls within function definitions.

    TASK:
    Find ALL function calls that appear ONLY WITHIN THE BODY of the specified target function.
    DO NOT include calls from other functions or the global scope.

    ANALYSIS STEPS:
    1. First locate the target function's definition(s)
    2. Identify its body (code between the function definition and end)
    3. Only analyze calls within this specific scope
    4. List all function calls found within this scope

    SCOPE RULES:
    ✓ ONLY analyze code inside the target function's body
    ✗ IGNORE all code outside the target function
    ✗ IGNORE calls in other functions even if nested within target function
    ✗ IGNORE calls in the global scope


    INCLUDE these types of calls (if within target function):
    • Direct function calls: foo()
    • Method calls: obj.method()
    • Built-in function calls: print()
    • Nested function calls: foo(bar())
    • Operator calls when used as functions: +(a,b)
    • Chained calls: foo().bar()

    EXCLUDE:
    • Macro calls: @macro
    • Type constructors: MyType()
    • Function definitions
    • Function references without calls: map(func)
    • Any calls outside the target function's body

    OUTPUT FORMAT:
    • Return ONLY a comma-separated list of function names
    • No spaces after commas
    • No quotes, brackets, or other delimiters
    • No explanatory text
    • Example valid output: fib,readline,parse,vector_sum


    Example:
    ```julia
    function other_func()
        helper()  # IGNORE - outside target
    end

    function target_func()
        foo("hello")  # INCLUDE - foo
        x = helper()    # INCLUDE - helper
        if true
            foo(bar()) # INCLUDE - foo,bar
        end
    end

    sqrt(16)  # IGNORE - outside target
    ```
    For target_func, output would be: foo,helper,foo,bar

    Note: Return ONLY the comma-separated list, with no spaces after commas, no quotes, no additional text or formatting.
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
  AT.airetry!(x -> !isempty(AT.last_output(x)) && !occursin(":", AT.last_output(x)) && !occursin(".", AT.last_output(x)),
    result,
    "The result should only contain function names separated by commas")


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

function get_function_dict(filepath::String)
  if !isfile(filepath)
    error("File not found: $filepath")
  end

  content = read(filepath, String)
  if isempty(content)
    # println("Warning: File is empty")
    return Dict{String,Vector{String}}()
  end

  @info "Analyzing function calls in $filepath"
  config = get_ai_config()
  output = get_func_defs(content, config)
  response = AT.last_output(output)
  if isempty(response)
    println("No functions found in $filepath")
  end

  # parse the response into a list of function names
  function_names = split(response, ",")
  function_names = [strip(f) for f in function_names]
  function_names = unique(function_names)

  function_dict = Dict{String,Vector{String}}()
  for function_name in function_names
    function_dict[function_name] = []
  end
  for target_function in function_names
    @info "Analyzing function calls in $target_function"
    call_names = get_func_calls(content, target_function, config)
    if typeof(call_names) <: PromptingTools.Experimental.AgentTools.AICall
      # try again
      call_names = get_func_calls(content, target_function, config)
    end
    if typeof(call_names) <: PromptingTools.Experimental.AgentTools.AICall
      @warn "Failed to analyze function calls for $target_function"
    else
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