module = "lua-uni-algos"

typesetexe = "lualatex"
stdengine = "luatex"
checkengines = {"luatex"}

installfiles = {"lua-uni-*.lua"}
sourcefiles = {"lua-uni-*.lua"}
typesetfiles = {"lua-uni-algos.tex"}

tdsroot = "luatex"

uploadconfig = {
  pkg = module,
  version = "v0.5",
  author = "Marcel Krüger, The LaTeX Team",
  license = "lppl1.3c",
  summary = "Unicode algorithms for LuaTeX",
  ctanPath = "/macros/luatex/generic/lua-uni-algos",
  update = true,
  repository = "https://github.com/latex3/lua-uni-algos",
  bugtracker = "https://github.com/latex3/lua-uni-algos/issues",
  topic = {"luatex", "unicode"},
  announcement_file = "announce",
}
