kpse.set_program_name'lualatex'
local normalize = require'lua-uni-normalize'
local to_nfc, to_nfd, to_nfkc, to_nfkd = normalize.NFC, normalize.NFD, normalize.NFKC, normalize.NFKD

local function dostep(orig, nfc, nfd, nfkc, nfkd)
  local our_nfc = to_nfc(orig)
  local our_nfd = to_nfd(orig)
  local our_nfkc = to_nfkc(orig)
  local our_nfkd = to_nfkd(orig)
  if nfc ~= our_nfc or nfd ~= our_nfd or nfkc ~= our_nfkc or nfkd ~= our_nfkd then
    return {
      nfc = nfc ~= our_nfc and our_nfc or nil,
      exp_nfc = nfc ~= our_nfc and nfc or nil,
      nfd = nfd ~= our_nfd and our_nfd or nil,
      exp_nfd = nfd ~= our_nfd and nfd or nil,
      nfkc = nfkc ~= our_nfkc and our_nfkc or nil,
      exp_nfkc = nfkc ~= our_nfkc and nfkc or nil,
      nfkd = nfkd ~= our_nfkd and our_nfkd or nil,
      exp_nfkd = nfkd ~= our_nfkd and nfkd or nil,
    }
  end
  return false
end
local function jointests(last, pos, new)
  -- if not new then os.exit(1) end
  last[1] = last[1] + 1
  if new then
    last[#last + 1] = {last[1], pos, new}
  else
    last[2] = last[2] + 1
  end
  return last
end

local p = require'lua-uni-parse'
local codepoint_list = p.codepoint * (' ' * p.codepoint)^0/utf8.char

local results = p.parse_file('NormalizationTest', lpeg.Cf(
    lpeg.Ct(lpeg.Cc(0) * lpeg.Cc(0))
  * ('@' * p.ignore_line + p.eol
    + lpeg.Cg(lpeg.Cp() * (p.fields(codepoint_list,
                                    codepoint_list,
                                    codepoint_list,
                                    codepoint_list,
                                    codepoint_list * p.sep) / dostep)))^0
, jointests) * -1)
if not results then
  error'Reading tests failed'
end
for k=3,#results do
  print(string.format('Failure at test %i, offset %i, %s', results[k][1], results[k][2], require'inspect'(results[k][3])))
end
print(string.format("%i/%i tests succeeded!", results[2], results[1]))
-- os.exit(results[1] == results[2] and 0 or 1)
