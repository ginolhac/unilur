-- Inspired from JJAlaire
-- https://github.com/quarto-ext/code-filename/blob/main/_extensions/code-filename/code-filename.lua
-- And Andrie
-- https://github.com/andrie/reveal-auto-agenda/blob/main/_extensions/reveal-auto-agenda/reveal-auto-agenda.lua
-- With precious help from Christophe Dervieux


local options_solution = nil
local exr_counts, sol_counts, comment_counts, question_counts = {}, {}, {}, {} -- counters for numbering exercises, solutions, comments, questions
local section_numbers = {} -- track header numbers for hierarchical numbering
local total_points = 0 -- total points for the exam
local last_question_prefix = nil -- last question prefix used for linking solutions/comments
local question_registry = {} -- registry to store all questions for summary table
local current_section_title = "" -- current header titles
local top_section_title = "" -- only stores first-level (#) header title

-- Counters for old .exr / solution / comment numbering
local exr_counter = 0
local sol_counter = 0
local comment_counter = 0


-- === Read metadata ===
-------------------------
-- Reads the YAML metadata for options (e.g., show-solution)
-- permitted options include:
-- solution: true/false
local function read_meta(meta)
  local options = meta["show-solution"]
  if options ~= nil then options_solution = options end
end


-- === Header tracking ===
--------------------------
-- Updates numbering and stores section titles whenever a header is encountered
function Header(el)
  local level = el.level
  
  -- Extend or trim the section_numbers table to match header level
  while #section_numbers < level do table.insert(section_numbers, 0) end
  while #section_numbers > level do table.remove(section_numbers) end
  
  -- Increment counter for this header level
  section_numbers[level] = (section_numbers[level] or 0) + 1
  
  -- Reset deeper levels
  for i = level + 1, #section_numbers do section_numbers[i] = nil end
  
  -- Store header titles
  current_section_title = pandoc.utils.stringify(el.content)
  if level == 1 then
   top_section_title = current_section_title -- only first-level headers for summary
  end
  
  -- Reset counters for each new header (start numbering fresh within this section)
  exr_counts, sol_counts, comment_counts, question_counts = {}, {}, {}, {}
  last_question_prefix = nil
  
  return el
end


-- === Helper: current setion prefix for numbering ===
------------------------------------------------------
local function current_section_prefix()
  if #section_numbers == 0 then return "" end
  return table.concat(section_numbers, ".") -- e.g., "1.2" for section 1, subsection 2
end 


-- === Helper: answer lines for exam questions ===
---------------------------------------------------
-- Generates empty lines for students to write answers
local function answer_lines(n)
  local blocks = {}
  for i = 1, n do
    if quarto.doc.isFormat("pdf") then
    -- LaTeX dotted line
      table.insert(blocks, pandoc.RawBlock("latex", "\\noindent\\dotfill\\par\\vspace{0.3em}")) -- can control the space between the lines
    else
    -- HTML dotted line
      table.insert(blocks, pandoc.RawBlock("html", "<div class='answer-line dotted'>&nbsp;</div>"))
    end
  end
  return blocks
end


-- === Helper: hierarchical numbering for exercises/questions ===
-----------------------------------------------------------------
local function make_numbered_prefix(count_table)
  local depth = #section_numbers + 1 -- one deeper than current header level
  count_table[depth] = (count_table[depth] or 0) + 1
  local section_pref = current_section_prefix()
  if section_pref == "" then
    return tostring(count_table[depth])
  else
    return section_pref .. "." .. tostring(count_table[depth])
  end
end

-- === Helper: stringify blocks for LaTeX output (used in solutions/comments) ===
local function stringify_blocks(blocks)
  local out = {}
  for _, block in ipairs(blocks) do
    if block.t == "CodeBlock" then
      table.insert(out, "\\begin{verbatim}\n" .. block.text .. "\n\\end{verbatim}")
    elseif block.t == "Para" or block.t == "Plain" then
      table.insert(out, pandoc.utils.stringify(block.content) .. "\n")
    elseif block.t == "Div" and block.classes:includes("cell-output") then
      for _, inner in ipairs(block.content) do
        if inner.t == "CodeBlock" then
          table.insert(out, "\\begin{verbatim}\n" .. inner.text .. "\n\\end{verbatim}")
        elseif inner.t == "Para" or inner.t == "Plain" then
          table.insert(out, pandoc.utils.stringify(inner.content) .. "\n")
        else
          table.insert(out, "% [unhandled output block: " .. inner.t .. "]")
        end
      end
    else
      table.insert(out, "% [unhandled block: " .. block.t .. "]")
    end
  end
  return table.concat(out, "\n")
end


-- === Main Div handler ===
----------------------------
local function Div(el)
  local options_collapse = true

  ---------------------------------------------------------
  -- Exercise (.exr)
  ---------------------------------------------------------
  if el.identifier:match("^exr%-") or el.classes:includes("exr") then
    -- Generate hierarchical prefix for exercises
    local prefix = make_numbered_prefix(exr_counts)
    exr_counter = exr_counter + 1

    -- Heading with numbering at the beginning
    local heading = pandoc.Para{
      pandoc.Strong{pandoc.Str(prefix .. " Exercise")}
    }

    -- Insert at top of the content
    table.insert(el.content, 1, heading)
    return el
end
  
  ---------------------------------------------------------
  -- Exam Question (.exam-question)
  ---------------------------------------------------------
  if el.classes:includes("exam-question") then
    local prefix = make_numbered_prefix(question_counts) -- e.g., "1.1.1"
    last_question_prefix = prefix

    -- Extract points for this question
    local points = tonumber(el.attributes["points"]) or 0
    if points > 0 then total_points = total_points + points end

    -- Store information for summary table
    table.insert(question_registry, {
      section = top_section_title, -- only first-level section name
      question = prefix,
      points = points
    })

    -- Extract first paragraph as the question text
    local question_text = ""
    if #el.content > 0 and el.content[1].t == "Para" then
      question_text = pandoc.utils.stringify(el.content[1])
      table.remove(el.content, 1) -- remove first paragraph from content
    end
    
    -- Build heading elements: "1.1.1 Question: What is X?"
    local heading_elems = { 
      pandoc.Strong(prefix .. " Question: "), -- bold prefix + label
      pandoc.Str(question_text)  -- normal font for question text
    }
    
    -- Add points display (bold + underline for PDF, HTML strong for web)
    if points > 0 then
      if quarto.doc.isFormat("pdf") then
        table.insert(heading_elems,
          pandoc.RawInline("latex", string.format(" \\hfill (\\textbf{\\underline{\\hspace{0.7cm}}/%dp})", points))
        )
      else
        table.insert(heading_elems,
          pandoc.RawInline("html", string.format(" <span class='points'><strong>(_____/ %d)</strong></span>", points))
        )
      end
    end

    local heading = pandoc.Para(heading_elems)
    
    -- Combine heading with remaining content
    local content = { heading }
    for _, block in ipairs(el.content) do table.insert(content, block) end
    
    -- Add empty answer lines if solutions are hidden
    if not options_solution then
      local n_lines = tonumber(el.attributes["lines"]) or 6
      for _, b in ipairs(answer_lines(n_lines)) do table.insert(content, b) end
    end

    return pandoc.Div(content, { class = "exam-question-box" })
  end

---------------------------------------------------------
  -- Solution (.unilur-solution)
  ---------------------------------------------------------
  if (el.classes:includes("cell") and el.attributes["unilur-solution"] == "true")
      or el.classes:includes("unilur-solution") then
    el.attributes["unilur-solution"] = nil

    if options_solution then
      if el.attributes["unilur-collapse"] == "false" then options_collapse = false end
      sol_counter = sol_counter + 1
      local prefix = last_question_prefix or make_numbered_prefix(sol_counts)
      local title = prefix .. " Solution"

      if quarto.doc.isFormat("pdf") then
        local latex_content = pandoc.write(pandoc.Pandoc(el.content), "latex")
        return {
          pandoc.RawBlock("latex", "\\begin{callout-solution}[]{\\textbf{" .. title .. "}}"),
          pandoc.RawBlock("latex", latex_content),
          pandoc.RawBlock("latex", "\\end{callout-solution}")
        }
      else
        return {quarto.Callout({
          content = { el },
          icon = false,
          title = pandoc.Para{pandoc.Strong(title)},
          collapse = options_collapse,
          type = "solution"
        })}
      end
    else
      return {}
    end
  end

  ---------------------------------------------------------
  -- Comment (.unilur-comment)
  ---------------------------------------------------------
  if (el.classes:includes("cell") and el.attributes["unilur-comment"] == "true")
      or el.classes:includes("unilur-comment") then
    el.attributes["unilur-comment"] = nil

    if options_solution then
      if el.attributes["unilur-collapse"] == "false" then options_collapse = false end
      comment_counter = comment_counter + 1
      local prefix = last_question_prefix or make_numbered_prefix(comment_counts)
      local title = prefix .. " Comment"

      if quarto.doc.isFormat("pdf") then
        local latex_content = stringify_blocks(el.content)
        return pandoc.RawBlock("latex",
          string.format("\\begin{callout-comment}[]{\\textbf{%s}}\n%s\n\\end{callout-comment}", title, latex_content)
        )
      else
        return {quarto.Callout({
          content = { el },
          icon = false,
          title = pandoc.Para{pandoc.Strong(title)},
          collapse = options_collapse,
          type = "comment"
        })}
      end
    else
      return {}
    end
  end
  ---------------------------------------------------------
  -- Summary (.exam-summary)
  ---------------------------------------------------------
  if el.classes:includes("exam-summary") then
    -- Generate a Markdown table manually (compatible with PDF & HTML)
    local rows = {}
    table.insert(rows, "|**Section** | **Question** | **Points** |")
    table.insert(rows, "|:--|:--:|--:|")

    local subtotal = 0
    for _, q in ipairs(question_registry) do
      table.insert(rows, string.format("| %s | %s | %d |", q.section, q.question, q.points))
      subtotal = subtotal + q.points
    end
    
    -- Add total row
    table.insert(rows, string.format("| **Total** | — | **%d** |", subtotal))
    
    -- Parse Markdown into Pandoc blocks and wrap in a div
    local md_table = table.concat(rows, "\n")
    local blocks = pandoc.read(md_table, "markdown").blocks
    return pandoc.Div(blocks, { class = "exam-summary" })
  end
end

return {
  { Meta = read_meta },
  { Header = Header, Div = Div }
}

