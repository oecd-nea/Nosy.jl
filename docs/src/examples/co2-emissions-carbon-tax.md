# CO2 Emissions And Carbon Tax

This example adds a CO2 carrier, a CO2 node, a linked CO2 emission flow, and a
carbon tax. The emission factor is 0.4 tCO2/MWh.



```jldoctest co2_emissions; output = false
julia> begin
           using Nosy
           using HiGHS
           import JuMP: set_silent
           s = Sim(Model(HiGHS.Optimizer); mesh=TimeMesh())
           set_silent(model(s))
           elec_carrier = EnergyCarrier("power", s)
           co2_carrier = CO2Carrier("co2", s)
           hours = 1:8760
           day_angle = 2pi .* ((hours .- 1) .% 24) ./ 24
           season_angle = 2pi .* (hours .- 1) ./ 8760
           load_profile = 3000 .+ 1500 .* sin.(day_angle .- pi / 2) .+
               120 .* sin.(season_angle .- pi / 2)
           snapshot = Snapshot(s)
           grid = Node("grid", elec_carrier, rule=:curtailed)
           co2_node = Node("co2", co2_carrier, rule=:curtailed)
           consumption = Component("consumption", Demand(elec_carrier, load_profile))
           connect!(snapshot, consumption, grid)
           gasplant = Component(
               "gasplant",
               DispatchableSource(elec_carrier),
               [
                   LinkedJointFlow("co2", co2_carrier, :output, "output", x -> 0.4 .* x[1]),
                   VariableCapacity("output", energy),
                   FixedCost(:capex, "output", energy, 60_000.0),
                   VariableCost(:fuel, "output", energy, 50.0),
                   VariableCost(:co2tax, "co2", co2, 100.0),
               ],
           )
           connect!(snapshot, gasplant, grid, "output")
           connect!(snapshot, gasplant, co2_node, "co2")
           optimize!(snapshot, cost(snapshot))
           result = extract(snapshot)
       end;

```

Expected results:

```jldoctest co2_emissions
julia> costs(result)
3×5 DataFrame
 Row │ component    capex    co2tax    fuel     total
     │ String       Float64  Float64   Float64  Float64
─────┼───────────────────────────────────────────────────
   1 │ consumption  0.0      0.0       0.0      0.0
   2 │ gasplant     2.772e8  1.0512e9  1.314e9  2.6424e9
   3 │ all          2.772e8  1.0512e9  1.314e9  2.6424e9

julia> balance(result, "gasplant", :output, co2; collapse=true, aggregate=true)
1.0512000000000114e7

julia> balance(result, "gasplant", :output, mass; collapse=true, aggregate=true)
1.0512000000000114e7
```
The CO2 flow is a normal port from the point of view of costs and balances. For
[`CO2Carrier`](@ref), `co2` and `mass` return the same physical quantity.
