-- Inspired from JJAlaire
-- https://github.com/quarto-ext/code-filename/blob/main/_extensions/code-filename/code-filename.lua
-- And Andrie
-- https://github.com/andrie/reveal-auto-agenda/blob/main/_extensions/reveal-auto-agenda/reveal-auto-agenda.lua
-- With precious help from Christophe Dervieux

local options_solution = nil
local exr_counter = 0 -- add a counter
local sol_counter = 0 -- add a counter
local comment_counter = 0 -- add a counter

-- permitted options include:
-- solution: true/false
local function read_meta(meta)
  local options = meta["show-solution"]
  if options ~= nil then
    options_solution = options
  end
end

-- helper function for rendering cell-code and cell-output for PDF format
local function stringify_blocks(blocks)
  local out = {}
  for _, block in ipairs(blocks) do
    if block.t == "CodeBlock" then
      table.insert(out, "\\begin{verbatim}\n" .. block.text .. "\n\\end{verbatim}")
    elseif block.t == "Para" or block.t == "Plain" then
      local text = pandoc.utils.stringify(block.content)
      table.insert(out, text .. "\n")
    elseif block.t == "Div" then
      -- Look for cell-output (result of code)
      if block.classes:includes("cell-output") then
        -- Recursively stringify contents
        for _, inner in ipairs(block.content) do
          if inner.t == "CodeBlock" then
            table.insert(out, "\\begin{verbatim}\n" .. inner.text .. "\n\\end{verbatim}")
          elseif inner.t == "Para" or inner.t == "Plain" then
            table.insert(out, pandoc.utils.stringify(inner.content) .. "\n")
          else
            table.insert(out, "% [unhandled output block: " .. inner.t .. "]")
          end
        end
      end
    else
      table.insert(out, "% [unhandled block: " .. block.t .. "]")
    end
  end
  return table.concat(out, "\n")
end

local function Div(el)
  local options_collapse = true
  -- Modify the numbering of the exercises
  -- Default for exr is 1.1, 1.2 with a heading mandatory
  if el.identifier:match("^exr%-") or el.classes:includes("exr") then
    exr_counter = exr_counter + 1

    -- Add a heading-style line with flat numbering
    local heading = pandoc.Para{
      pandoc.Strong{pandoc.Str("Exercise " .. exr_counter .. " ")}
    }

    -- Insert at top of the content
    table.insert(el.content, 1, heading)

    return el
  end

  -- Solution callout
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

      -- Increment solution counter
      sol_counter = sol_counter + 1

      if quarto.doc.isFormat("pdf") then
        local latex_content = stringify_blocks(el.content)
        local title = "Solution " .. sol_counter .. " "
        return pandoc.RawBlock("latex", string.format("\\begin{callout-solution}[]{\\textbf{%s}}\n%s\n\\end{callout-solution}", title, latex_content))
      else
        return {quarto.Callout({
          content =  { el },
          icon = false,
          title = pandoc.Para{pandoc.Strong("Solution " .. sol_counter .. " ")}, -- Solution text in bold with number
          collapse = options_collapse,
          type = "solution"
        })}
      end
    else
      return {} -- remove the solution chunks for questions
    end
  end

  -- Comment callout
  if (el.classes:includes("cell") and el.attributes["unilur-comment"] == "true") or (el.classes:includes("unilur-comment")) then
    el.attributes["unilur-comment"] = nil
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

      -- Increment comment counter
      comment_counter = comment_counter + 1

      if quarto.doc.isFormat("pdf") then
        local latex_content = stringify_blocks(el.content)
        local title = "Comment " .. comment_counter .. " "
        return pandoc.RawBlock("latex", string.format("\\begin{callout-comment}[]{\\textbf{%s}}\n%s\n\\end{callout-comment}", title, latex_content))
      else
        return {quarto.Callout({
          content =  { el },
          icon = false,
          title = pandoc.Para{pandoc.Strong("Comment " .. comment_counter .. " ")},
          collapse = options_collapse,
          type = "comment"
        })}
      end
    else
      return {} -- remove the comment chunks for questions
    end
  end
end

-- Run in two passes so we process metadata
-- and then process the divs
return {
  {Meta = read_meta},
  {Div = Div}
}
