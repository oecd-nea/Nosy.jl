# API Reference

This page groups the public API exported by Nosy. For a narrative introduction,
see [Modelling Concepts](@ref) and [Examples](@ref).

## Simulation And Optimisation

```@docs
TimeMesh
Sim
sim
model
lowermodel
uppermodel
Snapshot
finalize!
optimize!
extract
conflicts
```

## Carriers And Modifiers

```@docs
EnergyCarrier
MassCarrier
CO2Carrier
PowerCarrier
energy
mass
co2
```

## Nodes, Components, And Connections

```@docs
Node
Component
connect!
tag!
hastag
getnodes
getcomponents
```

## Model Archetypes

```@docs
DispatchableSource
ProfileSource
Demand
BasicSink
BasicConverter
BasicStorage
LazyStorage
ACLine
DCLine
```

## Behaviors

```@docs
FixedCapacity
VariableCapacity
FixedComposedCapacity
VariableComposedCapacity
CapacityMultiplier
Duration
YearlySum
Ramping
ReserveUp
ReserveDown
UnitCommitment
FixedCost
VariableCost
NoLoadCost
StartupCost
```

## Joint Flows

```@docs
FixedJointFlow
FreeJointFlow
LinkedJointFlow
```

## Balance

```@docs
balance
```

## Metrics And Post-Processing

```@docs
capacity
nbunits
cost
fixedcost
variablecost
noloadcost
startupcost
reserve
costs
table
dualprice
```
