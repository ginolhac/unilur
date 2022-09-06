-- Inspired from JJAlaire
-- https://github.com/quarto-ext/code-filename/blob/main/_extensions/code-filename/code-filename.lua
-- And Andrie
-- https://github.com/andrie/reveal-auto-agenda/blob/main/_extensions/reveal-auto-agenda/reveal-auto-agenda.lua

local options_solution = nil
-- permitted options include:
-- solution: true/false
local function read_meta(meta)
  local options = meta["unilur"]
  -- options_solution = false
  -- if options == nil then return meta end
  if options ~= nil then
    if options.solution ~= nil then
      options_solution = options.solution
    end
  end
end

local function codeBlockWithSolution(el)
  local solutionEl = pandoc.Div({pandoc.Plain{
    pandoc.RawInline("html", "<pre>"),
    pandoc.Strong{"Solution"},  -- pandoc.utils.stringify(options_solution) pandoc.Strong{"Solution"}
    pandoc.RawInline("html", "</pre>")
  }}, pandoc.Attr("", {"code-with-solution-header"}))
  return pandoc.Div(
    { solutionEl, el:clone() },
    pandoc.Attr("", {"code-with-solution"})
  )
end

local function scan_blocks(blocks)

  -- transform ast for 'solution'
  local foundSolution = false
  local newBlocks = pandoc.List()
  for _,block in ipairs(blocks) do
    if block.attributes ~= nil and block.attributes["solution"] and options_solution then --options_solution ~= nil then
      local solution = block.attributes["solution"]
      if block.t == "CodeBlock" then
        foundSolution = true
        block.attributes["solution"] = nil
        newBlocks:insert(codeBlockWithSolution(block))
      elseif block.t == "Div" and block.content[1].t == "CodeBlock" then
        foundSolution = true
        block.attributes["solution"] = nil
        block.content[1] = codeBlockWithSolution(block.content[1], solution)
        newBlocks:insert(block)
      else
        newBlocks:insert(block)
      end
    else
      newBlocks:insert(block)
    end
  end

  -- if we found a solution then return the modified list of blocks
  if foundSolution then
    -- inject css for bootstrap and reveal
    if quarto.doc.hasBootstrap() or quarto.doc.isFormat("revealjs") then
      quarto.doc.addHtmlDependency({
        name = "unilur",
        version = "0.0.1",
        stylesheets = {"unilur.css"}
      })
    end
    return newBlocks
  else
    return blocks
  end
end


-- Run in two passes so we process metadata
-- and then process the divs
return {
  {Meta = read_meta},
  {Blocks = scan_blocks}
}
