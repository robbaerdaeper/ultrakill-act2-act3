-- Distortion was removed — Refract on a tiny target rect read as visual noise,
-- not the menacing warp the wiki describes. Keep API stub so any caller (spawn FX,
-- third-party) is a no-op instead of a crash.

if not UKPuppet then return end
if SERVER then return end

UKPuppet.AddDistort = UKPuppet.AddDistort or function() end
