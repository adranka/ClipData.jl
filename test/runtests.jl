using ClipData
using Test
using InteractiveUtils: clipboard
using Tables
using CSV
using Aqua
using Documenter

const ≅ = isequal

@testset "ClipData.jl" begin

@testset "cliptable" begin
    """
    a b
    1 2
    3 4
    """ |> clipboard

    @test Tables.columntable(cliptable()) == (a = [1, 3], b = [2, 4])

    """
    a\tb
    1\t2
    3\t4
    """ |> clipboard

    @test Tables.columntable(cliptable()) == (a = [1, 3], b = [2, 4])

    t = (a = [1, 3], b = [2, 4])
    cliptable(t)
    @test clipboard() == "a\tb\n1\t2\n3\t4"
end

@testset "cliparray" begin
    """
    1 2
    3 4
    """ |> clipboard

    @test cliparray() == [1 2; 3 4]

    """
    1\t2
    3\t4
    """ |> clipboard

    @test cliparray() == [1 2; 3 4]

    """
    1
    2
    3
    4
    """ |> clipboard

    @test cliparray() == [1, 2, 3, 4]

    X = [1 2; 3 4]
    cliparray(X)
    @test clipboard() == "1\t2\n3\t4"

    x = [1, 2, 3, 4]
    cliparray(x)
    @test clipboard() == "1\n2\n3\n4"

    """
    1 2 3 4
    """ |> clipboard

    @test cliparray() == [1, 2, 3, 4]

    """
    1\t2\t3\t4
    """ |> clipboard

    @test cliparray() == [1, 2, 3, 4]

    """
    1,2,3,4
    """ |> clipboard

    @test cliparray() == [1, 2, 3, 4]

    """
    5
    """ |> clipboard

    @test cliparray() == [5]
end

@testset "mwetable" begin
    """
    a b
    1 2
    3 4
    """ |> clipboard

    s = mwetable(; returnstring=true)
    s_correct =
"""
df = \"\"\"
a,b
1,2
3,4
\"\"\" |> IOBuffer |> CSV.File"""

    @test s == s_correct

    t = (a = [1, 3], b = [2, 4])
    s = mwetable(t; returnstring = true)
    @test s == s_correct

    # Tests the default printing to stdout
    io = IOBuffer()
    mwetable(io, t; returnstring=false)
    @test String(take!(io)) == s_correct

    io = IOBuffer()
    cliptable(t)
    mwetable(io; returnstring=false)
    @test String(take!(io)) == s_correct
end

@testset "mwearray" begin
    """
    1 2
    3 4
    """ |> clipboard

    s = mwearray(; returnstring=true)
    s_correct =
"""
X = \"\"\"
1,2
3,4
\"\"\" |> IOBuffer |> (io -> CSV.File(io; header=false)) |> Tables.matrix"""

    @test s == s_correct

    t = [1 2; 3 4]
    s = mwearray(t; returnstring = true)

    @test s == s_correct

    io = IOBuffer()
    mwearray(io, t; returnstring=false)
    @test String(take!(io)) == s_correct

    io = IOBuffer()
    cliparray(t)
    mwearray(io)
    @test String(take!(io)) == s_correct

    """
    1
    2
    3
    4
    """ |> clipboard

    s = mwearray(; returnstring=true)

    s_correct =
"""
x = \"\"\"
1
2
3
4
\"\"\" |> IOBuffer |> (io -> CSV.File(io; header=false)) |> Tables.matrix |> vec"""

    @test s == s_correct

    x = [1, 2, 3, 4]

    s = mwearray(x; returnstring=true)
    @test s == s_correct

    # Tests the default printing to stdout
    io = IOBuffer()
    mwearray(io, x; returnstring=false)
    @test String(take!(io)) == s_correct

    io = IOBuffer()
    cliparray(x)
    mwearray(io)
    @test String(take!(io)) == s_correct

    # `name` is honored when reading from the clipboard, and its default
    # follows the shape of the data.
    s = mwearray(; name = :myvec, returnstring = true)

    s_correct =
"""
myvec = \"\"\"
1
2
3
4
\"\"\" |> IOBuffer |> (io -> CSV.File(io; header=false)) |> Tables.matrix |> vec"""

    @test s == s_correct

    io = IOBuffer()
    mwearray(io; name = :myvec)
    @test String(take!(io)) == s_correct

    cliparray([1 2; 3 4])
    s = mwearray(; name = :mymat, returnstring = true)

    s_correct =
"""
mymat = \"\"\"
1,2
3,4
\"\"\" |> IOBuffer |> (io -> CSV.File(io; header=false)) |> Tables.matrix"""

    @test s == s_correct
    @test startswith(mwearray(; returnstring = true), "X = ")
end

# Capture what an expression prints to stdout. The macros expand to the
# no-`io` method, so there is no `io` argument to pass in. `redirect_stdout`
# needs a real stream, hence the temp file rather than an `IOBuffer`.
function capture_stdout(f)
    mktemp() do path, io
        redirect_stdout(f, io)
        flush(io)
        read(path, String)
    end
end

# Run a generated MWE snippet in a fresh module and hand back the value it
# binds, so we can check the code actually reproduces the original data.
function eval_mwe(s, name)
    m = Module()
    Base.eval(m, :(using CSV, Tables))
    # Return the binding from the same `include_string` that creates it, so the
    # lookup does not run in an older world age than the assignment.
    include_string(m, string(s, "\n", name))
end

# Julia 1.6 wraps an error thrown during macro expansion in a `LoadError`, while
# later versions rethrow it untouched. Hand back the error the macro itself threw.
function expansion_error(ex)
    try
        macroexpand(@__MODULE__, ex)
        nothing
    catch err
        err isa LoadError ? err.error : err
    end
end

@testset "@mwetable" begin
    mytable = (a = [1, 2], b = [3, 4])

    # The macro's only job is splicing in the variable's name. `mwetable`
    # resolves in ClipData, not in the caller's scope.
    @test @macroexpand(@mwetable mytable) ==
        :($(GlobalRef(ClipData, :mwetable))(mytable, name = :mytable))
    @test expansion_error(:(@mwetable (a = [1], b = [2]))) isa ArgumentError

    s = capture_stdout() do
        @mwetable mytable
    end

    s_correct =
"""
mytable = \"\"\"
a,b
1,3
2,4
\"\"\" |> IOBuffer |> CSV.File"""

    @test s == s_correct
    @test s == mwetable(mytable; name = :mytable, returnstring = true)

    # The generated code reproduces the original table.
    @test eval_mwe(s, :mytable) |> Tables.columntable == mytable
end

@testset "@mwearray" begin
    myarray = [1 2; 3 4]
    myvector = [1, 2, 3, 4]

    @test @macroexpand(@mwearray myarray) ==
        :($(GlobalRef(ClipData, :mwearray))(myarray, name = :myarray))
    @test @macroexpand(@mwearray myvector) ==
        :($(GlobalRef(ClipData, :mwearray))(myvector, name = :myvector))
    @test expansion_error(:(@mwearray [1 2; 3 4])) isa ArgumentError

    # The error points at the function form rather than naming a private helper.
    e = expansion_error(:(@mwearray [1 2; 3 4]))
    @test occursin("@mwearray expects the name of a variable", sprint(showerror, e))

    s = capture_stdout() do
        @mwearray myarray
    end

    s_correct =
"""
myarray = \"\"\"
1,2
3,4
\"\"\" |> IOBuffer |> (io -> CSV.File(io; header=false)) |> Tables.matrix"""

    @test s == s_correct
    @test s == mwearray(myarray; name = :myarray, returnstring = true)
    @test eval_mwe(s, :myarray) == myarray

    s = capture_stdout() do
        @mwearray myvector
    end

    s_correct =
"""
myvector = \"\"\"
1
2
3
4
\"\"\" |> IOBuffer |> (io -> CSV.File(io; header=false)) |> Tables.matrix |> vec"""

    @test s == s_correct
    @test s == mwearray(myvector; name = :myvector, returnstring = true)
    @test eval_mwe(s, :myvector) == myvector
end

# The macros expand to a call on ClipData's own function, so they work even when
# that function is not reachable from the caller's scope.
@testset "macro scope" begin
    expected_array = mwearray([1 2; 3 4]; name = :myarray, returnstring = true)
    expected_table = mwetable((a = [1, 2],); name = :mytable, returnstring = true)

    # Only the macros are imported; `mwearray`/`mwetable` are not in scope.
    m = Module()
    Base.eval(m, :(import ClipData: @mwearray, @mwetable))
    Base.eval(m, :(myarray = [1 2; 3 4]))
    Base.eval(m, :(mytable = (a = [1, 2],)))

    @test capture_stdout() do
        Base.eval(m, :(@mwearray myarray))
    end == expected_array

    @test capture_stdout() do
        Base.eval(m, :(@mwetable mytable))
    end == expected_table

    # A local binding shadowing the function name must not be called instead.
    m = Module()
    Base.eval(m, :(using ClipData))
    Base.eval(m, :(function shadowed(mwearray)
        myarray = [1 2; 3 4]
        @mwearray myarray
    end))

    @test capture_stdout() do
        Base.eval(m, :(shadowed("not a function")))
    end == expected_array
end

@testset "empty clipboard" begin
    # An empty clipboard parses to zero columns; `Tables.matrix` used to throw
    # "reducing over an empty collection" from inside `cliparray`.
    for cb in ["", "\n", "\n\n"]
        clipboard(cb)
        @test cliparray() == []
        @test cliparray() isa AbstractVector
        @test Tables.columntable(cliptable()) == NamedTuple()
    end

    # Whitespace is a delimiter, not emptiness, so it still parses.
    "  " |> clipboard
    @test cliparray() ≅ [missing, missing, missing]

    # An empty array has no CSV representation, so the MWE is a literal. It has
    # to be code that actually runs.
    clipboard("")
    @test mwearray(; returnstring = true) == "x = Any[]"
    @test eval_mwe(mwearray(; returnstring = true), :x) == Any[]

    @test mwearray(Int[]; returnstring = true) == "x = Int64[]"
    @test eval_mwe(mwearray(Int[]; returnstring = true), :x) == Int[]

    X = Matrix{Float64}(undef, 0, 3)
    @test mwearray(X; returnstring = true) == "X = Matrix{Float64}(undef, 0, 3)"
    @test eval_mwe(mwearray(X; returnstring = true), :X) == X

    # `name` and `io` are honored on the empty path too.
    @test mwearray(Int[]; name = :myvec, returnstring = true) == "myvec = Int64[]"
    io = IOBuffer()
    mwearray(io, Int[])
    @test String(take!(io)) == "x = Int64[]"

    # Round trip: writing an empty array and reading it back.
    cliparray(Int[])
    @test clipboard() == ""
    @test cliparray() == Int[]
end

@testset "Kwargs with reading" begin
    """
    a,b
    1,2
    3,NA
    """ |> clipboard
    t = cliptable(; missingstring = "NA") |> Tables.columntable
    @test t ≅ (; a = [1, 3], b = [2, missing])

    """
    a\tb
    1\t2
    3\t4
    # a comment
    """ |> clipboard
    t = cliptable(; comment = "#") |> Tables.columntable
    @test t == (; a = [1, 3], b = [2, 4])

    """
    a,b
    1,2
    3,NA
    """ |> clipboard
    t = cliptable(; limit = 1, header = true) |> Tables.columntable
    @test t == (; a = [1], b = [2])

    """
    1,2
    3,NA
    """ |> clipboard
    a = cliparray(; missingstring = "NA")
    @test a ≅  [1 2; 3 missing]

    """
    1 2 3 4
    """ |> clipboard
    @test cliparray(; delim = ',') == ["1 2 3 4"]
end

@testset "Kwargs with writing" begin
    t = (a = [1, 2], b = [3, 4])
    cliptable(t; delim = ",")
    @test clipboard() == "a,b\n1,3\n2,4"

    cliptable(t; header = ["x", "y"])
    @test clipboard() == "x\ty\n1\t3\n2\t4"

    t = (a = [1.0, missing], b = [3, 4])
    cliptable(t; missingstring = "NA", decimal = ',')

    @test clipboard() == "a\tb\n1,0\t3\nNA\t4"

    t = (a = [1, nothing], b = [missing, 4])
    cliptable(t, missingstring="-1", transform=(col, val) -> something(val, missing))

    @test clipboard() == "a\tb\n1\t-1\n-1\t4"

    # A non-default `newline` is stripped whole, rather than one character of it
    t = (a = [1, 2], b = [3, 4])

    cliptable(t)
    @test clipboard() == "a\tb\n1\t3\n2\t4"

    cliptable(t; newline = "\r\n")
    @test clipboard() == "a\tb\r\n1\t3\r\n2\t4"
    @test Tables.columntable(cliptable()) == t

    cliparray([1 2; 3 4]; newline = "\r\n")
    @test clipboard() == "1\t2\r\n3\t4"
    @test cliparray() == [1 2; 3 4]

    cliparray([1, 2, 3]; newline = "\r\n")
    @test clipboard() == "1\r\n2\r\n3"
    @test cliparray() == [1, 2, 3]
end

@testset "Kwargs with mwe" begin
    # `mwetable()`/`mwearray()` forward keyword arguments to the clipboard read,
    # so data that needs them can be turned into an MWE at all.
    "a;b\n1;2\n3;4" |> clipboard

    s = mwetable(; delim = ';', returnstring = true)

    s_correct =
"""
df = \"\"\"
a,b
1,2
3,4
\"\"\" |> IOBuffer |> CSV.File"""

    @test s == s_correct
    @test eval_mwe(s, :df) |> Tables.columntable == (a = [1, 3], b = [2, 4])

    "1;2\n3;4" |> clipboard

    s = mwearray(; delim = ';', returnstring = true)

    s_correct =
"""
X = \"\"\"
1,2
3,4
\"\"\" |> IOBuffer |> (io -> CSV.File(io; header=false)) |> Tables.matrix"""

    @test s == s_correct
    @test eval_mwe(s, :X) == [1 2; 3 4]

    # The MWE is always written in the default comma form, so a `missingstring`
    # used on the way in is canonicalised on the way out.
    "a,b\n1,NA\n3,4" |> clipboard

    s = mwetable(; missingstring = "NA", returnstring = true)
    @test s ==
"""
df = \"\"\"
a,b
1,
3,4
\"\"\" |> IOBuffer |> CSV.File"""

    @test eval_mwe(s, :df) |> Tables.columntable ≅ (a = [1, 3], b = [missing, 4])

    # The example from the README.
    "my col,other col\n1,2" |> clipboard
    @test mwetable(; normalizenames = true, returnstring = true) ==
"""
df = \"\"\"
my_col,other_col
1,2
\"\"\" |> IOBuffer |> CSV.File"""

    # Read kwargs compose with `name` and `io`.
    "a;b\n1;2" |> clipboard

    s_correct =
"""
mydf = \"\"\"
a,b
1,2
\"\"\" |> IOBuffer |> CSV.File"""

    @test mwetable(; delim = ';', name = "mydf", returnstring = true) == s_correct

    io = IOBuffer()
    mwetable(io; delim = ';', name = "mydf")
    @test String(take!(io)) == s_correct

    "1;2" |> clipboard
    @test mwearray(; delim = ';', name = :myvec, returnstring = true) ==
"""
myvec = \"\"\"
1
2
\"\"\" |> IOBuffer |> (io -> CSV.File(io; header=false)) |> Tables.matrix |> vec"""

    # Write kwargs are deliberately not forwarded: the generated snippet has no
    # way to reflect them, so a MethodError beats a silently wrong MWE.
    @test_throws MethodError mwetable((a = [1, missing],); missingstring = "NA")
    @test_throws MethodError mwearray([1, 2]; delim = ';')
end

@testset "strings" begin
    """
    a,b
    hello,world
    foo,bar
    """ |> clipboard

    @test Tables.columntable(cliptable()) == (a = ["hello", "foo"], b = ["world", "bar"])

    # Quoted fields containing the delimiter
    """
    a,b
    "x,y",2
    "p,q",4
    """ |> clipboard

    @test Tables.columntable(cliptable()) == (a = ["x,y", "p,q"], b = [2, 4])

    # Same idea, but with a space delimiter
    """
    a b
    "hello world" 2
    "foo bar" 4
    """ |> clipboard

    t = cliptable(; delim = ' ') |> Tables.columntable
    @test t == (a = ["hello world", "foo bar"], b = [2, 4])

    # Escaped quotes inside a quoted field
    """
    a,b
    "she said ""hi"" loudly",1
    """ |> clipboard

    @test Tables.columntable(cliptable()) == (a = ["she said \"hi\" loudly"], b = [1])

    # Writing only escapes strings containing the delimiter actually in use
    t = (a = ["x,y", "p"], b = [1, 2])

    cliptable(t)
    @test clipboard() == "a\tb\nx,y\t1\np\t2"

    cliptable(t; delim = ',')
    @test clipboard() == "a,b\n\"x,y\",1\np,2"

    # ... so a tab-delimited write escapes embedded tabs instead
    t = (a = ["x\ty"], b = [1])
    cliptable(t)
    @test clipboard() == "a\tb\n\"x\ty\"\t1"

    # Embedded quotes and newlines are escaped as well
    t = (a = ["say \"hi\"", "two\nlines"], b = [1, 2])
    cliptable(t)
    @test clipboard() == "a\tb\n\"say \"\"hi\"\"\"\t1\n\"two\nlines\"\t2"

    # Round trip a table whose strings contain the delimiter
    t = (a = ["x,y", "p,q"], b = [1, 2])
    cliptable(t; delim = ',')
    @test Tables.columntable(cliptable(; delim = ',')) == t

    # Arrays of strings
    """
    a,b
    c,d
    """ |> clipboard

    @test cliparray() == ["a" "b"; "c" "d"]

    x = ["a,b", "c"]

    cliparray(x)
    @test clipboard() == "a,b\nc"

    cliparray(x; delim = ',')
    @test clipboard() == "\"a,b\"\nc"
end

@testset "mixed variables" begin
    """
    a,b,c,d
    1,2.5,hello,true
    3,4.0,world,false
    """ |> clipboard

    t = cliptable() |> Tables.columntable
    @test t == (a = [1, 3], b = [2.5, 4.0], c = ["hello", "world"], d = [true, false])
    @test eltype(t.a) <: Integer
    @test eltype(t.b) <: AbstractFloat
    @test eltype(t.c) <: AbstractString
    @test eltype(t.d) == Bool

    # Missing values mixed in with strings and numbers
    """
    a,b,c
    1,x,2.5
    ,y,
    """ |> clipboard

    t = cliptable() |> Tables.columntable
    @test t ≅ (a = [1, missing], b = ["x", "y"], c = [2.5, missing])

    # Mixed columns come back as a Matrix with a promoted eltype
    """
    1,a,2.5
    2,b,3.5
    """ |> clipboard

    X = cliparray()
    @test X isa Matrix
    @test X == [1 "a" 2.5; 2 "b" 3.5]

    # Writing a table with mixed column types
    t = (a = [1, 2], b = ["x", "y"], c = [1.5, 2.5], d = [true, false])
    cliptable(t)
    @test clipboard() == "a\tb\tc\td\n1\tx\t1.5\ttrue\n2\ty\t2.5\tfalse"

    # Writing a mixed array
    X = [1 "a"; 2 "b"]
    cliparray(X)
    @test clipboard() == "1\ta\n2\tb"
end

@testset "mixed data within a column" begin
    # Integers and floats in one column promote to Float64
    """
    a,b
    1,2.5
    2.5,3
    """ |> clipboard

    t = cliptable() |> Tables.columntable
    @test t == (a = [1.0, 2.5], b = [2.5, 3.0])
    @test eltype(t.a) <: AbstractFloat
    @test eltype(t.b) <: AbstractFloat

    # A non-numeric value later in the column forces the whole column to String
    """
    a
    1
    2
    3
    hello
    """ |> clipboard

    t = cliptable() |> Tables.columntable
    @test t == (a = ["1", "2", "3", "hello"],)
    @test eltype(t.a) <: AbstractString

    # ... and the same holds when the non-numeric value comes first
    """
    a
    hello
    1
    2
    3
    """ |> clipboard

    @test Tables.columntable(cliptable()) == (a = ["hello", "1", "2", "3"],)

    # Missing values inside an otherwise mixed column
    """
    a,b
    1,x
    ,y
    hello,z
    """ |> clipboard

    t = cliptable() |> Tables.columntable
    @test t ≅ (a = ["1", missing, "hello"], b = ["x", "y", "z"])

    # `types` overrides the promotion and keeps everything as strings
    """
    a,b
    1,2
    3,4
    """ |> clipboard

    t = cliptable(; types = String) |> Tables.columntable
    @test t == (a = ["1", "3"], b = ["2", "4"])

    # A mixed column read as an array
    """
    1
    2.5
    hello
    """ |> clipboard

    @test cliparray() == ["1", "2.5", "hello"]

    """
    1,x
    2.5,y
    hello,z
    """ |> clipboard

    @test cliparray() == ["1" "x"; "2.5" "y"; "hello" "z"]

    # Writing a mixed Julia column
    t = (a = Any[1, "two", 3.5],)
    cliptable(t)
    @test clipboard() == "a\n1\ntwo\n3.5"

    # ... including one whose string element contains the delimiter
    t = (a = Any[1, "x,y", 2.5],)
    cliptable(t; delim = ',')
    @test clipboard() == "a\n1\n\"x,y\"\n2.5"

    # ... and one containing missing
    t = (a = Any[1, missing, "x"],)
    cliptable(t; missingstring = "NA")
    @test clipboard() == "a\n1\nNA\nx"

    # A mixed column survives a round trip through an MWE
    """
    a,b
    1,x
    hello,2.5
    """ |> clipboard

    s_correct =
"""
df = \"\"\"
a,b
1,x
hello,2.5
\"\"\" |> IOBuffer |> CSV.File"""

    @test mwetable(; returnstring = true) == s_correct
end

@testset "mwe with strings and mixed types" begin
    t = (a = ["x,y", "p"], b = [1, 2])

    s_correct =
"""
df = \"\"\"
a,b
\"x,y\",1
p,2
\"\"\" |> IOBuffer |> CSV.File"""

    @test mwetable(t; returnstring = true) == s_correct

    # Same table, but round tripped through the clipboard first
    cliptable(t; delim = ',')
    @test mwetable(; returnstring = true) == s_correct

    t = (a = [1, 2], b = ["x", "y"], c = [1.5, 2.5])

    s_correct =
"""
df = \"\"\"
a,b,c
1,x,1.5
2,y,2.5
\"\"\" |> IOBuffer |> CSV.File"""

    @test mwetable(t; returnstring = true) == s_correct

    x = ["a,b", "c"]

    s_correct =
"""
x = \"\"\"
\"a,b\"
c
\"\"\" |> IOBuffer |> (io -> CSV.File(io; header=false)) |> Tables.matrix |> vec"""

    @test mwearray(x; returnstring = true) == s_correct

    X = [1 "a"; 2 "b"]

    s_correct =
"""
X = \"\"\"
1,a
2,b
\"\"\" |> IOBuffer |> (io -> CSV.File(io; header=false)) |> Tables.matrix"""

    @test mwearray(X; returnstring = true) == s_correct
end

@testset "docstrings" begin
    # The doctests drive the real clipboard, so they need `clipboard` in scope
    # alongside the package itself. `docs/make.jl` skips them for that reason:
    # the docs are built on a headless machine with no clipboard.
    DocMeta.setdocmeta!(
        ClipData,
        :DocTestSetup,
        :(using ClipData, Tables; using InteractiveUtils: clipboard);
        recursive = true)

    doctest(ClipData; manual = false)
end

@testset "Aqua" begin
    Aqua.test_all(ClipData)
end

end
