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
  pmod = {
    arg_num = 1,
    space = true,
    func = function(a)
      return '(mod ' .. a .. ')'
    end
  },
  sqrt = {
    arg_num = 1,
    func = function(a, index)
      local prefix = ''
      if not index or index == '2' then prefix = '√'
      elseif index == '3' then prefix = '∛'
      elseif index == '4' then prefix = '∜'
      else prefix = '[' .. index .. ']√' end
      return prefix .. a
    end
  }
}

local echo = {
  arg_num = 1,
  func = function(a) return a end
}

latex_lib.dfrac = latex_lib.frac
latex_lib.textrm = echo
latex_lib.left = echo
latex_lib.right = echo
latex_lib.mathrm = latex_lib.textrm

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

function load_data(name, alias)
  local f, err = io.open('data/' .. name)
  if not f then
    return print(err)
  end
  latex_lib[name] = {}
  for line in f:lines() do
    local cmd, char = line:match('^(%S+) (.+)$')
    if cmd and char then
      latex_lib[name][cmd] = char
    end
  end
  if alias then latex_lib[alias] = latex_lib[name] end
end

load_data('subscripts')
load_data('superscripts')
load_data('textbb', 'mathbb')
load_data('textbf', 'mathbf')
load_data('textcal', 'mathcal')
load_data('textfrak', 'mathfrak')
load_data('textit', 'mathit')
load_data('textmono', 'mathtt')

-- math operators
local operators = {
  'arcsin', 'arccos', 'arctan', 'arctg', 'arcctg',
  'arg', 'ch', 'cos', 'cosec', 'cosh', 'cot', 'cotg',
  'coth', 'csc', 'ctg', 'cth', 'deg', 'dim', 'exp',
  'hom', 'ker', 'lg', 'ln', 'log', 'sec', 'sin',
  'sinh', 'sh', 'tan', 'tanh', 'tg', 'th',
}

for _, v in ipairs(operators) do
  latex_lib[v] = {
    arg_num = 0,
    space = true,
    func = function() return v end
  }
end

return latex_lib
