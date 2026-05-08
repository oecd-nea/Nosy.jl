using Documenter
using Nosy

DocMeta.setdocmeta!(Nosy, :DocTestSetup, :(using Nosy); recursive=true)

doctest_setting = get(ENV, "DOCUMENTER_DOCTEST", "true")
doctest_value = doctest_setting == "fix" ? :fix : parse(Bool, doctest_setting)

makedocs(
    modules=[Nosy],
    sitename="Nosy.jl",
    authors="Guillaume KRIVTCHIK, OECD Nuclear Energy Agency, and contributors",
    repo="https://github.com/oecd-nea/Nosy.jl/blob/{commit}{path}#L{line}",
    format=Documenter.HTML(
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://oecd-nea.github.io/Nosy.jl/stable/",
        repolink="https://github.com/oecd-nea/Nosy.jl",
        assets=String[],
        edit_link="main",
    ),
    pages=[
        "Home" => "index.md",
        "Getting Started" => "getting-started.md",
        "Modelling Concepts" => [
            "Overview" => "concepts.md",
            "Building a Snapshot" => "concepts/building-snapshot.md",
            "Optimizing a Snapshot" => "concepts/optimizing.md",
            "Querying a Snapshot" => "concepts/querying.md",
        ],
        "Performance" => "performance.md",
        "Examples" => [
            "Overview" => "examples.md",
            "Dispatchable Source And Demand" => "examples/dispatchable-source-demand.md",
            "Unit Commitment" => "examples/unit-commitment.md",
            "CO2 Emissions And Carbon Tax" => "examples/co2-emissions-carbon-tax.md",
            "PV And Battery Storage" => "examples/pv-battery-storage.md",
            "Linked Capacities" => "examples/linked-capacities.md",
            "Two Power Nodes" => "examples/two-power-nodes.md",
            "Power And Hydrogen Demand" => "examples/power-hydrogen-demand.md",
            "Combined Heat And Power" => "examples/combined-heat-power.md",
            "Operating Reserve" => "examples/operating-reserve.md",
            "PV, Battery, And Upward Reserve" => "examples/pv-battery-upward-reserve.md",
            "Infeasibility And Conflicts" => "examples/infeasibility-conflicts.md",
            "Alternative Objectives" => "examples/alternative-objectives.md",
            "Single-Level Vs Bilevel Capacity Expansion And Dispatch" =>
                "examples/bilevel-capacity-expansion-dispatch.md",
        ],
        "API Reference" => "api.md",
    ],
    doctest=doctest_value,
    checkdocs=:exports,
)

if get(ENV, "CI", "false") == "true"
    deploydocs(
        repo="github.com/oecd-nea/Nosy.jl.git",
        devbranch="main",
        push_preview=true,
    )
end
