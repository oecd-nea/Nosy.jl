using Test
using JuMP: Model
import JuMP
using Nosy: Sim, TimeMesh, sim
using Nosy: PowerCarrier, MassCarrier, Node
using Nosy: ACLine, DCLine, ACLineModel, DCLineModel
using Nosy: _input, _output, PortRef, _getport, hasport
using Nosy: build  


tsim() = Sim(Model(), mesh=TimeMesh(fill(1//1, 10)))

@testset "ACLine" begin

    # check port exposure, carrier/sim consistency, and parameter validation
    let 
        s = tsim()
        pc = PowerCarrier("electricity", s)
        n1 = Node("n1", pc; losses=0.0, rule=:default, evalprice=false, tags=Symbol[])
        n2 = Node("n2", pc; losses=0.0, rule=:default, evalprice=false, tags=Symbol[])

        acdata = ACLine(pc, pc, 0.1)
        acmodel = build(acdata, "acline")

        # model type
        @test isa(acmodel, ACLineModel)

        # Convention: net(from->to) = from_out − to_out (f_ft − f_tf)
        @test hasport(acmodel.s, "from_in", "acline")
        @test hasport(acmodel.s, "from_out", "acline")
        @test hasport(acmodel.s, "to_in", "acline")
        @test hasport(acmodel.s, "to_out", "acline")

        in_keys  = Set(collect(keys(_input(acmodel.s).d)))
        out_keys = Set(collect(keys(_output(acmodel.s).d)))
        @test in_keys  == Set([PortRef("acline","from_in"), PortRef("acline","to_in")])
        @test out_keys == Set([PortRef("acline","from_out"), PortRef("acline","to_out")])

        # carrier/sim consistency
        p_from_out = _getport(acmodel.s, "from_out", "acline", :output)
        p_from_in = _getport(acmodel.s, "from_in", "acline", :input)
        p_to_in = _getport(acmodel.s, "to_in", "acline", :input)
        p_to_out = _getport(acmodel.s, "to_out", "acline", :output)
        @test p_from_out.carrier === pc
        @test p_to_out.carrier === pc
        @test sim(acmodel.s) === s

        vars = JuMP.all_variables(s.model)
        @test length(vars) == 10
        @test JuMP.coefficient(p_from_out.series[1], vars[1]) == 1.0
        @test JuMP.coefficient(p_to_out.series[1], vars[1]) == -1.0
        @test iszero(p_from_in.series[1])
        @test iszero(p_to_in.series[1])

        # parameter validation (B>0)
        @test_throws ArgumentError ACLine(pc, pc, 0.0)
        @test_throws ArgumentError ACLine(pc, pc, -0.5)
    end

    # type safety: carriers must match PowerCarrier only
    let 
        s = tsim()
        pc = PowerCarrier("electricity", s)
        mc = MassCarrier("mc", s)

        @test_throws MethodError ACLine(pc, mc, 0.1)
        @test_throws MethodError ACLine(mc, pc, 0.1)
    end
end    

@testset "DCLine" begin

    # check port exposure, carrier/sim consistency, and parameter validation
    let 
        s = tsim()
        pc = PowerCarrier("electricity", s)
        n1 = Node("n1", pc; losses=0.0, rule=:default, evalprice=false, tags=Symbol[])
        n2 = Node("n2", pc; losses=0.0, rule=:default, evalprice=false, tags=Symbol[])

        dcdata  = DCLine(pc, pc)
        dcmodel = build(dcdata, "dcline")

        # model type
        @test isa(dcmodel, DCLineModel)

        # Convention: net(from->to) = from_out − to_out (f_ft − f_tf)
        @test hasport(dcmodel.s, "from_in", "dcline")
        @test hasport(dcmodel.s, "from_out", "dcline")
        @test hasport(dcmodel.s, "to_in", "dcline")
        @test hasport(dcmodel.s, "to_out", "dcline")

        in_keys  = Set(collect(keys(_input(dcmodel.s).d)))
        out_keys = Set(collect(keys(_output(dcmodel.s).d)))
        @test in_keys  == Set([PortRef("dcline","from_in"), PortRef("dcline","to_in")])
        @test out_keys == Set([PortRef("dcline","from_out"), PortRef("dcline","to_out")])

        # carrier/sim consistency
        p_from_out = _getport(dcmodel.s, "from_out", "dcline", :output)
        p_from_in = _getport(dcmodel.s, "from_in", "dcline", :input)
        p_to_in = _getport(dcmodel.s, "to_in", "dcline", :input)
        p_to_out = _getport(dcmodel.s, "to_out", "dcline", :output)
        @test p_from_out.carrier === pc
        @test p_to_out.carrier   === pc
        @test sim(dcmodel.s) === s

        vars = JuMP.all_variables(s.model)
        @test length(vars) == 10
        @test JuMP.coefficient(p_from_out.series[1], vars[1]) == 1.0
        @test JuMP.coefficient(p_to_out.series[1], vars[1]) == -1.0
        @test iszero(p_from_in.series[1])
        @test iszero(p_to_in.series[1])
    end
    
    # type safety: carriers must match PowerCarrier only
    let 
        s = tsim()
        pc = PowerCarrier("electricity", s)
        mc = MassCarrier("mc", s)

        @test_throws MethodError DCLine(pc, mc)
        @test_throws MethodError DCLine(mc, pc)
    end
end
