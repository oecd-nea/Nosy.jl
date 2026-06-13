# Exporting and Importing snapshots

## Exporting

You can save a `Snapshot` to disk using the [`exportsnapshot`](@ref) function.
Please note that this function will serialize the `snapshot`, 
but also remove the JuMP `Model` from the `Snapshot`, 
which is necessary to create a lightweight file.


## Importing

You can import a `Snapshot` from file using the [`importsnapshot`](@ref) function.
Please note that the imported `Snapshot` will not be associated with a JuMP `Model`.

Under the hood, exporting / importing relies on serialization: please do not import
a `Snapshot` that you have not exported yourself.