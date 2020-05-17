-- lua-uni-normalize.lua
-- Copyright 2020 Marcel Krüger
--
-- This work may be distributed and/or modified under the
-- conditions of the LaTeX Project Public License, either version 1.3
-- of this license or (at your option) any later version.
-- The latest version of this license is in
--   http://www.latex-project.org/lppl.txt
-- and version 1.3 or later is part of all distributions of LaTeX
-- version 2005/12/01 or later.
--
-- This work has the LPPL maintenance status `maintained'.
-- 
-- The Current Maintainer of this work is Marcel Krüger

-- Provide all four kinds of Unicode normalization

local newtable = lua.newtable
local move = table.move
local char = utf8.char
local codes = utf8.codes
local unpack = table.unpack

kpse.set_program_name'kpsewhich'
local ccc, composition_mapping, decomposition_mapping, compatibility_mapping do
  local function doubleset(ts, key, v1, kind, v2)
    ts[1][key] = v1
    ts[3][key] = v2
    if not kind then
      ts[2][key] = v2
    end
    return ts
  end
  local p = require'lua-uni-parse'
  local l = lpeg
  local Cnil = l.Cc(nil)
  local letter = lpeg.R('AZ', 'az')
  ccc, decomposition_mapping, compatibility_mapping
                    = unpack(p.parse_file('UnicodeData', l.Cf(
    l.Ct(l.Ct'' * l.Ct'' * l.Ct'') * (
      l.Cg(p.fields(p.codepoint,
                    p.ignore_field,
                    p.ignore_field,
                    '0' * Cnil + p.number,
                    p.ignore_field,
                    ('<' * l.C(letter^1) * '> ' + Cnil)
                  * l.Ct(p.codepoint * (' ' * p.codepoint)^0)^-1,
                    p.ignore_line)) + p.eol
    )^0 * -1, doubleset)))

  composition_mapping = {}
  local composition_exclusions = {      [0x00958] = true, [0x00959] = true,
    [0x0095A] = true, [0x0095B] = true, [0x0095C] = true, [0x0095D] = true,
    [0x0095E] = true, [0x0095F] = true, [0x009DC] = true, [0x009DD] = true,
    [0x009DF] = true, [0x00A33] = true, [0x00A36] = true, [0x00A59] = true,
    [0x00A5A] = true, [0x00A5B] = true, [0x00A5E] = true, [0x00B5C] = true,
    [0x00B5D] = true, [0x00F43] = true, [0x00F4D] = true, [0x00F52] = true,
    [0x00F57] = true, [0x00F5C] = true, [0x00F69] = true, [0x00F76] = true,
    [0x00F78] = true, [0x00F93] = true, [0x00F9D] = true, [0x00FA2] = true,
    [0x00FA7] = true, [0x00FAC] = true, [0x00FB9] = true, [0x0FB1D] = true,
    [0x0FB1F] = true, [0x0FB2A] = true, [0x0FB2B] = true, [0x0FB2C] = true,
    [0x0FB2D] = true, [0x0FB2E] = true, [0x0FB2F] = true, [0x0FB30] = true,
    [0x0FB31] = true, [0x0FB32] = true, [0x0FB33] = true, [0x0FB34] = true,
    [0x0FB35] = true, [0x0FB36] = true, [0x0FB38] = true, [0x0FB39] = true,
    [0x0FB3A] = true, [0x0FB3B] = true, [0x0FB3C] = true, [0x0FB3E] = true,
    [0x0FB40] = true, [0x0FB41] = true, [0x0FB43] = true, [0x0FB44] = true,
    [0x0FB46] = true, [0x0FB47] = true, [0x0FB48] = true, [0x0FB49] = true,
    [0x0FB4A] = true, [0x0FB4B] = true, [0x0FB4C] = true, [0x0FB4D] = true,
    [0x0FB4E] = true,
    [0x02ADC] = true, [0x1D15E] = true, [0x1D15F] = true, [0x1D160] = true,
    [0x1D161] = true, [0x1D162] = true, [0x1D163] = true, [0x1D164] = true,
    [0x1D1BB] = true, [0x1D1BC] = true, [0x1D1BD] = true, [0x1D1BE] = true,
    [0x1D1BF] = true, [0x1D1C0] = true,
  }

  for cp, decomp in next, decomposition_mapping do
    if #decomp > 1 and not (composition_exclusions[cp] or ccc[decomp[1]]) then
      local mapping = composition_mapping[decomp[1]]
      if not mapping then
        mapping = {}
        composition_mapping[decomp[1]] = mapping
      end
      mapping[decomp[2]] = cp
    end
  end

  local function fixup_decomp(decomp)
    local first = decomp[1]
    local first_decomp = decomposition_mapping[first]
    if not first_decomp then return false end
    if fixup_decomp(first_decomp) then
      print('nested', first)
    end
    move(decomp, 2, #decomp, #first_decomp + 1)
    move(first_decomp, 1, #first_decomp, 1, decomp)
    return true
  end
  -- Fixup stage
  for cp, decomp in next, decomposition_mapping do
    if fixup_decomp(decomp) then
      -- print(':(', cp)
    end
  end

  -- NFKD edition
  local DEBUG = false
  local function fixup_decomp(orig, decomp)
    local work
    local shared = decomposition_mapping[orig] == decomp
    local j = 0
    for i = 1, #decomp do
      local cp = decomp[i]
      local cp_decomp = compatibility_mapping[cp]
      if cp_decomp then
        if shared then
          local old = decomp
          decomp = {}
          compatibility_mapping[orig] = decomp
          move(old, 1, #old, 1, decomp)
        end
        decomp[i] = cp_decomp
        j = j + #cp_decomp
        work = true
      else
        j = j + 1
      end
    end
    if not work then return decomp end
    for i = #decomp, 1, -1 do
      local v = decomp[i]
      if type(v) == 'number' then
        decomp[j] = v
        j = j - 1
      else
        local count = #v
        move(v, 1, count, j - count + 1, decomp)
        j = j - count
      end
    end
    assert(j == 0)
    return decomp
  end
  -- Fixup stage
  for cp, decomp in next, compatibility_mapping do
    fixup_decomp(cp, decomp)
  end
end

local function ccc_reorder(codepoints, i, j, k)
  if k >= j then return end
  local first = codepoints[k]
  local first_ccc = ccc[first]
  if not first_ccc then
    return ccc_reorder(codepoints, k+1, j, k+1)
  end
  local new_pos = k
  local cur_ccc
  repeat
    new_pos = new_pos + 1
    if new_pos > j then break end
    local cur = codepoints[new_pos]
    cur_ccc = ccc[cur]
  until (not cur_ccc) or (cur_ccc >= first_ccc)
  new_pos = new_pos - 1
  if new_pos == k then
    return ccc_reorder(codepoints, i, j, k+1)
  end
  move(codepoints, k+1, new_pos, k)
  codepoints[new_pos] = first
  return ccc_reorder(codepoints, i, j, k == i and i or k-1)
end
local result_table = {}
local function get_string()
  local result_table = result_table
  local s = char(unpack(result_table))
  for i=1,#result_table do
    result_table[i] = nil
  end
  return s
end
function to_nfd_table(s, decomposition_mapping)
  local new_codepoints = result_table
  local j = 1
  for _, c in codes(s) do
    local decomposed = decomposition_mapping[c]
    if decomposed then
      move(decomposed, 1, #decomposed, j, new_codepoints)
      j = j + #decomposed
    elseif c >= 0xAC00 and c <= 0xD7A3 then
      c = c - 0xAC00
      local tIndex = c % 28
      c = c // 28
      local vIndex = c % 21
      local lIndex = c // 21
      new_codepoints[j] = 0x1100 + lIndex
      new_codepoints[j+1] = 0x1161 + vIndex
      if tIndex == 0 then
        j = j + 2
      else
        new_codepoints[j+2] = 0x11A7 + tIndex
        j = j + 3
      end
    else
      new_codepoints[j] = c
      j = j + 1
    end
  end
  ccc_reorder(new_codepoints, 1, #new_codepoints, 1)
end
local function to_nfd(s)
  to_nfd_table(s, decomposition_mapping)
  return get_string()
end
local function to_nfkd(s)
  to_nfd_table(s, compatibility_mapping)
  return get_string()
end
local function to_nfc_generic(s, decomposition_mapping)
  to_nfd_table(s, decomposition_mapping)
  local codepoints = result_table
  local starter, lookup, last_ccc, lvt
  local j = 1
  for i, c in ipairs(codepoints) do
    local cur_ccc = ccc[c]
    if lookup then
      if (cur_ccc == nil) == (cur_ccc == last_ccc) then -- unblocked
        local composed = lookup[c]
        if composed then
          codepoints[starter] = composed
          lookup = composition_mapping[composed]
          goto CONTINUE
        end
      end
    elseif lvt then
      if lvt == 1 then
        if c >= 0x1161 and c <= 0x1175 then
          lvt = 2
          codepoints[starter] = ((codepoints[starter] - 0x1100) * 21 + c - 0x1161) * 28 + 0xAC00
          goto CONTINUE
        end
      else -- if lvt == 2 then
        if c >= 0x11A8 and c <= 0x11C2 then
          lvt = nil
          codepoints[starter] = codepoints[starter] + c - 0x11A7
          goto CONTINUE
        end
      end
    end
    codepoints[j] = c
    lvt = nil
    if not cur_ccc then
      starter = j
      lookup = composition_mapping[c]
      if not lookup and c >= 0x1100 and c <= 0x1112 then
        lvt = 1
      end
    end
    j = j + 1
    last_ccc = cur_ccc
    ::CONTINUE::
  end
  for i = j,#codepoints do codepoints[i] = nil end
  return get_string()
end
local function to_nfc(s)
  return to_nfc_generic(s, decomposition_mapping)
end
local function to_nfkc(s)
  return to_nfc_generic(s, compatibility_mapping)
end

return {
  NFD = to_nfd,
  NFC = to_nfc,
  NFKD = to_nfkd,
  NFKC = to_nfkc,
}
-- print(require'inspect'{to_nfd{0x1E0A}, to_nfc{0x1E0A}})

-- print(require'inspect'{to_nfd{0x1100, 0x1100, 0x1161, 0x11A8}, to_nfc{0x1100, 0x1100, 0x1161, 0x11A8}})
