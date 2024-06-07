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


local function Div(el)
  local options_collapse = true
  if (el.classes:includes("cell") and el.attributes["unilur-solution"] == "true") or (el.classes:includes("unilur-solution")) then
    el.attributes["unilur-solution"] = nil
    if quarto.doc.hasBootstrap() or quarto.doc.isFormat("revealjs") then
      quarto.doc.addHtmlDependency({
        name = "unilur",
        version = "0.1.0",
        stylesheets = {"unilur.css"}
      })
    end
    -- Embed solution code/block inside a callout if global option is true
    if options_solution then
      -- collapse callout by default except specified
      if el.attributes["unilur-collapse"] == "false" then
        options_collapse = false
      end
      return {quarto.Callout({
        content =  { el },
        icon = false,
        title = "Solution",
        collapse = options_collapse,
        type = "solution"
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
