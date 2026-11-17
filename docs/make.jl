using Documenter, ClipData

makedocs(
	sitename = "ClipData.jl",
	modules = [ClipData],
	doctest = false,
	pages = Any[
		"Introduction" => "index.md",
		"API" => "api/api.md"],
	format = Documenter.HTML(
		canonical = "https://jcunwin.github.io/ClipData.jl/stable/"
	))

deploydocs(
    repo = "github.com/jcunwin/ClipData.jl.git",
    target = "build",
    deps = nothing,
    make = nothing)
