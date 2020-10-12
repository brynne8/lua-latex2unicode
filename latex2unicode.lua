local re = require('lpeg.re')
local latex_lib = require('latex_lib')

local trans_pat = {
  subscripts = re.compile("([0-9()aeh-pr-vx+=-] /'β'/'γ'/'ρ'/'φ'/'χ')+ !."),
  superscripts = re.compile("([0-9()a-zABD-PRT-W+=-] /'α'/'β'/'γ'/'δ'/'∊'/'θ'/'ι'/'Φ'/'φ'/'χ')+ !.")
}

local defs = {
  newline = '\n',
  eb = ']'
}

local grammar = re.compile([=[--lpeg
  equation    <- {| (%s* block)+ |}
  block       <- &'\' (space / macro / newline / escape) / subscript / superscript
                  / '{' (equation / {''}) '}' / {[^\{}_^[%eb]}
  space       <- '\' ([,:;! ] / 'q' 'q'? 'uad') -> ' '
  macro       <- {'\' %a+} ('[' -> 'optional' (equation / {''}) ']')?
  newline     <- '\\' -> newline
  escape      <- '\' {.}
  
  subscript   <- {'_'} parameter
  superscript <- {'^'} parameter
  parameter   <-  / { [^%s{}] }
]=], defs)

local function subsup(a, b)
  --print('subsup: ', a, b)
  local dict = latex_lib[a]
  if trans_pat[a]:match(b) then
    return b:gsub('[%z\1-\127\194-\244][\128-\191]*', function(p)
      return dict[p]
    end)
  else
    local stext = (b:ulen() == 1 and b or ('{' .. b .. '}'))
    if a == 'subscripts' then return '_' .. stext
    else return '^' .. stext end
  end
end

local expand_parameter = nil

local function walk(expr, in_parameter)
  local s = ''
  local i, v = 1, expr[i]
  
  local function next_token(prev_token)
      i = i + 1
      local p = expr[i]
      if not p then
        error("Expected group for '" .. prev_token .."'")
      end
      return p
  end
  
  while true do
    v = expr[i]
    if not v then break end
    if type(v) == 'string' then
      if v == '_' then
        local p = next_token('_')
        s = s:gsub(' $', '') .. subsup('subscripts', expand_parameter(p, true))
      elseif v == '^' then
        local p = next_token('^')
        s = s:gsub(' $', '') .. subsup('superscripts', expand_parameter(p, true))
      elseif v:sub(1, 1) == '\\' then
        local func = v:sub(2)
        local a = latex_lib[func]
        if a then
          if type(a) == 'string' then
            s = s .. a
          elseif not a.arg_num then
            local b = expand_parameter(next_token(func), true)
            s = s .. b:gsub('[%z\1-\127\194-\244][\128-\191]*', function(p)
              return a[p]
            end)
          else
            local arguments = {}
            local op_arg = nil
            local j = 1
            while j <= a.arg_num do
              local the_arg = expand_parameter(next_token(func .. '#' .. j), true)
              if the_arg == 'optional' then
                op_arg = expand_parameter(next_token(func), true)
                j = j - 1
              else
                arguments[j] = the_arg
              end
              j = j + 1
            end
            if op_arg then
              table.insert(arguments, op_arg)
            end
            local sp = a.space and ' ' or ''
            s = s .. sp .. a.func(unpack(arguments)) .. sp
          end
        else
          error('Unsupported macro: ' .. func)
        end
      else -- simple string
        if in_parameter then
          s = s .. v
        else
          local it = latex_lib.textit
          s = s .. v:gsub('[%z\1-\127\194-\244][\128-\191]*', function(p)
            return it[p]
          end)
        end
      end
    else -- table
      s = s .. walk(v, in_parameter)
    end
    i = i + 1
  end
  return (s:gsub('^ ', ''):gsub(' $', ''))
end

local inspect = require('inspect')

expand_parameter = function(p, in_parameter)
  --print('expand_parameter', p)
  if type(p) == 'string' then
    if #p > 1 and p:sub(1, 1) == '\\' then
      local res = latex_lib[p:sub(2)]
      if type(res) ~= 'string' then
        error('Expected group instead of macro: ' .. p)
      end
      return res
    else
      return p
    end
  else -- table
    return walk(p, in_parameter)
  end
end

local tree = grammar:match([[
\mathbb{AB}
]])
print(inspect(tree))

print(walk(tree))
