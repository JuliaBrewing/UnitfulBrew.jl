__precompile__(true)
"""
    UnitfulBrew

Module extending Unitful.jl with beer brewing units.
"""
module UnitfulBrew

using Unitful
#using UnitfulEquivalences
using UnitfulEquivalences: dimtype, @equivalence
import UnitfulEquivalences: edconvert

export Brewing

# New dimensions
@dimension 𝐂    "C"     Color
@dimension 𝐃    "𝐃"     DiastaticPower
@dimension 𝐁    "𝐁"     Bitterness
@dimension 𝐏    "𝐏"     SugarContents

# Time units: adding beerjson symbols as alias to Unitful symbols
const sec = Unitful.s
const min = Unitful.minute
const day = Unitful.d
const week = Unitful.wk

# US Volumes
@unit gal       "gal"       Gallon      231*(Unitful.inch)^3    false
@unit qt        "qt"        Quart       gal//4                  false
@unit pt        "pt"        Pint        qt//2                   false
@unit cup       "cup"       Cup         pt//2                   false
@unit floz      "floz"      FluidOunce  pt//16                  false
@unit tbsp      "tbsp"      Tablespoon  floz//2                 false
@unit tsp       "tsp"       Teaspoon    tbsp//3                 false
@unit bbl       "bbl"       Barrel      42gal                   false

# Imperial Volumes
@unit ifloz     "ifloz"     ImperialFluidOunce  28.4130625*(Unitful.mm) false
@unit gi        "gi"        Gill                5ifloz                  false
@unit ipt       "ipt"       ImperialPint        20ifloz                 false
@unit iqt       "iqt"       ImperialQuart       2ipt                    false
@unit igal      "igal"      ImperialGallon      8ipt                    false
@unit ibbl      "ibbl"      ImperialBarrel      36igal                  false

# Sugar content
@refunit °P     "°P"        Plato               𝐏           false
@unit Brix      "Brix"      Brix                1°P         false
@unit Balling   "Balling"   Balling             1°P         false

# Specific gravity
# uconvert(Unitful.NoUnits, 1.010u"sg") == 1.01
# uconvert(u"permille", 1.040u"sg") == 1040.0 ‰
# uconvert(u"gu", 1.040u"sg") == 40.0 gu
# uconvert(u"sg", 40u"gu") == 1.04 sg
@unit       sg  "sg"        SpecificGravity     1.0         false
@affineunit gu  "gu"        1000.0 * Unitful.permille
const gp = gu # gravity points

# Diastatic Power
@refunit        °Lintner    "°Lintner"  Lintner     𝐃                   false
@unit           °WK_aux     "°WK_aux"   WK_aux      (10//35)°Lintner    false
@affineunit     °WK         "°WK"       16°WK_aux
const Lintner = °Lintner

# Color units
@refunit    SRM     "SRM"       SRM                 𝐂               false
@unit       °L      "°L"        Lovibond            1SRM            false
@unit       EBC     "EBC"       EBC                 (197//100)SRM   false
const srm = SRM
const Lovi = °L
const ebc = EBC

# Carbonation units

# International Bitterness Unit

@refunit    IBU     "IBU"       InternationalBitternessUnit 𝐁       false

# Concentration units
#=
Unitful already has percent, permille and pertenthousand,
so we only add ppm, ppb, and ppt
@unit percent         "%"    Percent         1//100             false
@unit permille        "‰"    Permille        1//1000            false
@unit pertenthousand  "‱"    Pertenthousand  1//10000           false
=#
@unit       ppm     "ppm"       PartsPerMillion     1//10^6         false
@unit       ppb     "ppb"       PartsPerBillion     1//10^9         false
@unit       ppt     "ppt"       PartsPerTrillion    1//10^9         false

# pH logarithmic scale
@logscale pH⁺    "pH⁺"       powerofHydrogen      10      10      false
const pwrH = pH⁺ # either pH\^+<ESC> or, with dead keys, pH\^<SPACE>+<ESC>
#=
Using symbols pwrH and pH⁺ since there is a dimensional symbol pH already defined in Unitful:
```julia-repl
julia> typeof(Unitful.pH)
Unitful.FreeUnits{(pH,),𝐋² 𝐌 𝐈⁻² 𝐓⁻²,nothing}
```
=#

## Define the conversion functions between Plato and gravity units
"""
    gu_to_plato(gu::Number)

Convert a value in Gravity Units to degrees Plato according
to the quadratic formula

    Plato = 0.25802gu - 0.00020535gu^2,

which is equivalent to the formula for specific gravity

    Plato = 668.72 * sg - 463.37 - 205.35 * sg^2,

with
    gu = 1000 ( sg - 1.000 ).
"""
gu_to_plato(gu::Number) = 0.25802gu - 0.00020535gu^2

"""
    plato_to_gu(p::Number)

Convert a value in degrees Plato to Gravity Units by inverting the quadratic
formula for degrees Plato, so that

    gu = e - sqrt(e^2 - g * Plato)) if ^2 - g * p >= 0 else gu = e

where 
    e = 0.25802 / 0.00020535 / 2 = 628.2444606768931
and 
    g = 1 / 0.00020535 = 4869.734599464329

The value gu = d when p > d/2 is just for definiteness of the function since
the in this range the conversion is meaningless.
"""
function plato_to_gu(p::Number)
    e = 628.2444606768931
    g = 4869.734599464329
    d = e^2 - g*p
    if d >= 0
        e - sqrt(d)
    else
        e
    end
end

# Define the equivalences

_eqconversion_error(v, u, e) = error("$e does not define conversion from $u to $v")

"""
    Brewing()

Equivalence to convert brewing related quantities.

* Convert between Density and NoDims according to a linear relation with 1u"mg/L" equivalent to 1u"ppm"

* Convert between degrees Plato and specific gravity (need to include gravity points, as well)

# Examples

```jldoctest
julia> uconvert(u"mg/l", 10u"ppm", Brewing())
10 mg L⁻¹
julia> uconvert(u"ppm", 1u"g/l", Brewing())
1000 ppm
julia> uconvert(u"°P", 1.040u"sg", Brewing())
9.992240000000066 °P
julia> uconvert(u"sg", 15u"°P", Brewing())
1.0611068377146742 sg
```
"""
@equivalence Brewing

edconvert(d::dimtype(Unitful.Density), x::Unitful.Quantity{T,D,U}, e::Brewing) where {T,D,U} = D == Unitful.NoDims ? x * 1u"kg/L" : throw(_eqconversion_error(d, D, e))

#edconvert(::Unitful.Dimensions{()}, x::UnitfulBrew.SugarContents, ::Brewing) = plato_to_gu(x.val) * UnitfulBrew.gu

# edconvert(::dimtype(SugarContents), x::Unitful.NoUnits, ::Brewing) = gu_to_plato(uconvert(UnitfulBrew.gu, x).val) * UnitfulBrew.°P

function edconvert(d::dimtype(SugarContents), x::Unitful.Quantity{T,D,U}, e::Brewing) where {T,D,U} 
    if D == NoDims
        gu_to_plato(uconvert(UnitfulBrew.gu, x).val) * UnitfulBrew.°P
    else
        throw(_eqconversion_error(d, D, e))
    end
end

function edconvert(d::Unitful.Dimensions{()}, x::Unitful.Quantity{T,D,U}, e::Brewing) where {T,D,U} 
    if D == UnitfulBrew.𝐏
        plato_to_gu(uconvert(UnitfulBrew.°P, x).val) * UnitfulBrew.gu
    elseif D == Unitful.𝐌/Unitful.𝐋^3
        x * 1u"L/kg" # Density to parts per (e.g. 1u"ppm" = 1u"mg/l")
    else
        throw(_eqconversion_error(d, D, e))
    end
end

# The function below is just so I get things straight
function show_quantity_info(x::Quantity{T,D,U}) where {T,D,U}
    println("Here is the result of (T, D, U, U()) for $x:")
    return T, D, U, U()
end

# Register the above units and dimensions in Unitful
__init__() = Unitful.register(UnitfulBrew)

end # module