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



macro ODE(∂::Vararg{Expr})
    dim = length(∂)

    # Check that ∂ is not used within the code
    @assert nor([occursin("∂", string(expr)) for expr in [∂x, ∂y, ∂z]]...) "Remove usage of ∂."
            
    symbols = Vector{Symbol}()

    for expression in ∂
        collectSymbols!(expression, symbols)
    end

    symbols = filter!(!Meta.isoperator, symbols)
    symbols = filter!(!isFunction, symbols)

    diff_symbols = Set{Symbol}([expr.args[1] for expr in ∂])
    dependent_vars = Set{Symbol}([Symbol(string(symbol)[end]) for symbol in diff_symbols])
    constants = setdiff(symbols, diff_symbols, dependent_vars)
    constants = [Expr(:(::), constant, :(Real)) for constant in constants]

    @assert length(dependent_vars) == dim

    quote
        function ODEFunc!(t::Real, u::Matrix{<:Real}, $(constants...))
            $(dependent_vars...) = eachrow(u)

            for equation in ∂
                $(@.(equation))
            end
        end

        ODEFunction(ODEFunc, 3)
    end 
end

macro ODE(derivatives)
    derivatives = filter(x -> !(x isa LineNumberNode), derivatives.args)
    # @assert length(derivatives) == 3 "Incorrected number of derivatives defined."
    @eval @ODE($(derivatives...))
end

end