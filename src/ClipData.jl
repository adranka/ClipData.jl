module ClipData

using CSV, Tables

using InteractiveUtils: clipboard

export cliptable, cliparray, mwetable, mwearray, @mwetable, @mwearray

# Every `mwetable`/`mwearray` method ends the same way: hand back the generated
# code, or print it to `io`.
@inline function mwestring(io, s, returnstring)
    if returnstring == true
        return s
    else
        print(io, s)
        return nothing
    end
end

function clipstring(s, returnstring)
    clipboard(s)
    if returnstring == true
        return String(s)
    else
        return nothing
    end
end

function checkname(name)
    Base.isidentifier(name) || throw(ArgumentError(
        "`name` must be a valid Julia identifier, got `$name`."))
    return name
end

function escapepayload(s)
    if occursin('\\', s) || occursin('$', s) || occursin("\"\"\"", s)
        s = replace(s, "\\" => "\\\\")
        s = replace(s, "\$" => "\\\$")
        s = replace(s, "\"" => "\\\"")
    end
    return s
end

# `CSV.write` terminates the last row with `newline`; the clipboard should not
# carry that trailing separator.
function chopnewline(s, newline)
    nl = string(newline)
    endswith(s, nl) ? chop(s, tail = length(nl)) : s
end

"""
    cliptable(; kwargs...)

Make a table from the clipboard. Returns
a `CSV.File`, which can then be transformed
into a `DataFrame` or other Tables.jl-compatible
object.

`cliptable` auto-detects delimiters, and all keyword
arguments are passed directly to the `CSV.File`
constructor.

## Examples

```jldoctest
julia> # Send string to the clipboard
       \"\"\"
       a,b
       1,2
       100,200
       \"\"\" |> clipboard

julia> cliptable() |> Tables.columntable
(a = [1, 100], b = [2, 200])
```

"""
function cliptable(; kwargs...)
    CSV.File(IOBuffer(clipboard()); kwargs...)
end

"""
    cliparray(; kwargs...)

Make a `Vector` or `Matrix` from the clipboard.
Auto-detects delimiters, and all keyword arguments are passed
directly to a `CSV.File` constructor. If the returned `CSV.File`
has one row or one column, `cliparray` returns a `Vector`. 
Otherwise it returns a `Matrix`.

# Examples

```jldoctest
julia> # Send string to clipboard
       \"\"\"
       1 2
       3 4
       \"\"\" |> clipboard

julia> cliparray()
2×2 Matrix{Int64}:
 1  2
 3  4

julia> \"\"\"
       1
       2
       3
       4
       \"\"\" |> clipboard

julia> cliparray()
4-element Vector{Int64}:
 1
 2
 3
 4
```
"""
function cliparray(; kwargs...)
    t = CSV.File(IOBuffer(clipboard()); header=false, kwargs...)
    # An empty clipboard parses to zero columns, which `Tables.matrix` has no
    # element type to promote to.
    if isempty(Tables.columnnames(t))
        return Any[]
    end
    mat = Tables.matrix(t)
    if size(mat, 2) == 1 || size(mat, 1) == 1
        return vec(mat)
    else
        return mat
    end
end

"""
    cliptable(t; returnstring = false, delim = '\t', kwargs...)

Send a Tables.jl-compatible object to the clipboard.
Default delimiter is tab. Accepts all keyword arguments
that can be passed to `CSV.write`. If `returnstring=true`,
also return the string sent to the clipboard.

# Example

```jldoctest
julia> t = (a = [1, 2, 3], b = [100, 200, 300])
(a = [1, 2, 3], b = [100, 200, 300])

julia> cliptable(t)
```
"""
function cliptable(t; returnstring = false, delim = '\t', newline = '\n', kwargs...)
    io = IOBuffer()
    CSV.write(io, t; delim = delim, newline = newline, kwargs...)
    s = chopnewline(String(take!(io)), newline)
    return clipstring(s, returnstring)
end

"""
    cliparray(t::AbstractVecOrMat; returnstring = false, kwargs...)

Send a `Vector` or `Matrix` to the clipboard.
Default delimiter is tab and with no header.
Accepts all keyword arguments that can be passed
to `CSV.write`. If `returnstring=true`, also return
the string sent to the clipboard.

# Examples

```jldoctest
julia> X = [1 2; 3 4]
2×2 Matrix{Int64}:
 1  2
 3  4

julia> cliparray(X)
```
"""
function cliparray(t::AbstractVecOrMat; returnstring = false, delim='\t',
                   header=false, newline='\n', kwargs...)
    if t isa AbstractVector
        t = reshape(t, :, 1)
    end
    io = IOBuffer()
    CSV.write(io, Tables.table(t); delim=delim, header=header, newline=newline, kwargs...)
    s = chopnewline(String(take!(io)), newline)
    return clipstring(s, returnstring)
end

"""
    mwetable([io::IO=stdout]; returnstring=false, name=:df, kwargs...)

Create a Minimum Working Example (MWE) using
the clipboard. `mwetable` prints out a multi-line
comma-separated string and provides the necessary
code to read that string using `CSV.File`.
The object is assigned the name given by
`name` (default `:df`). Prints to `io`,
which is by default `stdout`, or returns the code
as a `String` if `returnstring=true`.

Remaining keyword arguments are forwarded to [`cliptable`](@ref)
to parse the clipboard, so data needing e.g. `delim` or
`missingstring` can still be turned into an MWE. The generated
code is always written in the default comma-separated form.

# Examples

```jldoctest
julia> \"\"\"
       a b
       1 2
       100 200
       \"\"\" |> clipboard

julia> mwetable()
df = \"\"\"
a,b
1,2
100,200
\"\"\" |> IOBuffer |> CSV.File
```

"""
function mwetable(io::IO; returnstring=false, name=:df, kwargs...)
    t = cliptable(; kwargs...)
    mwetable(io, t, returnstring=returnstring, name=name)
end

mwetable(; kwargs...) = mwetable(stdout; kwargs...)


"""
    mwetable([io::IO=stdout], t; returnstring=false, name=:df)

Create a Minimum Working Example (MWE) from
an existing Tables.jl-compatible object.
`mwetable` prints out a multi-line
comma-separated string and provides the necessary
code to read that string using `CSV.File`.
The object is assigned the name given by
`name` (default `:df`). Prints to `io`,
which is by default `stdout`, or returns the code
as a `String` if `returnstring=true`.

# Examples

```jldoctest
julia> t = (a = [1, 2, 3], b = [100, 200, 300])
(a = [1, 2, 3], b = [100, 200, 300])

julia> mwetable(t)
df = \"\"\"
a,b
1,100
2,200
3,300
\"\"\" |> IOBuffer |> CSV.File
```
"""
function mwetable(io::IO, t; returnstring=false, name=:df)
    checkname(name)
    main_io = IOBuffer()
    table_io = IOBuffer()

    start_str = """
$name = \"\"\"
"""
    print(main_io, start_str)

    CSV.write(table_io, t)
    print(main_io, escapepayload(String(take!(table_io))))

    end_str = """
\"\"\" |> IOBuffer |> CSV.File"""
    print(main_io, end_str)
    s = String(take!(main_io))

    return mwestring(io, s, returnstring)
end

mwetable(t; kwargs...) = mwetable(stdout, t; kwargs...)

function mwetable_helper(t::Symbol)
    t_name = QuoteNode(t)
    # `mwetable` is left unescaped so it resolves in this module rather than in
    # the caller's scope; only the user's variable is escaped.
    :(mwetable($(esc(t)), name = $t_name))
end

function mwetable_helper(t)
    throw(ArgumentError("@mwetable expects the name of a variable, got `$t`. " *
                        "Use `mwetable($t)` instead."))
end

"""
    @mwetable(t)

Create a Minimum Working Example (MWE) from
an existing Tables.jl-compatible object.
`mwetable` prints out a multi-line
comma-separated string and provides the necessary
code to read that string using `CSV.File`. The name
assigned to the object in the MWE is the
same as the name of the input object, so `t` must be
a variable name rather than an expression. Prints
to `stdout`.

# Examples

```jldoctest
julia> my_special_table = (a = [1, 2, 3], b = [100, 200, 300])
(a = [1, 2, 3], b = [100, 200, 300])

julia> @mwetable my_special_table
my_special_table = \"\"\"
a,b
1,100
2,200
3,300
\"\"\" |> IOBuffer |> CSV.File
```
"""
macro mwetable(t)
    mwetable_helper(t)
end

"""
    mwearray([io::IO=stdout]; returnstring=false, name=nothing, kwargs...)

Create a Minimum Working Example (MWE) from
the clipboard to create an array. `mwearray`
prints out a multi-line comma-separated string
and provides the necessary code to read that string
back as a `Vector` or `Matrix`. Prints to `io`,
which is by default `stdout`, or returns the code
as a `String` if `returnstring=true`. The object is assigned
the name given by `name`, which must be a valid Julia
identifier and defaults to `:X` when the clipboard holds a
`Matrix` and `:x` when it holds a `Vector`.

Remaining keyword arguments are forwarded to [`cliparray`](@ref)
to parse the clipboard. Note that `cliparray` collapses a single
row to a `Vector`, so a one-row clipboard produces a single-column
MWE; pass the data through [`mwetable`](@ref) to keep the layout.

# Examples

```jldoctest
julia> \"\"\"
       1 2
       3 4
       \"\"\" |> clipboard

julia> mwearray()
X = \"\"\"
1,2
3,4
\"\"\" |> IOBuffer |> (io -> CSV.File(io; header=false)) |> Tables.matrix
```
"""
function mwearray(io::IO; returnstring=false, name=nothing, kwargs...)
    t = cliparray(; kwargs...)
    name = something(name, t isa AbstractVector ? :x : :X)
    mwearray(io, t, returnstring=returnstring, name=name)
end

mwearray(; kwargs...) = mwearray(stdout; kwargs...)

"""
    mwearray([io::IO=stdout], t::AbstractMatrix; returnstring=false, name=:X)

Create a Minimum Working Example (MWE) from
a `Matrix`. `mwearray` prints out a multi-line
comma-separated string and provides the necessary
code to recreate `t`. Prints to `io`, which is by
default `stdout`, or returns the code as a `String`
if `returnstring=true`. `name` must be a valid Julia
identifier.

This method takes no `CSV.write` keyword arguments: the
generated code is always the default comma-separated form.

# Examples

```jldoctest
julia> X = [1 2; 3 4]
2×2 Matrix{Int64}:
 1  2
 3  4

julia> mwearray(X)
X = \"\"\"
1,2
3,4
\"\"\" |> IOBuffer |> (io -> CSV.File(io; header=false)) |> Tables.matrix
```
"""
function mwearray(io::IO, t::AbstractMatrix; returnstring=false, name=:X)
    checkname(name)
    if isempty(t)
        return mwestring(io, "$name = Matrix{$(eltype(t))}(undef, $(size(t, 1)), $(size(t, 2)))", returnstring)
    end

    main_io = IOBuffer()
    array_io = IOBuffer()

    start_str = """
$name = \"\"\"
"""
    print(main_io, start_str)

    CSV.write(array_io, Tables.table(t); header=false)
    print(main_io, escapepayload(String(take!(array_io))))

    end_str = """
\"\"\" |> IOBuffer |> (io -> CSV.File(io; header=false)) |> Tables.matrix"""
    print(main_io, end_str)
    s = String(take!(main_io))

    return mwestring(io, s, returnstring)
end

"""
    mwearray([io::IO=stdout], t::AbstractVector; returnstring=false, name=:x)

Create a Minimum Working Example (MWE) from
a `Vector`. `mwearray` prints out a multi-line
comma-separated string and provides the necessary
code to recreate `t`. Prints to `io`, which is by
default `stdout`, or returns the code as a `String`
if `returnstring=true`. `name` must be a valid Julia
identifier.

This method takes no `CSV.write` keyword arguments: the
generated code is always the default comma-separated form.

# Example

```jldoctest
julia> x = [1, 2, 3, 4]
4-element Vector{Int64}:
 1
 2
 3
 4

julia> mwearray(x)
x = \"\"\"
1
2
3
4
\"\"\" |> IOBuffer |> (io -> CSV.File(io; header=false)) |> Tables.matrix |> vec
```
"""
function mwearray(io::IO, t::AbstractVector; returnstring=false, name=:x)
    checkname(name)
    if isempty(t)
        return mwestring(io, "$name = $(eltype(t))[]", returnstring)
    end

    main_io = IOBuffer()
    array_io = IOBuffer()

    t = reshape(t, :, 1)

    start_str = """
$name = \"\"\"
"""
    print(main_io, start_str)

    CSV.write(array_io, Tables.table(t); header=false)
    print(main_io, escapepayload(String(take!(array_io))))

    end_str = """
\"\"\" |> IOBuffer |> (io -> CSV.File(io; header=false)) |> Tables.matrix |> vec"""
    print(main_io, end_str)
    s = String(take!(main_io))

    return mwestring(io, s, returnstring)
end

mwearray(t::Union{AbstractVector, AbstractMatrix}; kwargs...) = mwearray(stdout, t; kwargs...)

function mwearray_helper(t::Symbol)
    t_name = QuoteNode(t)
    # `mwearray` is left unescaped so it resolves in this module rather than in
    # the caller's scope; only the user's variable is escaped.
    :(mwearray($(esc(t)), name=$t_name))
end

function mwearray_helper(t)
    throw(ArgumentError("@mwearray expects the name of a variable, got `$t`. " *
                        "Use `mwearray($t)` instead."))
end

"""
    @mwearray(t)

Create a Minimum Working Example (MWE)
from a `Vector` or `Matrix` with the same
name as the object in the Julia session. Prints
to `stdout`.

# Examples

```jldoctest
julia> my_special_matrix = [1 2; 3 4]
2×2 Matrix{Int64}:
 1  2
 3  4

julia> @mwearray my_special_matrix
my_special_matrix = \"\"\"
1,2
3,4
\"\"\" |> IOBuffer |> (io -> CSV.File(io; header=false)) |> Tables.matrix
```
"""
macro mwearray(t)
    mwearray_helper(t)
end

end
