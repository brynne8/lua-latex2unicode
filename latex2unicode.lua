local re = require('lpeg.re')

function string:ulen()
  return select(2, self:gsub('[^\128-\193]', ''))
end

local latex_lib = {
  frac = {
    arg_num = 2,
    func = function(a, b)
      local a = a:ulen() == 1 and a or ('(' .. a .. ')')
      local b = b:ulen() == 1 and b or ('(' .. b .. ')')
      return a .. '/' .. b
    end
  },
  mathrm = {
    arg_num = 1,
    func = function(a) return a end
  }
}

latex_lib.dfrac = latex_lib.frac

do
  local status, err = pcall(function()
    for line in io.lines('data/symbols') do
      local cmd, char = line:match('^\\(%w+) (.+)$')
      if cmd and char then
        latex_lib[cmd] = char
      end
    end
  end)
  if not status then
    print(err)
  end
end

local trans_data = {}
local trans_pat = {
  subscripts = re.compile("([0-9()aeh-pr-vx+=-] /'β'/'γ'/'ρ'/'φ'/'χ')+ !."),
  superscripts = re.compile("([0-9()a-zABD-PRT-W+=-] /'α'/'β'/'γ'/'δ'/'∊'/'θ'/'ι'/'Φ'/'φ'/'χ')+ !.")
}

function load_data(name)
  local f, err = io.open('data/' .. name)
  if not f then
    return print(err)
  end
  trans_data[name] = {}
  for line in f:lines() do
    local cmd, char = line:match('^(%S+) (.+)$')
    if cmd and char then
      trans_data[name][cmd] = char
    end
  end
end

load_data('subscripts')
load_data('superscripts')

local defs = {
  merge = function(a, b)
    --print('merge', a, b)
    return a .. b
  end,
  gen_macro = function(a, b, c)
    --print('gen_macro', a, b, c)
    local func_name = a
    if latex_lib[a] then
      a = latex_lib[a]
      --print(a)
      if type(a) == 'string' then
        if b then return a .. b .. (c or '')
        else return a end
      elseif a.arg_num then
        if a.arg_num == 1 then
          return a.func(b) .. (c or '')
        elseif a.arg_num == 2 then
          if not c then error(func_name .. ' second parameter cannot be nil') end
          return a.func(b, c)
        else
          error('unsupported number of arguments')
        end
      end
    elseif b then return a .. ' ' .. b .. (c and (' ' .. c) or '')
    else return a end
  end,
  transform = function(a, b)
    --print('transform', a, b)
    if a == 'subscripts' or a == 'superscripts' then
      if trans_pat[a]:match(b) then
        return b:gsub('[%z\1-\127\194-\244][\128-\191]*', function(p)
          return trans_data[a][p]
        end)
      else
        local stext = (b:ulen() == 1 and b or ('{' .. b .. '}'))
        if a == 'subscripts' then return '_' .. stext
        else return '^' .. stext end
      end
    else
      return b:gsub('[%z\1-\127\194-\244][\128-\191]*', function(p)
        return trans_data[a][b]
      end)
    end
  end
}

local grammar = re.compile([=[--lpeg
  equation  <- block+ ~> merge
  block     <- space / macro / subscript / superscript / parameter / {[^{}]}
  space     <- '\' ([,:;! ] / 'q'? 'quad') -> ' '
  bare_macro <- ('\' {%a+} ) -> gen_macro
  macro     <- ('\' {%a+} (parameter parameter?)? ) -> gen_macro
  subscript <- ('_' ''->'subscripts' parameter )  -> transform
  superscript  <- ('^' ''->'superscripts' parameter )  -> transform
  parameter <- '{' equation '}' / bare_macro / { [^%s^_{}] }
]=], defs)

print(grammar:match([[B' =-\nabla \times E]]))
