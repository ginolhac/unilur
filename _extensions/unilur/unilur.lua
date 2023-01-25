-- Inspired from JJAlaire
-- https://github.com/quarto-ext/code-filename/blob/main/_extensions/code-filename/code-filename.lua
-- And Andrie
-- https://github.com/andrie/reveal-auto-agenda/blob/main/_extensions/reveal-auto-agenda/reveal-auto-agenda.lua
-- With precious help from Christophe Dervieux

local options_solution = nil
-- permitted options include:
-- solution: true/false
local function read_meta(meta)
  local options = meta["show-solution"]
  if options ~= nil then
    options_solution = options
  end
end


function Div(el)
  if el.classes:includes("cell") and el.attributes["unilur-solution"] == "true" then
    el.attributes["unilur-solution"] = nil
    -- Embed solution code/block inside a callout if global option is true
    if options_solution then
      return {quarto.Callout({
        content =  { el },
        caption = "Solution",
        collapse = true,
        type = "note"
        })}
    else
      return {} -- remove the solution chunks for questions
    end
  end
end


-- Run in two passes so we process metadata
-- and then process the divs
return {
  {Meta = read_meta},
  {Div = Div}
}
