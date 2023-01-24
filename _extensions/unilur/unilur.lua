function Div(el)
  print(el.content)
  if el.classes:includes("cell") and el.attributes["unilur-solution"] == "true" then
    print("Solution!")
    el.attributes["unilur=solution"] = nil
    return {quarto.Callout({
      content =  { pandoc.Div(el) },
      caption = "Solution",
      collapse = true,
      type = "note"
      })}
  end
  -- FIXME when solution true and main solution false should discard chunk
end
