-- lua-uni-case.lua
-- Copyright 2020--2022 Marcel Krüger
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

local unpack = table.unpack
local move = table.move
local codes = utf8.codes
local utf8char = utf8.char

local parse = require'lua-uni-parse'

local empty = {}

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
        '0' * lpeg.Cc(nil) + parse.number, -- ccc
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

local soft_dotted do
  local entry = parse.fields(parse.codepoint_range, lpeg.C(lpeg.R("AZ", "az", "__")^1))
  soft_dotted = parse.parse_file('PropList', lpeg.Cf(
      lpeg.Ct(
          lpeg.Cg(lpeg.Ct'', 'Soft_Dotted')
        * lpeg.Cg(lpeg.Cc(cased), 'Other_Lowercase')
        * lpeg.Cg(lpeg.Cc(cased), 'Other_Uppercase'))
    * (lpeg.Cg(entry) + parse.eol)^0
  , function(t, cp_start, cp_end, prop)
    local prop_table = t[prop]
    if prop_table then
      for cp = cp_start, cp_end or cp_start do
        prop_table[cp] = true
      end
    end
    return t
  end) * -1).Soft_Dotted
end

do
  assert(parse.parse_file('WordBreakProperty', (parse.fields(
    parse.codepoint_range,
    lpeg.P'Single_Quote' + 'MidLetter' + 'MidNumLet'
  ) / function(cp_start, cp_end)
    for cp = cp_start, cp_end or cp_start do
      case_ignorable[cp] = true
    end
  end + parse.ignore_line)^0 * -1))
end

do
  local ws = lpeg.P' '^0
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
  local entry = parse.fields(parse.codepoint,
                  lpeg.Ct((ws * parse.codepoint)^0),
                  lpeg.Ct((ws * parse.codepoint)^0),
                  lpeg.Ct((ws * parse.codepoint)^0),
                  (lpeg.Ct((lpeg.P' '^0 * lpeg.C(lpeg.R('AZ', 'az', '__')^1))^1) * ";")^-1)
              / function(cp, lower, title, upper, condition)
                set(lowercase, cp, condition, lower)
                set(uppercase, cp, condition, upper)
              end
  assert(parse.parse_file('SpecialCasing', (entry + parse.eol)^0 * -1))
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

local casefold, casefold_lookup do
  local p = require'lua-uni-parse'
  local l = lpeg or require'lpeg'
  local result = {}

  local data = p.parse_file('CaseFolding', l.Cf(
      l.Ct(l.Cg(l.Ct'', 'C') * l.Cg(l.Ct'', 'F') * l.Cg(l.Ct'', 'S') * l.Cg(l.Ct'', 'T'))
    * (l.Cg(p.fields(p.codepoint, l.C(1), l.Ct(p.codepoint * (' ' * p.codepoint)^0), true)) + p.eol)^0
    * -1
  , function(t, base, class, mapping)
    t[class][base] = mapping
    return t
  end))
  local C, F, S, T = data.C, data.F, data.S, data.T
  data = nil

  function casefold_lookup(c, full, special)
    return (special and T[c]) or C[c] or (full and F or S)[c]
  end
  function casefold(s, full, special)
    local first = special and T or empty
    local second = C
    local third = full and F or S
    local result = result
    for i = #result, 1, -1 do result[i] = nil end
    local i = 1
    for _, c in codes(s) do
      local datum = first[c] or second[c] or third[c]
      if datum then
        local l = #datum
        move(datum, 1, l, i, result)
        i = i + l
      else
        result[i] = c
        i = i + 1
      end
    end
    return utf8char(unpack(result))
  end
end

if not tex or tex.initialize then
  return {
    casefold = casefold,
    casefold_lookup = casefold_lookup,
  }
end

local direct = node.direct
local is_char = direct.is_char
local has_glyph = direct.has_glyph
local uses_font = direct.uses_font
local getnext = direct.getnext
local setchar = direct.setchar
local setdisc = direct.setdisc
local getdisc = direct.getdisc
local getfield = direct.getfield
local remove = direct.remove
local free = direct.free
local copy = direct.copy
local insert_after = direct.insert_after
local traverse = direct.traverse

local disc = node.id'disc'

--[[ We make some implicit assumptions about contexts in SpecialCasing.txt here which happened to be true when I wrote the code:
--
-- * Before_Dot only appears as Not_Before_Dot
-- * No other context appears with Not_
-- * Final_Sigma is never language dependent
-- * Other contexts are always language dependent
-- * The only languages with special mappings are Lithuanian (lt/"LTH "/lit), Turkish (tr/"TRK "/tur), and Azeri/Azerbaijani (az/"AZE "/aze)
--   (Additionally we add special mappings for de-x-eszett, el, el-x-iota, hy-x-yiwn which are not present in SpecialCasing.txt)
]]

local UPPER_MASK = 0x3FF
local HAS_VOWEL = 0x200000
local HAS_YPOGEGRAMMENI = 0x400000
local HAS_ACCENT = 0x800000
local HAS_DIALYTIKA = 0x1000000
local HAS_OTHER_GREEK_DIACRITIC = 0x2000000

local greek_data
local greek_diacritic = {
  [0x0300] = HAS_ACCENT,
  [0x0301] = HAS_ACCENT,
  [0x0342] = HAS_ACCENT,
  [0x0302] = HAS_ACCENT,
  [0x0303] = HAS_ACCENT,
  [0x0311] = HAS_ACCENT,
  [0x0308] = HAS_DIALYTIKA,
  [0x0344] = HAS_DIALYTIKA | HAS_ACCENT,
  [0x0345] = HAS_YPOGEGRAMMENI,
  [0x0304] = HAS_OTHER_GREEK_DIACRITIC,
  [0x0306] = HAS_OTHER_GREEK_DIACRITIC,
  [0x0313] = HAS_OTHER_GREEK_DIACRITIC,
  [0x0314] = HAS_OTHER_GREEK_DIACRITIC,
  [0x0343] = HAS_OTHER_GREEK_DIACRITIC,
}

local greek_precombined_iota = {
  [0x0391] = 0x1FBC,
  [0x0397] = 0x1FCC,
  [0x03A9] = 0x1FFC,
}

-- Greek handling based on https://icu.unicode.org/design/case/greek-upper
-- with smaller variations since we ant to preserve nodes whenever possible.
local function init_greek_data()
  local NFD = require'lua-uni-normalize'.NFD
  local data = {}
  greek_data = data

  local vowels = {
    [utf8.codepoint'Α'] = true, [utf8.codepoint'Ε'] = true,
    [utf8.codepoint'Η'] = true, [utf8.codepoint'Ι'] = true,
    [utf8.codepoint'Ο'] = true, [utf8.codepoint'Ω'] = true,
    [utf8.codepoint'Υ'] = true,
  }
  local function handle_char(c)
    local decomp = NFD(utf8.char(c))
    local first = utf8.codepoint(decomp)
    local upper = uppercase[first]
    if upper then
      if not tonumber(upper) then
        upper = upper._
        assert(#upper == 1)
        upper = upper[1]
      end
    else
      upper = first
    end
    if upper > UPPER_MASK then return end -- Only happens for unassigned codepoints
    local datum = upper
    if vowels[upper] then
      datum = datum | HAS_VOWEL
    end
    if utf8.len(decomp) > 1 then
      for _, c in utf8.codes(decomp) do
        local dia = greek_diacritic[c]
        if dia and dia ~= HAS_OTHER_GREEK_DIACRITIC then datum = datum | dia end
      end
    end
    data[c] = datum
  end
  for c = 0x0370, 0x03ff do handle_char(c) end
  for c = 0x1f00, 0x1fff do handle_char(c) end
  for c = 0x2126, 0x2126 do handle_char(c) end
end

local function font_lang(feature)
  return setmetatable({}, {__index = function(t, fid)
    local f = font.getfont(fid)
    local features = f.specification.features.normal
    local lang = features[feature]
    if type(lang) ~= 'string' or lang == 'auto' then
      lang = features.language
      lang = lang == 'lth' and 'lt'
          or lang == 'trk' and 'tr'
          or lang == 'aze' and 'az'
          or lang == 'hye' and 'hy'
          or (lang == 'ell' or lang == 'pgr') and 'el'
          or false
    end
    t[fid] = lang
    return lang
  end})
end

local function is_followed_by_cased(font, n, after)
  n = getnext(n)
  repeat
    while n do
      local char, id = is_char(n, font)
      if not char and id == disc then
        after = getnext(n)
        n = getfield(n, 'replace')
        char, id = is_char(n, font)
      end
      if char then
        if not case_ignorable[char] then
          return cased[char]
        end
        n = getnext(n)
      else
        return false
      end
    end
    n, after = after
  until not n
  return false
end

local function is_Final_Sigma(font, mapping, n, after)
  mapping = mapping.Final_Sigma
  if not mapping then return false end
  mapping = mapping._
  if not mapping then return false end
  return not is_followed_by_cased(font, n, after) and mapping
end

local function is_More_Above(font, mapping, n, after)
  mapping = mapping.More_Above
  if not mapping then return false end
  mapping = mapping._
  if not mapping then return false end
  n = getnext(n)
  repeat
    while n do
      local char, id = is_char(n, font)
      if id == disc then
        after = getnext(n)
        n = getfield(n, 'replace')
        char, id = is_char(n, font)
      elseif char then
        local char_ccc = ccc[char]
        if not char_ccc then
          return false
        elseif char_ccc == 230 then
          return mapping
        end
        n = getnext(n)
      else
        return false
      end
    end
    n, after = after
  until not n
  return false
end

local function is_Not_Before_Dot(font, mapping, n, after)
  mapping = mapping.Not_Before_Dot
  if not mapping then return false end
  mapping = mapping._
  if not mapping then return false end
  n = getnext(n)
  repeat
    while n do
      local char, id = is_char(n, font)
      if id == disc then
        after = getnext(n)
        n = getfield(n, 'replace')
        char, id = is_char(n, font)
      elseif char then
        local char_ccc = ccc[char]
        if not char_ccc then
          return mapping
        elseif char_ccc == 230 then
          return char ~= 0x0307 and mapping
        end
        n = getnext(n)
      else
        return mapping
      end
    end
    n, after = after
  until not n
  return mapping
end

local function is_Language_Mapping(font, mapping, n, after, seen_soft_dotted, seen_I)
  if not mapping then return false end
  if seen_soft_dotted then
    local mapping = mapping.After_Soft_Dotted
    mapping = mapping and mapping._
    if mapping then
      return mapping
    end
  end
  if seen_I then
    local mapping = mapping.After_I
    mapping = mapping and mapping._
    if mapping then
      return mapping
    end
  end
  return is_More_Above(font, mapping, n, after) or is_Not_Before_Dot(font, mapping, n, after) or mapping._ -- Might be nil
end

local function process(table, feature)
  local font_lang = font_lang(feature)
  -- The other seen_... are booleans, while seen_greek has more states:
  --   - nil: Not greek
  --   - true: Greek. Last was not a vowel with accent and without dialytika
  --   - node: Greek. Last vowel with accent and without dialytika
  local function processor(head, font, after, seen_cased, seen_soft_dotted, seen_I, seen_greek)
    local lang = font_lang[font]
    local greek, greek_iota
    if lang == 'el' or lang == 'el-x-iota' then
      if table == uppercase then
        if not greek_data then
          init_greek_data()
        end
        greek, greek_iota = greek_data, lang == 'el-x-iota'
      end
      lang = false
    end
    local n = head
    while n do
      do
        local new = has_glyph(n)
        if n ~= new then
          seen_cased, seen_soft_dotted, seen_I, seen_greek = nil
        end
        n = new
      end
      if not n then break end
      local char, id = is_char(n, font)
      if char then
        if greek and (char >= 0x0370 and char <= 0x03ff or char >= 0x1f00 and char <= 0x1fff or char == 0x2126) then
          -- In the greek uppercase situation we want to remove diacritics except under some exceptions.
          local first_datum = greek[char] or 0
          local datum = first_datum
          local upper = datum & UPPER_MASK
          -- When a vowel ges an accent removed and does not have a dialytika and is followed by a Ι or Υ,
          -- then this iota or ypsilon gets a dialytika.
          if datum & HAS_VOWEL ~= 0 and seen_greek and seen_greek ~= true and (upper == 0x0399 or upper == 0x03a5) then
            datum = datum | HAS_DIALYTIKA;
          end
          local has_ypogegrammeni = datum & HAS_YPOGEGRAMMENI ~= 0
          local add_ypogegrammeni = has_ypogegrammeni
          local post = getnext(n)
          local last
          local saved_tonos, saved_dialytika
          while post do
            local char = is_char(post, font)
            if not char then break end
            local diacritic_data = greek_diacritic[char]
            if not diacritic_data then break end
            -- Preserve flags to be aware if a dialytika has to be reinserted
            -- TODO: Keep dialytika node around
            datum = datum | diacritic_data
            -- Preserve ypogegrammeni (iota subscript) but convert them into capital iotas.
            -- If el-x-iota is active keep the combining character instead.
            if diacritic_data & HAS_YPOGEGRAMMENI ~= 0 then
              has_ypogegrammeni = true
              if not greek_iota then
                setchar(post, 0x0399)
              end
              last = post
              post = getnext(post)
            else
              -- Otherwise they get removed
              local old = post
              head, post = remove(head, post)
              if char == 0x0301 and not saved_tonos then
                -- But if we have a tonos we might want to reinsert it later
                saved_tonos = old
              elseif diacritic_data & HAS_DIALYTIKA ~= 0 and not saved_dialytika then
                -- Similar for dilytika
                saved_dialytika = old
              else
                free(old)
              end
            end
          end
          -- Special case: An isolated Ή preserves the tonos.
          if upper == 0x0397
              and not has_ypogegrammeni
              and not seen_cased
              and not is_followed_by_cased(font, n, after)
              then
            if first_datum & HAS_ACCENT ~= 0 then
              upper = 0x0389
              -- If it's precomposed we don't have to keep any combining accents
              if saved_tonos then
                free(saved_tonos)
                saved_tonos = nil
              end
            end
          else
            -- Not the special case so we don't have to keep the tonos node
            if saved_tonos then
              free(saved_tonos)
              saved_tonos = nil
            end
            -- Handle precomposed dialytika. If both a combining ans a precomposed
            -- dialyika are present (typically because the precomposed one is
            -- automatically added at the beginning) prefer the combining one to
            -- preserve attributes.
            if datum & HAS_DIALYTIKA ~= 0 and not saved_dialytika then
              if upper == 0x0399 then -- upper == 'Ι'
                upper = 0x03AA
              elseif upper == 0x03A5 then -- upper == 'Υ'
                upper = 0x03AB
              else
                assert(false) -- Should not be possible
              end
            end
          end
          if greek_iota and add_ypogegrammeni then
            local mapped = greek_precombined_iota[upper]
            if mapped then -- AFAICT always true
              upper = mapped
              add_ypogegrammeni = false
            end
          end
          setchar(n, upper)
          -- Potentially reinsert accents
          if saved_dialytika then
            head, n = insert_after(head, n, saved_dialytika)
            setchar(n, 0x0308) -- Needed since we might have a U+0344 (COMBINING GREEK DIALYTIKA TONOS)
          end
          if saved_tonos then
            head, n = insert_after(head, n, saved_tonos)
          end
          if add_ypogegrammeni then
            head, n = insert_after(head, n, copy(n))
            setchar(n, 0x0399)
          end
          -- If we preserved any combining ypogegrammeni nodes, skip them now
          n = last or n
          seen_greek = datum & (HAS_VOWEL | HAS_ACCENT | HAS_DIALYTIKA) == HAS_VOWEL | HAS_ACCENT and n or true
          seen_I, seen_soft_dotted = nil
        else
          local mapping = table[char]
          if mapping then
            if tonumber(mapping) then
              setchar(n, mapping)
            else
              mapping = seen_cased and is_Final_Sigma(font, mapping, n, after)
                     or lang and is_Language_Mapping(font, mapping[lang], n, after, seen_soft_dotted, seen_I)
                     or mapping._
              if #mapping == 0 then
                local old = n
                head, n = remove(head, n)
                free(old)
                goto continue
              else
                setchar(n, mapping[1])
                for i=2, #mapping do
                  head, n = insert_after(head, n, copy(n))
                  setchar(n, mapping[i])
                end
              end
            end
          end
          local char_ccc = ccc[char]
          if not char_ccc or char_ccc == 230 then
            seen_I = char == 0x49 or nil
            seen_soft_dotted = soft_dotted[char]
          end
          seen_greek = nil
        end
        if not case_ignorable[char] then
          seen_cased = cased[char] or nil
        end
      elseif id == disc and uses_font(n, font) then
        local pre, post, rep = getdisc(n)
        local after = getnext(n)
        pre, post, rep, seen_cased, seen_soft_dotted, seen_I, seen_greek =
            processor(pre, font, nil, seen_cased, seen_soft_dotted, seen_I, seen_greek),
            processor(post, font, after, seen_greek),
            processor(rep, font, after, seen_cased, seen_soft_dotted, seen_I, seen_greek)
        setdisc(n, pre, post, rep)
      else
        seen_cased, seen_soft_dotted, seen_I = nil
      end
      n = getnext(n)
      ::continue::
    end
    return head, seen_cased, seen_soft_dotted, seen_I, seen_greek
  end
  return function(head, font, ...) return (processor(head, font)) end
end

return {
  casefold = casefold,
  casefold_lookup = casefold_lookup,
  font = {
    uppercase = process(uppercase, 'upper'),
    lowercase = process(lowercase, 'lower'),
  },
}
