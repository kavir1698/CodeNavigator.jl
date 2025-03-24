module CodeNavigator

export get_function_dict, scan_julia_files_in_directory, create_uml_diagram, scan_julia_file
export get_function_definitions, get_function_calls, scan_julia_file

using JSON
using YAML
using Glob
using JuliaSyntax

include("create_diagram.jl")
include("parse_call_tree.jl")

end # module