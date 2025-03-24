# create a syntax tree from a julia file (includes multiple functions)
using JuliaSyntax

f = "src/create_AD_table.jl"
code = read(f, String)

# Parse the code into a syntax tree
expr = JuliaSyntax.parseall(Expr, code)

function print_syntax_tree(node, level=0)
  indent = "  "^level

  if node isa Expr
    println(indent, "└─ ", node.head)
    for arg in node.args
      print_syntax_tree(arg, level + 1)
    end
  else
    println(indent, "└─ ", node)
  end
end

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

print_syntax_tree(expr)
println("\nDefined functions:")
for func in get_function_definitions(expr)
    println("- ", func)
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

println("\nFunction analysis:")
for func_name in get_function_definitions(expr)
    func_node = find_function_node(expr, func_name)
    if func_node !== nothing
        println("\nFunction: ", func_name)
        println("Calls:")
        for call in get_function_calls(func_node.args[2])
            println("  - ", call)
        end
    end
end

