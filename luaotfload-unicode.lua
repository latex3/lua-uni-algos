-- lua-uni-case.lua
-- Copyright 2020--2025 Marcel Krüger
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

local utf8codes = utf8.codes
local sub = string.sub
local concat = table.concat

local parse = require'lua-uni-parse'
local empty = {}

local alphnum_only do
  local niceentry = parse.fields(parse.codepoint, parse.ignore_field, lpeg.S'LN' * lpeg.Cc(true) * parse.ignore_field, parse.ignore_line)
  local entry = niceentry + parse.ignore_line

  local data = parse.parse_file('UnicodeData', entry, rawset)
  local result = {}
  function alphnum_only(s)
    local result = result
    for i = #result, 1, -1 do result[i] = nil end
    local nice = nil
    for p, c in utf8codes(s) do
      if data[c]
          or (c >= 0x3400 and c <= 0x3DB5)
          or (c >= 0x4E00 and c <= 0x9FEF)
          or (c >= 0xAC00 and c <= 0xD7A3)
          then
        if not nice then nice = p end
      else
        if nice then
          result[#result + 1] = sub(s, nice, p-1)
          nice = nil
        end
      end
    end
    if nice then
      result[#result + 1] = sub(s, nice, #s)
    end
    return concat(result)
  end
end

local uppercase, lowercase, ccc, cased, case_ignorable, titlecase = {}, {}, {}, {}, {}, nil do
  local codepoint = parse.codepoint
  titlecase = nil -- Not implemented yet(?)
  local ignore_field = parse.ignore_field
  local cased_category = 'L' * lpeg.S'lut'
  local case_ignore_category = lpeg.P'Mn' + 'Me' + 'Cf' + 'Lm' + 'Sk'

  local simple_entry =
    parse.fields(parse.codepoint/0, parse.ignore_field, -- Name
      parse.ignore_field - cased_category - case_ignore_category,
      '0', parse.ignore_line)
  local entry = simple_entry
    + parse.fields(parse.codepoint, parse.ignore_field, -- Name
        cased_category * lpeg.Cc(cased) + case_ignore_category * lpeg.Cc(case_ignorable) + parse.ignore_field * lpeg.Cc(nil), -- General_Category
        '0' * lpeg.Cc(nil) + lpeg.R'09'^1/tonumber, -- ccc
        parse.ignore_field, parse.ignore_field, -- Bidi, Decomp
        parse.ignore_field, parse.ignore_field, -- Numeric, Numeric
        parse.ignore_field, parse.ignore_field, -- Numeric, Mirrored
        parse.ignore_field, parse.ignore_field, -- Obsolete, Obsolete
        (parse.codepoint + lpeg.Cc(nil)), -- uppercase
        (parse.codepoint + lpeg.Cc(nil)), -- lowercase
        (parse.codepoint + lpeg.Cc(nil))) -- titlecase
    / function(codepoint, cased_flag, ccc_val, upper, lower, title)
      if cased_flag then cased_flag[codepoint] = true end
      ccc[codepoint] = ccc_val
      uppercase[codepoint] = upper
      lowercase[codepoint] = lower
      -- if title then titlecase[codepoint] = title end -- Not implemented yet(?)
    end
  assert(parse.parse_file('UnicodeData', entry^0 * -1))
end

local props do
  local ws = lpeg.P' '^0
  local nl = ws * ('#' * (1-lpeg.P'\n')^0)^-1 * '\n'
  local entry = codepoint * (".." * codepoint + lpeg.Cc(false)) * ws * ";" * ws * lpeg.C(lpeg.R("AZ", "az", "__")^1) * nl
  local file = lpeg.Cf(
      lpeg.Ct(
          lpeg.Cg(lpeg.Ct"", "Soft_Dotted")
        * lpeg.Cg(lpeg.Cc(cased), "Other_Lowercase")
        * lpeg.Cg(lpeg.Cc(cased), "Other_Uppercase"))
    * (lpeg.Cg(entry) + nl)^0
  , function(t, cp_start, cp_end, prop)
    local prop_table = t[prop]
    if prop_table then
      for cp = cp_start, cp_end or cp_start do
        prop_table[cp] = true
      end
    end
    return t
  end) * -1

  local f = io.open(kpse.find_file"PropList.txt")
  props = file:match(f:read'*a')
  f:close()
end

do
  local ws = lpeg.P' '^0
  local nl = ws * ('#' * (1-lpeg.P'\n')^0)^-1 * '\n'
  local file = (codepoint * (".." * codepoint + lpeg.Cc(false)) * ws * ";" * ws * (lpeg.P'Single_Quote' + 'MidLetter' + 'MidNumLet') * nl / function(cp_start, cp_end)
    for cp = cp_start, cp_end or cp_start do
      case_ignorable[cp] = true
    end
  end + (1-lpeg.P'\n')^0 * '\n')^0 * -1

  local f = io.open(kpse.find_file"WordBreakProperty.txt")
  assert(file:match(f:read'*a'))
  f:close()
end

do
  local ws = lpeg.P' '^0
  local nl = ws * ('#' * (1-lpeg.P'\n')^0)^-1 * '\n'
  local empty = {}
  local function set(t, cp, condition, value)
    local old = t[cp] or cp
    if not condition then
      if #value == 1 and tonumber(old) then
        t[cp] = value[1]
        return
      end
      condition = empty
    end
    if tonumber(old or cp) then
      old = {_ = {old}}
      t[cp] = old
    end
    for i=1, #condition do
      local cond = condition[i]
      local step = old[cond]
      if not step then
        step = {}
        old[cond] = step
      end
      old = step
    end
    old._ = value
  end
  local entry = codepoint * ";"
              * lpeg.Ct((ws * codepoint)^1 + ws) * ";"
              * lpeg.Ct((ws * codepoint)^1 + ws) * ";"
              * lpeg.Ct((ws * codepoint)^1 + ws) * ";"
              * (lpeg.Ct((ws * lpeg.C(lpeg.R('AZ', 'az', '__')^1))^1) * ";")^-1
              * ws * nl / function(cp, lower, title, upper, condition)
                set(lowercase, cp, condition, lower)
                set(uppercase, cp, condition, upper)
              end
  local file = (entry + nl)^0 * -1

  local f = io.open(kpse.find_file"SpecialCasing.txt")
  assert(file:match(f:read'*a'))
  f:close()
end

do
  local function eq(a, b)
    if not a then return false end
    if not b then return false end
    if a == b then return true end
    if #a ~= #b then return false end
    for i=1,#a do if a[i] ~= b[i] then return false end end
    return true
  end
  local function collapse(t, inherited)
    inherited = t._ or inherited
    local empty = true
    for k,v in next, t do
      if k ~= '_' then
        if eq(inherited, collapse(v, inherited)) then
          t[k] = nil
        else
          empty = false
        end
      end
    end
    return empty and inherited
  end
  local function cleanup(t)
    for k,v in next, t do
      if not tonumber(v) then
        local collapsed = collapse(v)
        if collapsed and #collapsed == 1 then
          v = collapsed[1]
          if k == v then
            v = nil
          end
          t[k] = v
        end
      end
    end
  end
  cleanup(uppercase)
  cleanup(lowercase)
end

-- Here we manipulate the uppercase table a bit to add the `de-alt` language using capital eszett.
uppercase[0x00DF]['de-x-eszett'] = { _ = { 0x1E9E } }
uppercase[0x00DF]['de-alt'] = uppercase[0x00DF]['de-x-eszett']

-- Special handling for Eastern Armenian based on Unicode document L2/20-143.
uppercase[0x0587]['hy'] = { _ = { 0x0535, 0x054E } }
-- Resore Unicode behavior. This entry is redundant, but we have to be aware of it
-- if we later start to ignore unknown private use tags
uppercase[0x0587]['hy-x-yiwn'] = { _ = uppercase[0x0587]._ }

return {
  alphnum_only = alphnum_only,
  casemapping = {
    uppercase = uppercase,
    lowercase = lowercase,
    cased = cased,
    case_ignorable = case_ignorable,
    -- titlecase = titlecase,
  },
  ccc = ccc,
  soft_dotted = props.Soft_Dotted,
}
