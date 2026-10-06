setDefaultTab("Tools")

-- Ingame script editor (multiline) com:
--  - normalização de quebras de linha (CRLF/CR -> LF) para caret estável
--  - auto-scroll do cursor (quando pressiona ENTER na última linha, a view acompanha)
--  - foco automático no editor ao abrir
--  - execução segura do código salvo (Lua 5.1 e 5.2+)

UI.Button("Ingame script editor", function()
  local initial = storage.ingame_hotkeys or ""
  -- Normaliza quebras de linha para evitar bug do caret
  initial = initial:gsub("\r\n", "\n"):gsub("\r", "\n")

  local win = UI.MultilineEditorWindow(
    initial,
    {
      title = "Ingame script editor",
      description = "You can add your custom scripts here.\nPress Save to apply.",
      width = 600,
      height = 420
    },
    function(text)
      -- Salva normalizado para manter estabilidade nas próximas aberturas
      storage.ingame_hotkeys = (text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
      reload()
    end
  )

  -- === Auto-scroll do cursor / foco automático ===
  local edit = nil
  if win then
    edit = win.text or win:getChildById('text') or win:getChildById('textEdit') or win:getChildById('editor')
  end

  local function scrollToBottom()
    if not edit then return end
    -- Abordagem 1: via ScrollBar vertical (preferível)
    local sb = edit.verticalScrollBar or (edit.getVerticalScrollBar and edit:getVerticalScrollBar()) or nil
    if sb and sb.setValue and sb.getMaximum then
      sb:setValue(sb:getMaximum())
      return
    end
    -- Abordagem 2 (fallback): garantir visibilidade do retângulo do cursor
    if edit.ensureVisible and edit.getCursorRect then
      local r = edit:getCursorRect()
      if r then edit:ensureVisible(r) end
    end
  end

  if edit then
    -- Quando o texto muda (ENTER/cola/etc.), rolar até o fim
    local prevOnChange = edit.onTextChange
    edit.onTextChange = function(widget, ...)
      if prevOnChange then prevOnChange(widget, ...) end
      scrollToBottom()
    end

    -- Se o build expõe evento de mudança de posição do cursor, usar também
    if edit.onCursorPositionChange ~= nil then
      local prevOnCursor = edit.onCursorPositionChange
      edit.onCursorPositionChange = function(widget, ...)
        if prevOnCursor then prevOnCursor(widget, ...) end
        scrollToBottom()
      end
    end

    -- Dar foco e rolar ao abrir
    schedule(10, function()
      if edit.focus then edit:focus() end
      scrollToBottom()
    end)
  end
end)

UI.Separator()

-- Executa o conteúdo salvo (se houver)
do
  local scripts = storage.ingame_hotkeys
  if type(scripts) == "string" and #scripts > 3 then
    local ok, err = pcall(function()
      if _VERSION == "Lua 5.1" and type(jit) ~= "table" then
        local chunk, lerr = loadstring(scripts)
        assert(chunk, lerr)
        return chunk()
      else
        local chunk, lerr = load(scripts, "ingame_editor")
        assert(chunk, lerr)
        return chunk()
      end
    end)
    if not ok then
      error("Ingame editor error:\n" .. tostring(err))
    end
  end
end

UI.Separator()
