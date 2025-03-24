

function create_uml_diagram(functions_and_calls::Dict{String,Vector{String}}; filepath::String="code_diagram.uml")
  uml = ["@startuml"]
  added_transitions = Set{String}()  # Tracks added transitions to avoid duplicates

  # Create major states for each function
  for (func, calls) in functions_and_calls
    original_name, cleaned_func = clean_state_name(func)
    push!(uml, "state $cleaned_func {")
    
    # Add inner states for each unique call
    for call in unique(calls)
      original_call_name, cleaned_call_name = clean_state_name(call)
      push!(uml, "    state $cleaned_call_name")
    end
    
    push!(uml, "}")
  end

  # Add transitions between major states
  for (func, calls) in functions_and_calls
    _, cleaned_func = clean_state_name(func)
    for call in calls
      _, cleaned_call = clean_state_name(call)
      if haskey(functions_and_calls, call)  # Only connect to other major states
        transition = "$cleaned_func --> $cleaned_call"
        if !in(transition, added_transitions)
          push!(uml, transition)
          push!(added_transitions, transition)
        end
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


# using Graphs
# using GraphViz
# using GraphPlot
# using Cairo
# using Compose

# function create_call_graph(functions_and_calls::Dict{String,Vector{String}})
#     # Create a mapping of function names to vertex indices
#     all_functions = Set{String}()
#     for (func, calls) in functions_and_calls
#         push!(all_functions, func)
#         union!(all_functions, calls)
#     end
    
#     name_to_vertex = Dict(name => i for (i, name) in enumerate(all_functions))
#     vertex_to_name = Dict(i => name for (name, i) in name_to_vertex)
    
#     # Create a directed graph with vertices for each function
#     g = SimpleDiGraph(length(all_functions))
    
#     # Add edges based on function calls
#     for (func, calls) in functions_and_calls
#         from_vertex = name_to_vertex[func]
#         for called_func in calls
#             to_vertex = name_to_vertex[called_func]
#             add_edge!(g, from_vertex, to_vertex)
#         end
#     end
    
#     return g, name_to_vertex, vertex_to_name
# end

# function plot_call_graph(g::SimpleDiGraph, vertex_to_name::Dict{Int, String}; 
#                         output_path::String="call_graph.png")
#     # Create labels for the vertices
#     labels = [vertex_to_name[i] for i in 1:nv(g)]
    
#     # Use GraphViz for hierarchical layout
#     layout = spring_layout(g)
#     gv = GraphViz.Graph(directed=true)
    
#     # Add nodes and edges to GraphViz
#     for v in vertices(g)
#         GraphViz.add_node!(gv, string(v))
#     end
    
#     for e in edges(g)
#         GraphViz.add_edge!(gv, string(src(e)), string(dst(e)))
#     end
    
#     # Apply hierarchical layout
#     GraphViz.layout!(gv, :dot)
    
#     # Extract positions from GraphViz layout
#     pos_x = zeros(nv(g))
#     pos_y = zeros(nv(g))
#     for (i, node) in enumerate(GraphViz.nodes(gv))
#         pos_x[i] = node.pos.x
#         pos_y[i] = node.pos.y
#     end
    
#     # Create the plot
#     draw(PNG(output_path, 16inch, 16inch), gplot(g,
#         pos_x, pos_y,
#         nodelabel=labels,
#         NODESIZE=0.2,
#         NODELABELSIZE=5,
#         ARROWLENGTH=0.2,
#         edgelinewidth=0.5))
    
#     return output_path
# end

