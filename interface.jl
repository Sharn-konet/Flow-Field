module Interface

function collectSymbols!(expression::Expr, symbols::Vector{Symbol})
    for arg in expression.args
        if hasproperty(arg, :args)
            collectSymbols!(arg, symbols)
        else
            push!(symbols, arg)
        end
    end
end

function isFunction(symbol::Symbol)
    if isdefined(Main, symbol)
        return isa(getfield(Main, symbol), Function)
    end
    return false
end

struct ODEFunction <: Function
    func::Function
    dimensions::Int8
end

ODEFunction(args...) = ODEFunction.func(args...)


macro ODE(∂x::Expr, ∂y::Expr, ∂z::Expr)

    # Check that ∂ is not used within the code
    @assert nor([occursin("∂", string(expr)) for expr in [∂x, ∂y, ∂z]]...) "Remove usage of ∂."
            
    symbols = Vector{Symbol}()

    for expression in (∂x, ∂y, ∂z)
        collectSymbols!(expression, symbols)
    end

    symbols = filter!(!Meta.isoperator, symbols)
    symbols = filter!(!isFunction, symbols)

    diff_symbols = Vector{Symbol}([expr.args[1] for expr in [∂x, ∂y, ∂z]])
    dependent_vars = Vector{Symbol}([Symbol(string(symbol)[end]) for symbol in diff_symbols])
    constants = setdiff(symbols, diff_symbols, dependent_vars)
    constants = [Expr(:(::), constant, :(Real)) for constant in constants]

    initialisation = [:($symbol = Vector{Float64}(undef, 3)) for symbol in diff_symbols]

    func = quote
        function ODEFunc(t::Real, u::Matrix{<:Real}; $(constants...))

            x, y, z = eachrow(u)

            $(initialisation...)

            $(var"@__dot__"(LineNumberNode(1), Main, ∂x).args[1])
            $(var"@__dot__"(LineNumberNode(1), Main, ∂y).args[1])
            $(var"@__dot__"(LineNumberNode(1), Main, ∂z).args[1])

            return $(diff_symbols...)
        end

        ODEFunction(ODEFunc, 3)
    end

    @show func

    return func
end

macro ODE(∂x::Expr, ∂y::Expr)

    # Check that ∂ is not used within the code
    @assert nor([occursin("∂", string(expr)) for expr in [∂x, ∂y]]...) "Remove usage of ∂."
            
    symbols = Vector{Symbol}()

    for expression in (∂x, ∂y)
        collectSymbols!(expression, symbols)
    end

    symbols = filter!(!Meta.isoperator, symbols)
    symbols = filter!(!isFunction, symbols)

    diff_symbols = Set{Symbol}([expr.args[1] for expr in [∂x, ∂y]])
    dependent_vars = Set{Symbol}([Symbol(string(symbol)[end]) for symbol in diff_symbols])
    constants = setdiff(symbols, diff_symbols, dependent_vars)
    constants = [Expr(:(::), constant, :(Real)) for constant in constants]

    quote
        function ODEFunc(t::Real, u::Matrix{<:Real}; $(constants...))

            x, y = u[1,:], u[2,:]
        
            $(@.(∂x))
            $(@.(∂y))

            return $(diff_symbols...)
        end

        ODEFunction(ODEFunc, 2)
    end 
end

macro ODE(derivatives)
    derivatives = filter(x -> !(x isa LineNumberNode), derivatives.args)
    # @assert length(derivatives) == 3 "Incorrected number of derivatives defined."
    @eval @ODE($(derivatives...))
end

end