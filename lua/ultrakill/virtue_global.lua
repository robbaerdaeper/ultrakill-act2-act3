-- lua/ultrakill/virtue_global.lua
-- Lua аналог EnemyCooldowns.cs для Virtue: shared cooldown + strict round-robin WIND_UP.

if SERVER then AddCSLuaFile() end

if not UK_VIRTUE then include("ultrakill/virtue_constants.lua") end

UK_VirtueGlobal = UK_VirtueGlobal or {
  currentVirtues = {},
  virtueCooldown = 0,
  windingUpRef   = nil,
}

function UK_VirtueGlobal.Register(virtue)
  if not IsValid(virtue) then return end
  for _, e in ipairs(UK_VirtueGlobal.currentVirtues) do
    if e == virtue then return end
  end
  table.insert(UK_VirtueGlobal.currentVirtues, virtue)
end

function UK_VirtueGlobal.Unregister(virtue)
  for i = #UK_VirtueGlobal.currentVirtues, 1, -1 do
    if UK_VirtueGlobal.currentVirtues[i] == virtue or not IsValid(UK_VirtueGlobal.currentVirtues[i]) then
      table.remove(UK_VirtueGlobal.currentVirtues, i)
    end
  end
  if UK_VirtueGlobal.windingUpRef == virtue then
    UK_VirtueGlobal.windingUpRef = nil
  end
end

function UK_VirtueGlobal.CanAttack(virtue)
  return UK_VirtueGlobal.virtueCooldown <= 0
     and (UK_VirtueGlobal.windingUpRef == nil or UK_VirtueGlobal.windingUpRef == virtue)
end

function UK_VirtueGlobal.OnAttackStart(virtue)
  UK_VirtueGlobal.windingUpRef = virtue
  UK_VirtueGlobal.virtueCooldown = UK_VIRTUE.GLOBAL_VIRTUE_CD
end

function UK_VirtueGlobal.OnWindupComplete(virtue)
  if UK_VirtueGlobal.windingUpRef == virtue then
    UK_VirtueGlobal.windingUpRef = nil
  end
end

function UK_VirtueGlobal.Count()
  local n = 0
  for i = #UK_VirtueGlobal.currentVirtues, 1, -1 do
    if IsValid(UK_VirtueGlobal.currentVirtues[i]) then
      n = n + 1
    else
      table.remove(UK_VirtueGlobal.currentVirtues, i)
    end
  end
  return n
end

function UK_VirtueGlobal.Tick()
  if UK_VirtueGlobal.virtueCooldown > 0 then
    UK_VirtueGlobal.virtueCooldown = math.max(0, UK_VirtueGlobal.virtueCooldown - FrameTime())
  end
  if UK_VirtueGlobal.windingUpRef and not IsValid(UK_VirtueGlobal.windingUpRef) then
    UK_VirtueGlobal.windingUpRef = nil
  end
end

hook.Add("Tick", "UK_VirtueGlobal_Tick", UK_VirtueGlobal.Tick)
