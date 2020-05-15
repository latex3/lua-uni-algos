kpse.set_program_name'kpsewhich'
local graphemes = require'lua-uni-graphemes'

local function jointests(last, pos, new)
  -- if not new then os.exit(1) end
  last[1] = last[1] + 1
  if new then
    last[2] = last[2] + 1
  else
    last[#last + 1] = {last[1], pos}
  end
  return last
end

local function dostep(state, expected, cp)
  if state == false then return false end
  -- print(state, expected, cp)
  local result, state = graphemes.read_codepoint(cp, state)
  -- print(state, result)
  return (result or false) == expected and state
end

local p = require'lua-uni-parse'
local isbreak = '÷' * lpeg.Cc(true) + '×' * lpeg.Cc(false)

local line = lpeg.Cg(
    lpeg.Cp() * lpeg.Cf(lpeg.Cc(nil)
      * lpeg.Cg(isbreak * " " * p.codepoint * " ")^0,
      dostep)
    * "÷")^-1 * p.eol

local file = lpeg.Cf(
    lpeg.Ct(lpeg.Cc(0) * lpeg.Cc(0))
  * line^0
, jointests) * -1

local results = p.parse_file('GraphemeBreakTest', file)

if not results then
  error'Reading tests failed'
end
for k=3,#results do
  texio.write_nl(string.format('Failure at test %i, offset %i', results[k][1], results[k][2]))
end
texio.write_nl(string.format("%i/%i tests succeeded!", results[2], results[1]))
-- os.exit(results[1] == results[2] and 0 or 1)
