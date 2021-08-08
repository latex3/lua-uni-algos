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
  version = "v0.4",
  author = "Marcel Krüger",
  license = "lppl1.3",
  summary = "Unicode algorithms for LuaTeX",
  ctanPath = "/macros/luatex/generic/lua-uni-algos",
  update = true,
  repository = "https://github.com/zauguin/lua-uni-algos",
  bugtracker = "https://github.com/zauguin/lua-uni-algos/issues",
  topic = {"luatex", "unicode"},
  announcement_file = "announce",
}
