using CodeNavigator
using Test

dir = "testcode/"
file1 = joinpath(dir, "testcode1.jl")
file2 = joinpath(dir, "testcode2.jl")

@testset "analyze_function_calls 1" begin
  functions = analyze_function_calls(file1)
  @test all([f in keys(functions) for f in ["move_agent!", "remove_all!", "add_agent!", "nearby_positions", "nearby_agents", "random_nearby_agent"]])
  @test functions["move_agent!"] == ["remove_agent_from_space!", "add_agent_to_space!", "random_position"]
  @test all([f in functions["remove_all!"] for f in ["remove_all_from_space!", "remove_all_from_model!"]])
  @test all([f in functions["add_agent!"] for f in ["add_agent_own_pos!", "random_position", "add_agent_own_pos!", "agenttype"]])
  @test functions["nearby_positions"] == [] # self call is not included
  @test functions["nearby_agents"] == ["nearby_ids"]
  fcall_in_random_nearby_agent = ["nearby_ids", "itsample", "abmrng", "sampling_with_condition_single", "filter", "isnothing", "f", "AlgR"]
  @test_broken length(functions["random_nearby_agent"]) == length(fcall_in_random_nearby_agent) # all calls are included and no duplicates
  @test_broken all([f in functions["random_nearby_agent"] for f in fcall_in_random_nearby_agent])
end

@testset "analyze_function_calls 2" begin
  functions = analyze_function_calls(file2)
  @test_broken all([f in keys(functions) for f in ["to_discrete_position", "to_continuous_position", "sqr_distance", "find_continuous_path", "Agents.plan_route!", "walkable_cells_in_radius", "random_walkable"]])
  @test_broken all([f in keys(functions["to_discrete_position"]) for f in ["floor", "size", ".+", ".*", "./"]])
  @test_broken all([f in keys(functions["to_continuous_position"]) for f in ["size", ".+", ".*", "./"]])
  @test_broken all([f in keys(functions["sqr_distance"]) for f in ["abs", "sum", ".^", ".-", ":", "min"]])
  @test_broken all([f in keys(functions["find_continuous_path"]) for f in ["sqr_distance", "last", "push!", "≈", "Tuple", "to", "isempty", "to_discrete_position", "pop!", "to_continuous_position", "isnothing", "find_path", "<"]])
  @test_broken all([f in keys(functions["Agents.plan_route!"]) for f in ["find_continuous_path", "isnothing"]])
end
