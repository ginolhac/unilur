local function AddCallout(el)

    local solutionEl = quarto.Callout({
      content =  { pandoc.Div(el) },
      caption = "Solution",
      collapse = true,
      type = "note"
      })
    return solutionEl
end

local function scan_divs(Div)
    print("class", Div.classes[1])
    print("attr", Div.attributes["unilur-solution"])
    if Div.classes[1] == "cell" and Div.attributes["unilur-solution"] == "true" then
        print("Solution!")
        -- Div.attributes["solution"] = nil
        newDiv = AddCallout(Div)
    else
        NewDiv = Div
    end
  return NewDiv
end

return {Div = scan_divs}