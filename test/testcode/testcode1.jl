"""
    random_position(model) → pos

Return a random position in the model's space (always with appropriate Type).
"""
random_position(model) = notimplemented(model)

is_stationary(agent, model) = notimplemented(model)

"""
    move_agent!(agent [, pos], model::ABM) → agent

Move agent to the given position, or to a random one if a position is not given.
`pos` must have the appropriate position type depending on the space type.

The agent's position is updated to match `pos` after the move.
"""
function move_agent!(agent::AbstractAgent, pos::ValidPos, model::ABM)
  remove_agent_from_space!(agent, model)
  agent.pos = pos
  add_agent_to_space!(agent, model)
  return agent
end
function move_agent!(agent, model::ABM)
  move_agent!(agent, random_position(model), model)
end

function remove_all!(model::ABM)
  remove_all_from_space!(model)
  remove_all_from_model!(model)
  getfield(model, :maxid)[] = 0
end

"""
    add_agent!(agent::AbstractAgent [, pos], model::ABM) → agent

Add the `agent` to the model in the given position.
If `pos` is not given, the `agent` is added to a random position.
The `agent`'s position is always updated to match `position`, and therefore for `add_agent!`
the position of the `agent` is meaningless. Use [`add_agent_own_pos!`](@ref) to use
the `agent`'s position.
The type of `pos` must match the underlying space position type.
"""
function add_agent!(agent::AbstractAgent, model::ABM)
  agent.pos = random_position(model)
  add_agent_own_pos!(agent, model)
end

function add_agent!(agent::AbstractAgent, pos::ValidPos, model::ABM)
  agent.pos = pos
  add_agent_own_pos!(agent, model)
end

function add_agent!(
  pos::ValidPos,
  model::ABM,
  args::Vararg{Any,N};
  kwargs...,
) where {N}
  A = agenttype(model)
  add_agent!(pos, A, model, args...; kwargs...)
end

# A second method of an inline function
function nearby_positions(agent::AbstractAgent, model::ABM, r=1; kwargs...)
  nearby_positions(agent.pos, model, r; kwargs...)
end

# Inline function in two lines

nearby_agents(a, model, r=1; kwargs...) =
  (model[id] for id in nearby_ids(a, model, r; kwargs...))

function random_nearby_agent(a, model, r=1, f=nothing, alloc=false; kwargs...)
  iter_ids = nearby_ids(a, model, r; kwargs...)
  if isnothing(f)
    id = itsample(abmrng(model), iter_ids, StreamSampling.AlgR())
  else
    if alloc
      id = sampling_with_condition_single(iter_ids, f, model, id -> model[id])
    else
      iter_filtered = Iterators.filter(id -> f(model[id]), iter_ids)
      id = itsample(abmrng(model), iter_filtered, StreamSampling.AlgR())
    end
  end
  isnothing(id) && return nothing
  return model[id]
end
