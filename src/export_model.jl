

export export_model

_check_name(name) = Base.isidentifier(name) ? true : throw(ArgumentError("Model name must be a valid Julia identifier."))

"""
    export_model(model, name, file::IO)
    export_model(model, name, path::String)

Export the model into a module file. The `name` parameter is used for the name
of the module as well as the module file. The module file is created in the
directory specified by the optional third argument.
"""
function export_model(m::Model, name::AbstractString, path::AbstractString=".")
    if !endswith(path, ".jl")
        path = joinpath(path, name * ".jl")
    end
    open(path, "w") do fd
        export_model(m, name, IOContext(fd, :compact => false, :limit => false))
    end
    return nothing
end

function export_model(m::Model, name::AbstractString, fio::IO)
    _check_name(name)
    println(fio, "module ", name)
    println(fio)
    println(fio, "using ModelBaseEcon")
    println(fio)
    println(fio, "const model = Model()")
    println(fio)

    function _print_modified_options(opts, default, prefix)
        for (ok, ov) in pairs(opts)
            dv = getoption(default, ok, :not_a_default)
            if ov isa Options && dv isa Options
                _print_modified_options(ov, dv, prefix * "$ok.")
            elseif dv == :not_a_default || dv != ov
                println(fio, prefix, ok, " = ", ov)
            end
        end
    end

    println(fio, "# options")
    _print_modified_options(m.options, defaultoptions, "model.")
    println(fio)

    println(fio, "# flags")
    for fld in fieldnames(ModelFlags)
        fval = getfield(m.flags, fld)
        if fval != getfield(ModelFlags(), fld)
            println(fio, "model.", fld, " = ", fval)
        end
    end
    println(fio)

    if !isempty(parameters(m))
        println(fio, "@parameters model begin")
        for (n, p) in m.parameters
            println(fio, "    ", n, " = ", p)
        end
        println(fio, "end # parameters")
        println(fio)
    end

    if !isempty(variables(m))
        println(fio, "@variables model begin")
        for v in variables(m)
            println(fio, "    ", v)
        end
        println(fio, "end # variables")
        println(fio)
    end

    if !isempty(shocks(m))
        println(fio, "@shocks model begin")
        for v in shocks(m)
            println(fio, "    ", v)
        end
        println(fio, "end # shocks")
        println(fio)
    end

    if !isempty(m.autoexogenize)
        println(fio, "@autoexogenize model begin")
        for (k, v) in pairs(m.autoexogenize)
            println(fio, "    ", k, " = ", v)
        end
        println(fio, "end # autoexogenize")
        println(fio)
    end

    if !isempty(equations(m))
        println(fio, "@equations model begin")
        for eqn in equations(m)
            str = sprint(print, eqn, context=fio, sizehint=0)
            str = replace(str, r"(\s*\".*\"\s*)" => s"\1\\n    ")
            println(fio, "    ", unescape_string(str))
        end
        println(fio, "end # equations")
        println(fio)
    end

    println(fio, "@initialize model")

    sd = sstate(m)
    for cons in sd.constraints
        println(fio)
        println(fio, "@steadystate model ", cons)
    end

    println(fio)
    println(fio, "end # module ", name)
    println(fio)

    return nothing
end
