# Exporting and Importing snapshots

## Exporting

You can save a `Snapshot` to disk using the [`exportsnapshot`](@ref) function.
Please note that this function will make a copy of the `snapshot`, 
but also remove all connection between the JuMP `Model` and the copied `Snapshot`,
which is necessary to create a lightweight file.


## Importing

You can import a `Snapshot` from file using the [`importsnapshot`](@ref) function.
Please note that the imported `Snapshot` will not be associated with a JuMP `Model`.

Under the hood, exporting / importing relies on serialization: please do not import
a `Snapshot` that you have not exported yourself.