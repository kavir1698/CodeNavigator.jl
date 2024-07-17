to_discrete_position(pos, pathfinder) =
  floor.(Int, pos ./ pathfinder.dims .* size(pathfinder.walkmap)) .+ 1  # function broadcasted
to_continuous_position(pos, pathfinder) =
  pos ./ size(pathfinder.walkmap) .* pathfinder.dims .-
  pathfinder.dims ./ size(pathfinder.walkmap) ./ 2.0
sqr_distance(from, to, pathfinder::AStar{D,true}) where {D} =
  sum(min.(abs.(from .- to), pathfinder.dims .- abs.(from .- to)) .^ 2)
sqr_distance(from, to, pathfinder::AStar{D,false}) where {D} =
  sum((from .- to) .^ 2)
@inline function sqr_distance(from, to, pathfinder::AStar{D,P}) where {D,P}
  s = pathfinder.dims
  delta = abs.(from .- to)
  sum(
    P[i] ? (min(delta[i], s[i] - delta[i]))^2 : delta[i]^2
    for i in 1:D
  )
end

"""
    find_continuous_path(pathfinder, from, to)
Functions like `find_path`, but uses the output of `find_path` and converts it to the coordinate
space used by the corresponding `ContinuousSpace`. Performs checks on the last two waypoints
in the discrete path to ensure continuous path is optimal.
"""
function find_continuous_path(
  pathfinder::AStar{D},
  from::Agents.ValidPos,
  to::Agents.ValidPos,
) where {D}
  discrete_from = Tuple(to_discrete_position(from, pathfinder))
  discrete_to = Tuple(to_discrete_position(to, pathfinder))
  discrete_path = find_path(pathfinder, discrete_from, discrete_to)
  # find_path returns nothing if no path exists
  isnothing(discrete_path) && return
  # if discrete_path is empty, `from` and `to` are in the same grid cell,
  # so `to` is the only waypoint
  isempty(discrete_path) && return Path{D,Float64}(Tuple(to))

  cts_path = Path{D,Float64}()
  for pos in discrete_path
    push!(cts_path, to_continuous_position(pos, pathfinder))
  end

  # Handles an edge case to prevent backtracking for a fraction of a grid cell
  # Consider case where each grid cell is (1., 1.), and the path is to be calculated from
  # (0.5, 0.5) to (0.5, 1.2). Without this, the resultant path would look like
  # [(0.5, 0.5), (0.5, 1.5), (0.5, 1.2)], causing the agent to go to the last waypoint and
  # then backtrack to the target
  last_pos = last(cts_path)
  pop!(cts_path)
  # It's possible there's only one waypoint in the path, in which case the second last
  # position is the starting position
  second_last_pos = isempty(cts_path) ? from : last(cts_path)
  last_to_end = sqr_distance(last_pos, to, pathfinder)
  second_last_to_end = sqr_distance(second_last_pos, to, pathfinder)
  if last_to_end < second_last_to_end
    push!(cts_path, last_pos)
  end
  # If `to` is already at the center of a grid cell, there's no need
  # to push it to the path
  last_to_end ≈ 0.0 || push!(cts_path, Tuple(to))
  return cts_path
end

function Agents.plan_route!(
  agent::AbstractAgent,
  dest::Agents.ValidPos,
  pathfinder::AStar{D,P,M,Float64},
) where {D,P,M}
  path = find_continuous_path(pathfinder, agent.pos, dest)
  isnothing(path) && return
  pathfinder.agent_paths[agent.id] = path
end

walkable_cells_in_radius(pos, r, pathfinder::AStar{D,false}) where {D} =
  Iterators.filter(
    x -> all(1 .<= x .<= size(pathfinder.walkmap)) &&
           pathfinder.walkmap[x...] &&
           sum(((x .- pos) ./ r) .^ 2) <= 1,
    Iterators.product([(pos[i]-r[i]):(pos[i]+r[i]) for i in 1:D]...)
  )

"""
    Pathfinding.random_walkable(pos, model::ABM{<:ContinuousSpace{D}}, pathfinder::AStar{D}, r = 1.0)
Return a random position within radius `r` of `pos` which is walkable, as specified by `pathfinder`.
Return `pos` if no such position exists.
"""
function random_walkable(
  pos::Agents.ValidPos,
  model::ABM{<:ContinuousSpace{D}},
  pathfinder::AStar{D},
  r=1.0,
) where {D}
  T = typeof(pos)
  discrete_r = to_discrete_position(r, pathfinder) .- 1
  discrete_pos = to_discrete_position(pos, pathfinder)
  options = collect(walkable_cells_in_radius(discrete_pos, discrete_r, pathfinder))
  isempty(options) && return pos
  discrete_rand = rand(
    abmrng(model),
    options
  )
  half_cell_size = abmspace(model).extent ./ size(pathfinder.walkmap) ./ 2.0
  cts_rand = to_continuous_position(discrete_rand, pathfinder) .+
             (T(rand(abmrng(model)) for _ in 1:D) .- 0.5) .* half_cell_size
  dist = euclidean_distance(pos, cts_rand, model)
  dist > r && (cts_rand = mod1.(
    pos .+ get_direction(pos, cts_rand, model) ./ dist .* r,
    abmspace(model).extent
  ))
  return cts_rand
end
