"""
Component reserve metrics.
"""

"""
    reserve(c::Component, sense::Symbol, rname::String)

Return the reserve of Component `c` for the specified `sense` and `rname`.
`sense` is `:up` for upward reserve or `:down` for downward reserve.
"""
function reserve(c::Component{T}, sense::Symbol, rname::String) where T
    @argcheck (sense == :up || sense == :down) "reserve: sense must be :up or :down"
    
    result = Stepwise(differentzerovector(T, nsteps(mesh(c))), mesh(c))
    
    for b in getbehaviors(c, ReserveBehavior)
        b.rsense != sense && continue
        b.data.name == rname && (result .+= b.r)
    end
    
    return result
end
