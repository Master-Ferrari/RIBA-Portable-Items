---@diagnostic disable: undefined-global, undefined-field
--[[
    Уровни знаний экипажа. См. Docs/books-and-limits.md

    Уровень категории (0..2) принадлежит КАМПАНИИ, а не персонажу. Поэтому
    подключившийся позже, нанятый бот и вернувшийся со скамейки запаса видят
    одно и то же число, и выдавать им ничего не нужно.

    Вне кампании (обычные раунды, PvP) метаданных нет - там уровень живёт в
    памяти раунда и умирает вместе с ним.
]]

RibaPI.Levels = {}

local MAX_LEVEL = 2
local KEY = "riba.level."

-- запасное хранилище для режимов без кампании
local sessionLevels = {}

local function campaign()
    local ok, c = pcall(function()
        return Game.GameSession ~= nil and Game.GameSession.Campaign or nil
    end)
    if ok and c ~= nil then
        local ok2, meta = pcall(function() return c.CampaignMetadata end)
        if ok2 then return meta end
    end
    return nil
end

--- Текущий уровень категории: 0, 1 или 2.
function RibaPI.Levels.Get(category)
    if category == nil then return 0 end
    local meta = campaign()
    if meta ~= nil then
        local ok, v = pcall(function() return meta.GetInt(KEY .. category, 0) end)
        if ok and v ~= nil then return RibaPI.clamp(v, 0, MAX_LEVEL) end
    end
    return RibaPI.clamp(sessionLevels[category] or 0, 0, MAX_LEVEL)
end

--- Поднимает уровень на единицу. Возвращает новый уровень и признак успеха.
function RibaPI.Levels.Raise(category)
    local current = RibaPI.Levels.Get(category)
    if current >= MAX_LEVEL then return current, false end

    local new = current + 1
    local meta = campaign()
    if meta ~= nil then
        local ok = pcall(function() meta.SetValue(KEY .. category, new) end)
        if not ok then sessionLevels[category] = new end
    else
        sessionLevels[category] = new
    end
    return new, true
end

RibaPI.Levels.Max = MAX_LEVEL

--[[ Множитель лимита: уровень 0 -> x1, 1 -> x2, 2 -> x3.
     Базовое значение берётся из data.json, оно же было значением одной
     старой книги. ]]
function RibaPI.Levels.Cap(group)
    local base = RibaPI.Base(group)
    if base == nil then return nil end
    return base * (1 + RibaPI.Levels.Get(RibaPI.CategoryOf(group)))
end

--[[ Витрина: выдаём персонажу талант ТЕКУЩЕГО уровня, младшие снимаем -
     второй уровень заменяет первый, а не висит рядом с ним. Поэтому таланты
     обоих уровней несут одинаковый список AddedRecipe: снятие младшего не
     должно отбирать рецепты.

     На расчёт лимита таланты не влияют. Если выдача не сработает, лимит всё
     равно верный - он считается по CampaignMetadata.

     Оговорка: снятый талант уходит из Info.UnlockedTalents, то есть из сейва,
     но активный объект таланта живёт в приватном characterTalents и чистится
     только через ResetTalents, который заодно сбрасывает очки. Поэтому иконка
     младшего уровня исчезнет лишь после перезагрузки персонажа. ]]
function RibaPI.Levels.SyncTalents(character)
    if character == nil or character.Info == nil then return end
    for _, category in ipairs(RibaPI.Categories) do
        local level = RibaPI.Levels.Get(category)

        for i = 1, RibaPI.Levels.Max do
            local talent = "RIBA_" .. category .. "_" .. i
            if i == level then
                if not character.HasTalent(talent) then
                    pcall(function() character.GiveTalent(talent, true) end)
                end
            elseif character.HasTalent(talent) then
                pcall(function() character.Info.UnlockedTalents.Remove(talent) end)
            end
        end
    end
end

--[[ Разовая миграция старых сейвов: если кто-то в экипаже успел прочитать
     прежнюю книгу, считаем категорию открытой на первый уровень. ]]
function RibaPI.Levels.MigrateOnce()
    if campaign() == nil then return end
    local meta = campaign()
    local ok, done = pcall(function() return meta.GetBoolean("riba.migrated", false) end)
    if ok and done then return end

    for _, category in ipairs(RibaPI.Categories) do
        if RibaPI.Levels.Get(category) == 0 then
            local legacy = "RIBA_RecipeBook_" .. category
            for _, character in ipairs(Character.CharacterList) do
                if character.Info ~= nil and character.HasTalent(legacy) then
                    RibaPI.Levels.Raise(category)
                    break
                end
            end
        end
    end
    pcall(function() meta.SetValue("riba.migrated", true) end)
end
