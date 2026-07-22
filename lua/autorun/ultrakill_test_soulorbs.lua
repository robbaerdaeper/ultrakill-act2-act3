-- ULTRAKILL Soul Orbs: dual wield power-up core + Sharpshooter helicopter.
--
-- Canon source: decompiled DualWield / DualWieldPickup / PowerUpMeter / Bonus /
-- NewMovement.SuperCharge (Assembly-CSharp, game build 2026-07).
--   * juice = 30s, drains 1/s; new pickup refreshes timer only if its duration
--     exceeds the remaining juice (PowerUpMeter.latestMaxJuice pattern)
--   * each pickup = +1 weapon copy, no stack limit
--   * copies fire as delayed echoes of the real gun. Canon delay is
--     0.05 + n/20 s per copy; we default to 0.5 s (convar).
--   * powerUpColor = (1, 0.6, 0); vignette alpha = juice/latestMaxJuice
--
-- ukweapons (Workshop 3733242369) support: the dredux base fires through
-- BulletAttack/ProjectileAttack*/EmitSound — those get recorder shims, and
-- every weapon_dredux_uk_* Primary/SecondaryAttack gets a capture wrapper that
-- replays the recorded volley per stack. Railcannon electric/malicious deal
-- inline damage, so they re-run the whole PrimaryAttack instead; the marksman
-- coin toss is replicated coin-by-coin (echo coins still consume the pool).
--
-- Helicopter: >= 4 stacks + Sharpshooter twirling (RMB held) = lift. More
-- stacks, more lift. Needs at least 1 token to start the twirl (canon spin).
--
-- Non-pack weapons: hitscan echoes via EntityFireBullets, melee stacks damage
-- via EntityTakeDamage, projectiles (HL2 crossbow/RPG/frag/SMG grenade/AR2
-- orb/SLAM/bugbait + custom SWEPs by class heuristic) clone via
-- OnEntityCreated, gravity gun punt scales with stacks.

UKSoulOrbs = UKSoulOrbs or {}

local CVAR_DURATION = CreateConVar("ultrakill_dualwield_duration", "30",
    bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED),
    "Dual wield juice per gold orb, seconds (canon 30)")
local CVAR_DELAY = CreateConVar("ultrakill_dualwield_delay", "0",
    bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED),
    "Delay between echo shots of each dual wield copy (0 = instant, canon 0.05)")
local CVAR_HELI = CreateConVar("ultrakill_sharpshooter_helicopter", "1",
    bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED),
    "4+ dual wield stacks + Sharpshooter RMB twirl = helicopter")
local CVAR_VISUAL = CreateConVar("ultrakill_dualwield_maxcopies_visual", "8",
    bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED),
    "Max dual wield viewmodel copies drawn (mechanics are uncapped)")
local CVAR_INFINITE = CreateConVar("ultrakill_powerups_infinite", "0",
    bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED),
    "Power-ups never expire (dual wield juice stays full until death)")

local SND_DIR = "ultrakill_prelude_test/soulorb/"

function UKSoulOrbs.GetStacks(ply)
    return ply:GetNW2Int("UKDW_Stacks", 0)
end

function UKSoulOrbs.GetEndTime(ply)
    return ply:GetNW2Float("UKDW_End", 0)
end

function UKSoulOrbs.GetMaxJuice(ply)
    return ply:GetNW2Float("UKDW_Max", 30)
end

local SHARP_CLASSES = {
    ["weapon_dredux_uk_sharpshooter"] = true,
    ["weapon_dredux_uk_sharpshooter_alt"] = true,
}

----------------------------------------------------------------------------------------------------
-- Server: stack bookkeeping
----------------------------------------------------------------------------------------------------

if SERVER then

    util.AddNetworkString("UKSoulOrbs_Flash")

    function UKSoulOrbs.AddDualWield(ply, juice)
        juice = juice or CVAR_DURATION:GetFloat()
        ply:SetNW2Int("UKDW_Stacks", UKSoulOrbs.GetStacks(ply) + 1)
        -- canon: if (meter.juice < juiceAmount) { latestMaxJuice = juice = juiceAmount }
        local remaining = UKSoulOrbs.GetEndTime(ply) - CurTime()
        if juice > remaining then
            ply:SetNW2Float("UKDW_End", CurTime() + juice)
            ply:SetNW2Float("UKDW_Max", juice)
        end
    end

    function UKSoulOrbs.ClearDualWield(ply, silent)
        if UKSoulOrbs.GetStacks(ply) <= 0 then return end
        ply:SetNW2Int("UKDW_Stacks", 0)
        ply:SetNW2Float("UKDW_End", 0)
        if not silent and ply:Alive() then
            -- canon PowerUpMeter.endEffect = prefab "PowerUpEnd", its
            -- AudioSource plays the AudioClip "EnrageEnd" (traced through the
            -- prefab PPtr chain, round 2 2026-07-10) — Kevin's base already
            -- ships that exact game file
            ply:EmitSound("ultrakill/sound/EnrageEnd.wav", 75, 100, 0.8)
        end
    end

    -- canon TimeController.ParryFlash on orb pickup: white blink for the picker
    function UKSoulOrbs.PickupFlash(ply)
        net.Start("UKSoulOrbs_Flash")
        net.Send(ply)
        if ULTRAWep_Base and isfunction(ULTRAWep_Base.HitStopSimple) then
            ULTRAWep_Base.HitStopSimple(0.05)
        end
    end

    hook.Add("Think", "UKSoulOrbs_JuiceDrain", function()
        local infinite = CVAR_INFINITE:GetBool()
        for _, ply in player.Iterator() do
            if UKSoulOrbs.GetStacks(ply) > 0 then
                if infinite then
                    -- round-4 2026-07-10: pin the timer EVERY tick — the old
                    -- sag-to-half-then-refill read as a busted timer on the
                    -- HUD; now the bar just stands still at full
                    local maxj = UKSoulOrbs.GetMaxJuice(ply)
                    ply:SetNW2Float("UKDW_End", CurTime() + maxj)
                elseif CurTime() >= UKSoulOrbs.GetEndTime(ply) then
                    UKSoulOrbs.ClearDualWield(ply)
                end
            end
        end
    end)

    hook.Add("PlayerDeath", "UKSoulOrbs_DeathReset", function(ply)
        UKSoulOrbs.ClearDualWield(ply, true)
    end)

    hook.Add("PlayerSpawn", "UKSoulOrbs_SpawnReset", function(ply)
        UKSoulOrbs.ClearDualWield(ply, true)
    end)

end

----------------------------------------------------------------------------------------------------
-- Dual wield echoes for the ULTRAKILL Weapons Pack (dredux base)
----------------------------------------------------------------------------------------------------

local entMeta = FindMetaTable("Entity")

-- weapons that deal inline damage in PrimaryAttack (no Bullet/Proj call to
-- record) — echo re-runs the whole PrimaryAttack with the cooldown gate lifted
local FULL_REPLAY = {
    ["weapon_dredux_uk_railcannon_electric"] = true,
    ["weapon_dredux_uk_railcannon_malicious"] = true,
}

-- coin throwers: SecondaryAttack spawns ultrakill_coin directly
local COIN_CLASSES = {
    ["weapon_dredux_uk_marksman"] = true,
    ["weapon_dredux_uk_marksman_alt"] = true,
}

local function RecordEntry(wep, kind, fn, ...)
    local rec = wep.UKDW_Recording
    if not rec then return end
    rec[#rec + 1] = { kind = kind, fn = fn, args = { n = select("#", ...), ... } }
end

-- one echo copy firing: replay the recorded volley on the real weapon
local function ReplayRecording(wep, rec, chargeSnap)
    local restoreCharge = chargeSnap and chargeSnap > 0
        and isfunction(wep.SetCharge) and isfunction(wep.GetCharge)
    if restoreCharge then wep:SetCharge(chargeSnap) end
    wep.UKDW_Echoing = true
    for _, e in ipairs(rec) do
        local a = e.args
        -- fire sounds land on CHAN_WEAPON, where the NEXT real shot would
        -- replace them (echo delay ~ fire rate) — bounce echoes to STATIC
        if e.kind == "sound" and a[5] == CHAN_WEAPON then
            a = { n = a.n, unpack(a, 1, a.n) }
            a[5] = CHAN_STATIC
        end
        local ok, err = pcall(e.fn, wep, unpack(a, 1, a.n))
        if not ok then ErrorNoHalt("[UKSoulOrbs] echo replay: " .. tostring(err) .. "\n") end
    end
    wep.UKDW_Echoing = false
    if restoreCharge then wep:SetCharge(0) end
end

local function ScheduleEchoes(wep, owner, fire)
    -- canon floor 0.05s/copy: at a literal 0 echo volleys land the same frame
    -- and perfectly overlap the real shot (looks like nothing happened)
    local delay = math.max(CVAR_DELAY:GetFloat(), 0.05)
    local stacks = UKSoulOrbs.GetStacks(owner)
    for k = 1, stacks do
        timer.Simple(delay * k, function()
            if not (IsValid(wep) and IsValid(owner) and owner:Alive()) then return end
            if wep:GetOwner() ~= owner then return end
            if owner:GetActiveWeapon() ~= wep then return end
            -- copy #k exists only while the stack count still covers it
            if UKSoulOrbs.GetStacks(owner) < k then return end
            fire(k)
        end)
    end
end

local function WrapAttack(stored, class, method)
    local orig = rawget(stored, method)
    if not isfunction(orig) then return end

    stored[method] = function(self, ...)
        if self.UKDW_Echoing then return orig(self, ...) end
        -- nested call (e.g. PrimaryAttack -> LaunchCannonball): the outer
        -- window is already recording — pass through, don't reset it
        if self.UKDW_Recording then return orig(self, ...) end

        local owner = self:GetOwner()
        if not (IsValid(owner) and owner:IsPlayer()) or UKSoulOrbs.GetStacks(owner) <= 0 then
            return orig(self, ...)
        end

        -- melee (impact hammer punch, called from OnThink): copies strike
        -- INSTANTLY — no timer, no recording, just re-run the punch per stack
        if method == "ImpactPunch" then
            -- sentinel: if an older wrapper build is stacked under us (live
            -- re-wrap), the recording flag makes it pass straight through
            self.UKDW_Recording = {}
            local ret = orig(self, ...)
            self.UKDW_Recording = nil
            if SERVER then
                for k = 1, UKSoulOrbs.GetStacks(owner) do
                    self.UKDW_Echoing = true
                    local ok, err = pcall(orig, self)
                    self.UKDW_Echoing = false
                    if not ok then ErrorNoHalt("[UKSoulOrbs] punch echo: " .. tostring(err) .. "\n") end
                end
            end
            return ret
        end

        -- coin toss: detect an actual throw via ply.LastCoin, then echo coins
        if COIN_CLASSES[class] and method == "SecondaryAttack" then
            local before = SERVER and owner.LastCoin or nil
            self.UKDW_Recording = {} -- old-wrapper passthrough sentinel
            local ret = orig(self, ...)
            self.UKDW_Recording = nil
            if SERVER and owner.LastCoin ~= before then
                ScheduleEchoes(self, owner, function()
                    UKSoulOrbs.EchoCoinToss(owner)
                end)
            end
            return ret
        end

        -- inline-damage weapons: re-run PrimaryAttack per copy
        if FULL_REPLAY[class] and method == "PrimaryAttack" then
            local couldFire = owner:GetNW2Float("UK_Railcannon_Cooldown") == 0
            self.UKDW_Recording = {} -- old-wrapper passthrough sentinel
            local ret = orig(self, ...)
            self.UKDW_Recording = nil
            if SERVER and couldFire then
                ScheduleEchoes(self, owner, function()
                    owner:SetNW2Float("UK_Railcannon_Cooldown", 0)
                    self.UKDW_Echoing = true
                    local ok, err = pcall(orig, self)
                    self.UKDW_Echoing = false
                    if not ok then ErrorNoHalt("[UKSoulOrbs] railcannon echo: " .. tostring(err) .. "\n") end
                end)
            end
            return ret
        end

        -- generic path: record BulletAttack/ProjectileAttack*/EmitSound calls,
        -- then replay the volley per copy. Charge is snapshotted so an echoed
        -- Sharpshooter charged shot keeps its ricochets.
        local chargeSnap = isfunction(self.GetCharge) and self:GetCharge() or nil
        self.UKDW_Recording = {}
        local ret = orig(self, ...)
        local rec = self.UKDW_Recording
        self.UKDW_Recording = nil

        if SERVER and rec then
            local hasShot = false
            for _, e in ipairs(rec) do
                if e.kind == "shot" then hasShot = true break end
            end
            -- mode toggles / zooms record no ordnance — no echo
            if hasShot then
                ScheduleEchoes(self, owner, function()
                    ReplayRecording(self, rec, chargeSnap)
                end)
            end
        end
        return ret
    end
end

-- echo coin toss: canon copy throws its own coin (still consumes the pool);
-- mirrors weapon_dredux_uk_marksman SecondaryAttack minus the manual-cadence
-- LastCoin gate
function UKSoulOrbs.EchoCoinToss(ply)
    if CLIENT then return end
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or not COIN_CLASSES[wep:GetClass()] then return end
    -- echo coin is FREE: two coins thrown, one charged from the pool

    local pos = (ply:WorldSpaceCenter() + ply:EyePos()) / 2
    local coin = ents.Create("ultrakill_coin")
    if not IsValid(coin) then return end
    coin:SetPos(pos + ply:GetAimVector() * 10)
    coin:SetAngles(Angle(90, 0, 0) + (pos - coin:GetPos()):Angle())
    coin:Spawn()

    local phys = coin:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetVelocity(ply:GetVelocity() + Vector(0, 0, 250) + ply:GetAimVector() * 300)
    end

    net.Start("ULTRAKILL_TossCoin")
    net.Send(ply)

    coin:EmitSound("ultrakill/coinflip.ogg", 75, math.random(90, 105))
end

local function InstallWraps()
    local base = weapons.GetStored("weapon_dredux_base2_uk")
    if not base then return end

    if not base.UKDW_Wrapped then
        base.UKDW_Wrapped = true

        -- recorder shims on the shared base
        for _, name in ipairs({ "BulletAttack", "ProjectileAttack", "ProjectileAttack_Grav" }) do
            local orig = base[name]
            if isfunction(orig) then
                base[name] = function(self, ...)
                    RecordEntry(self, "shot", orig, ...)
                    return orig(self, ...)
                end
            end
        end

        -- pellet family (shotguns/nailguns): the CALLER pre-rolls math.Rand
        -- spread and passes it as an argument, so a verbatim replay repeats
        -- the exact pellet pattern of the real shot on every echo. Re-roll
        -- the direction per replay (keep the magnitude — it encodes the
        -- weapon's spread scale) and re-anchor the spawn point to the
        -- shooter's CURRENT muzzle so echoes track the aim.
        local origShotgun = base.ShotGun_ProjectileAttack
        if isfunction(origShotgun) then
            local function EchoPelletShot(self, proj, att, vel, spread)
                if isvector(spread) and spread:LengthSqr() > 0 then
                    local u = VectorRand()
                    u:Normalize()
                    local owner = self:GetOwner()
                    if IsValid(owner) then
                        att = owner:GetShootPos() + owner:GetAimVector() + u
                    end
                    spread = u * spread:Length()
                end
                return origShotgun(self, proj, att, vel, spread)
            end
            base.ShotGun_ProjectileAttack = function(self, proj, att, vel, spread)
                RecordEntry(self, "shot", EchoPelletShot, proj, att, vel, spread)
                return origShotgun(self, proj, att, vel, spread)
            end
        end

        -- EmitSound shim: shadows the C method for dredux weapons only, so echo
        -- copies replay the fire sounds captured during the original volley
        base.EmitSound = function(self, ...)
            RecordEntry(self, "sound", entMeta.EmitSound, ...)
            return entMeta.EmitSound(self, ...)
        end

        -- some fire sounds go through the base's delayed helper
        local origWDelay = base.EmitSoundWDelay
        if isfunction(origWDelay) then
            base.EmitSoundWDelay = function(self, ...)
                RecordEntry(self, "sound", origWDelay, ...)
                return origWDelay(self, ...)
            end
        end

        -- impact hammer punch lives on the base (impact_core/sawedon call it
        -- from OnThink) — wrap it as an instant-echo entry point
        WrapAttack(base, "weapon_dredux_base2_uk", "ImpactPunch")
    end

    -- per-class wraps re-checked every pass: a lua autorefresh of any single
    -- weapon file re-registers its stored table and drops our wrapper.
    -- The wrappers capture ScheduleEchoes & co. as upvalues at install time —
    -- bump UKDW_WRAP_VERSION whenever their behavior changes, or a running
    -- session keeps executing the OLD closures until a full game restart.
    -- (Re-wrapping stacks the new wrapper over the old one; the recording
    -- sentinel in each branch makes the stale inner wrapper pass through.)
    local UKDW_WRAP_VERSION = 2
    for _, tbl in ipairs(weapons.GetList()) do
        local class = tbl.ClassName or ""
        if class:find("^weapon_dredux_uk_") then
            local stored = weapons.GetStored(class)
            if stored and stored.UKDW_ClassWrapped ~= UKDW_WRAP_VERSION then
                stored.UKDW_ClassWrapped = UKDW_WRAP_VERSION
                WrapAttack(stored, class, "PrimaryAttack")
                WrapAttack(stored, class, "SecondaryAttack")
                -- charge-and-release launches fired from OnThink (RMB release)
                WrapAttack(stored, class, "LaunchCore")       -- shotgun core
                WrapAttack(stored, class, "LaunchChainsaw")   -- sawed-on variants
                WrapAttack(stored, class, "LaunchCannonball") -- S.R.S. cannon
                WrapAttack(stored, class, "LaunchGasoline")   -- firestarter
                -- impact_pump overrides the base punch with its own
                WrapAttack(stored, class, "ImpactPunch")
            end
        end
    end
    return true
end

hook.Add("InitPostEntity", "UKSoulOrbs_WrapWeapons", InstallWraps)
-- lua autorefresh mid-session: weapons are already registered
if weapons.GetStored("weapon_dredux_base2_uk") then InstallWraps() end
-- pack autorefresh re-registers its SWEP tables and wipes the shims — re-check
timer.Create("UKSoulOrbs_RewrapWatch", 5, 0, InstallWraps)

----------------------------------------------------------------------------------------------------
-- Generic dual wield support for non-pack hitscan weapons (HL2 etc.):
-- duplicate the FireBullets volley. No sound available generically.
----------------------------------------------------------------------------------------------------

hook.Add("EntityFireBullets", "UKSoulOrbs_GenericEcho", function(ent, data)
    if CLIENT then return end
    if not (IsValid(ent) and ent:IsPlayer()) then return end
    if ent.UKDW_GenericEcho then return end
    if UKSoulOrbs.GetStacks(ent) <= 0 then return end
    local wep = ent:GetActiveWeapon()
    -- dredux weapons echo through the recorder path
    if not IsValid(wep) or wep.IsUltrakillWeapon then return end

    local copy = {
        Num = data.Num, Spread = data.Spread, Damage = data.Damage,
        Force = data.Force, AmmoType = data.AmmoType, HullSize = data.HullSize,
        Tracer = data.Tracer, TracerName = data.TracerName,
    }
    local class = wep:GetClass()
    ScheduleEchoes(wep, ent, function()
        local cur = ent:GetActiveWeapon()
        if not IsValid(cur) or cur:GetClass() ~= class then return end
        copy.Src = ent:GetShootPos()
        copy.Dir = ent:GetAimVector()
        ent.UKDW_GenericEcho = true
        ent:FireBullets(copy)
        ent.UKDW_GenericEcho = false
    end)
end)

----------------------------------------------------------------------------------------------------
-- Generic dual wield for non-pack MELEE (crowbar, stunstick, fists...):
-- HL2 melee traces in C++ (no FireBullets), so echoes can't re-swing it —
-- instead each copy lands the SAME hit as its own separate damage event.
----------------------------------------------------------------------------------------------------

local MELEE_DMG = bit.bor(DMG_CLUB, DMG_SLASH)

hook.Add("EntityTakeDamage", "UKSoulOrbs_GenericMeleeStack", function(target, dmg)
    local attacker = dmg:GetAttacker()
    if not (IsValid(attacker) and attacker:IsPlayer()) then return end
    if attacker.UKDW_MeleeEchoing then return end
    local stacks = UKSoulOrbs.GetStacks(attacker)
    if stacks <= 0 then return end
    local isMelee = bit.band(dmg:GetDamageType(), MELEE_DMG) ~= 0
    if not isMelee then
        -- GMod fists punch with plain DMG_GENERIC — recognize it by inflictor
        local infl = dmg:GetInflictor()
        isMelee = IsValid(infl) and infl:GetClass() == "weapon_fists"
    end
    if not isMelee then return end
    local wep = attacker:GetActiveWeapon()
    -- dredux (impact hammer punch etc.) already echoes through its own path
    if not IsValid(wep) or wep.IsUltrakillWeapon then return end

    -- snapshot the hit; re-applying damage inside the damage hook is unsafe,
    -- so the echo strikes land one tick later
    local info = {
        damage = dmg:GetDamage(),
        dtype = dmg:GetDamageType(),
        force = dmg:GetDamageForce(),
        pos = dmg:GetDamagePosition(),
        infl = dmg:GetInflictor(),
    }
    timer.Simple(0, function()
        if not (IsValid(target) and IsValid(attacker)) then return end
        attacker.UKDW_MeleeEchoing = true
        for k = 1, UKSoulOrbs.GetStacks(attacker) do
            local d = DamageInfo()
            d:SetDamage(info.damage)
            d:SetDamageType(info.dtype)
            d:SetAttacker(attacker)
            d:SetInflictor(IsValid(info.infl) and info.infl or attacker)
            d:SetDamageForce(info.force)
            d:SetDamagePosition(info.pos)
            target:TakeDamageInfo(d)
        end
        attacker.UKDW_MeleeEchoing = false
    end)
end)

----------------------------------------------------------------------------------------------------
-- Generic dual wield for non-pack PROJECTILE weapons: HL2 crossbow / RPG /
-- frag grenades / SMG grenades / AR2 orbs / SLAM mines+satchels / bugbait
-- pheropods / flechettes, plus custom SWEPs recognized by projectile-like
-- class names. Each copy clones the spawned projectile with the same
-- velocity, fanned out sideways so instant echoes don't nest inside each
-- other.
----------------------------------------------------------------------------------------------------

if SERVER then

    -- per-class fixups for engine projectiles whose damage/fuse is set by the
    -- C++ weapon code rather than in the entity's own Spawn
    local PROJ_FIXUP = {
        ["crossbow_bolt"] = function(c)
            local cv = GetConVar("sk_plr_dmg_crossbow")
            c:SetSaveValue("m_flDamage", cv and cv:GetFloat() or 100)
        end,
        ["rpg_missile"] = function(c)
            local cv = GetConVar("sk_plr_dmg_rpg_round")
            if cv then c:SetSaveValue("m_flDamage", cv:GetFloat()) end
        end,
        ["npc_grenade_frag"] = function(c, src)
            -- keep the original fuse; a bogus/unset detonate time otherwise
            -- makes echoes blow almost instantly and chain the real grenade
            local fuse = 3
            if src.detonate and src.detonate > CurTime() + 0.3 then
                fuse = src.detonate - CurTime()
            end
            c:Fire("SetTimer", string.format("%.2f", fuse))
        end,
        ["grenade_ar2"] = true,          -- SMG1 alt grenade
        ["npc_grenade_bugbait"] = true,  -- pheropod throw
        ["hunter_flechette"] = true,
        ["npc_satchel"] = function(c, src)
            -- weapon_slam remote-detonates satchels whose thrower == its owner
            c:SetSaveValue("m_hThrower", src.owner)
        end,
        ["npc_tripmine"] = true,
        ["prop_combine_ball"] = true,    -- special-cased: launcher, see below
    }

    -- custom SWEP projectiles: recognized by class name
    local PROJ_PATTERNS = { "grenade", "rocket", "missile", "bolt", "projectile", "flechette" }

    local function IsCloneableClass(class)
        if PROJ_FIXUP[class] ~= nil then return true end
        for _, p in ipairs(PROJ_PATTERNS) do
            if class:find(p, 1, true) then return true end
        end
        return false
    end

    local function IsExcludedClass(class)
        -- the pack + our own entities echo through their own paths
        return class:find("ultrakill", 1, true) ~= nil
            or class:find("dredux", 1, true) ~= nil
            or class:find("^ent_uk_") ~= nil
            or class:find("^uk_") ~= nil
    end

    local function ProjOwner(ent)
        local o = ent:GetOwner()
        if IsValid(o) and o:IsPlayer() then return o end
        for _, field in ipairs({ "m_hThrower", "m_hOwner" }) do
            local t = ent:GetInternalVariable(field)
            if IsValid(t) and t:IsPlayer() then return t end
        end
        local pa = ent.GetPhysicsAttacker and ent:GetPhysicsAttacker(1) or nil
        if IsValid(pa) and pa:IsPlayer() then return pa end
    end

    -- AR2 orbs can't be ents.Create'd — launch a fresh one through a
    -- point_combine_ball_launcher, then tag it as weapon-launched so it
    -- dissipates and disintegrates NPCs like the real alt-fire ball
    local function CloneCombineBall(src, offset)
        local launcher = ents.Create("point_combine_ball_launcher")
        if not IsValid(launcher) then return end
        local speed = math.max(src.vel:Length(), 1)
        launcher:SetPos(src.pos + offset)
        launcher:SetAngles(src.vel:GetNormalized():Angle())
        launcher:SetKeyValue("ballcount", "1")
        launcher:SetKeyValue("minspeed", tostring(speed))
        launcher:SetKeyValue("maxspeed", tostring(speed))
        launcher:SetKeyValue("ballradius", "12")
        launcher:SetKeyValue("launchconenoise", "0")
        launcher:Spawn()
        launcher:Activate()
        launcher:Fire("LaunchBall")
        -- entity I/O lands next tick — pick the launched ball up after it
        timer.Simple(0.05, function()
            if not IsValid(launcher) then return end
            for _, b in ipairs(ents.FindInSphere(launcher:GetPos(), 160)) do
                if b:GetClass() == "prop_combine_ball" and not b.UKDW_Clone then
                    b.UKDW_Clone = true
                    b.UKDW_Owner = src.owner
                    b:SetSaveValue("m_bWeaponLaunched", true)
                    if IsValid(src.owner) then b:SetPhysicsAttacker(src.owner) end
                    timer.Simple(4, function() -- canon AR2 orb lifetime
                        if IsValid(b) then b:Fire("Explode") end
                    end)
                end
            end
            launcher:Remove()
        end)
    end

    local function SpawnProjClone(src, k)
        local ply = src.owner
        if not (IsValid(ply) and ply:Alive()) then return end
        if UKSoulOrbs.GetStacks(ply) < k then return end

        local right
        if src.vel:LengthSqr() > 100 then
            right = src.vel:GetNormalized():Cross(vector_up)
            if right:LengthSqr() < 0.01 then right = src.ang:Right() end
        else
            right = src.ang:Right()
        end
        right:Normalize()
        local ring = math.ceil(k / 2)
        local side = (k % 2 == 1) and 1 or -1
        local offset = right * (side * ring * 12)

        if src.class == "prop_combine_ball" then
            return CloneCombineBall(src, offset)
        end

        local c = ents.Create(src.class)
        if not IsValid(c) then return end
        c.UKDW_Clone = true
        c.UKDW_Owner = ply
        c:SetPos(src.pos + offset)
        c:SetAngles(src.ang)
        c:SetOwner(ply)
        c:Spawn()
        c:Activate()

        local fix = PROJ_FIXUP[src.class]
        if isfunction(fix) then
            local ok, err = pcall(fix, c, src)
            if not ok then ErrorNoHalt("[UKSoulOrbs] proj fixup: " .. tostring(err) .. "\n") end
        end

        local phys = c:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
            phys:SetVelocity(src.vel)
            if src.angvel then phys:SetAngleVelocity(src.angvel) end
        else
            -- MOVETYPE_FLY bolts/missiles: no vphys and no Lua abs-velocity
            -- setter — write the save fields the movement code reads, else the
            -- clone hangs in the air with zero speed and slowly sinks
            c:SetSaveValue("m_vecAbsVelocity", src.vel)
            c:SetSaveValue("m_vecVelocity", src.vel)
        end
    end

    hook.Add("OnEntityCreated", "UKSoulOrbs_ProjEcho", function(ent)
        -- defer one tick: owner/thrower/velocity are set right after creation
        timer.Simple(0, function()
            if not IsValid(ent) or ent.UKDW_Clone then return end
            local class = ent:GetClass()
            if IsExcludedClass(class) or not IsCloneableClass(class) then return end

            local ply = ProjOwner(ent)
            if not ply then return end
            local stacks = UKSoulOrbs.GetStacks(ply)
            if stacks <= 0 then return end
            local wep = ply:GetActiveWeapon()
            if IsValid(wep) and wep.IsUltrakillWeapon then return end -- pack echoes itself

            local phys = ent:GetPhysicsObject()
            local src = {
                class = class,
                owner = ply,
                pos = ent:GetPos(),
                ang = ent:GetAngles(),
                vel = IsValid(phys) and phys:GetVelocity() or ent:GetVelocity(),
                angvel = IsValid(phys) and phys:GetAngleVelocity() or nil,
                detonate = ent:GetInternalVariable("m_flDetonateTime"),
            }

            -- same canon 0.05s/copy floor as ScheduleEchoes
            local delay = math.max(CVAR_DELAY:GetFloat(), 0.05)
            for k = 1, stacks do
                timer.Simple(delay * k, function() SpawnProjClone(src, k) end)
            end
        end)
    end)

    -- echo projectiles never hurt their own shooter: instant clones spawn
    -- right beside him (an AR2 orb ricochet was a guaranteed self-kill)
    hook.Add("EntityTakeDamage", "UKSoulOrbs_CloneNoSelfDamage", function(target, dmg)
        local infl = dmg:GetInflictor()
        if IsValid(infl) and infl.UKDW_Clone and target == infl.UKDW_Owner then
            return true
        end
    end)

    ------------------------------------------------------------------------------------------------
    -- Gravity gun: every dual wield copy adds punt power (+50% per stack)
    ------------------------------------------------------------------------------------------------

    hook.Add("GravGunPunt", "UKSoulOrbs_GravgunPunt", function(ply, ent)
        local stacks = UKSoulOrbs.GetStacks(ply)
        if stacks <= 0 then return end
        -- the engine applies its punt impulse after this hook — scale it next tick
        timer.Simple(0, function()
            if not (IsValid(ent) and IsValid(ply)) then return end
            local phys = ent:GetPhysicsObject()
            if not IsValid(phys) then return end
            phys:SetVelocity(phys:GetVelocity() * (1 + 0.5 * stacks))
        end)
    end)

end

----------------------------------------------------------------------------------------------------
-- Sharpshooter helicopter: 4+ stacks, RMB twirl held -> rotor lift.
-- Runs in SetupMove (predicted) so flight is smooth for the pilot.
----------------------------------------------------------------------------------------------------

local CVAR_GRAVITY = GetConVar("sv_gravity")

hook.Add("SetupMove", "UKSoulOrbs_Helicopter", function(ply, mv, cmd)
    if not CVAR_HELI:GetBool() then return end
    if not ply:Alive() then return end
    local stacks = UKSoulOrbs.GetStacks(ply)
    if stacks < 1 then return end
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or not SHARP_CLASSES[wep:GetClass()] then return end
    if not mv:KeyDown(IN_ATTACK2) then return end
    -- rotor = the canon revolver twirl; needs a token to start (weapon rule)
    if not wep.StartSpin then return end

    local dt = engine.TickInterval()
    local vel = mv:GetVelocity()

    -- 1..3 стака: стволов ещё мало для взлёта, но висишь дольше —
    -- часть гравитации гасится и падение упирается в мягкий потолок
    if stacks < 4 then
        local grav = CVAR_GRAVITY and CVAR_GRAVITY:GetFloat() or 600
        local cancel = 0.3 * stacks           -- 30% / 60% / 90% гравитации
        local maxFall = -(430 - stacks * 115) -- -315 / -200 / -85
        vel.z = vel.z + grav * cancel * dt
        if vel.z < maxFall then
            vel.z = math.min(vel.z + grav * 2 * dt, maxFall)
        end
        mv:SetVelocity(vel)
        ply.UKDW_HeliGrace = CurTime() + 1.5
        return
    end

    local power = stacks - 3 -- 4 стака = 1, дальше растёт без предела

    local lift = 900 + 400 * (power - 1)
    local maxRise = 220 + 170 * (power - 1)
    if vel.z < maxRise then
        vel.z = math.min(vel.z + lift * dt, maxRise)
    end

    -- air control toward WASD, scaled by rotor power
    local f = math.Clamp(mv:GetForwardSpeed() / 400, -1, 1)
    local s = math.Clamp(mv:GetSideSpeed() / 400, -1, 1)
    if f ~= 0 or s ~= 0 then
        local ang = mv:GetMoveAngles()
        local fwd, right = ang:Forward(), ang:Right()
        fwd.z, right.z = 0, 0
        fwd:Normalize()
        right:Normalize()
        local wish = fwd * f + right * s
        local thrust = 700 + 250 * (power - 1)
        local maxH = 320 + 160 * (power - 1)
        local horiz = Vector(vel.x, vel.y, 0) + wish:GetNormalized() * thrust * dt
        if horiz:Length() > maxH then horiz = horiz:GetNormalized() * maxH end
        vel.x, vel.y = horiz.x, horiz.y
    end

    mv:SetVelocity(vel)
    ply.UKDW_HeliGrace = CurTime() + 1.5
end)

hook.Add("GetFallDamage", "UKSoulOrbs_HeliLanding", function(ply, speed)
    if (ply.UKDW_HeliGrace or 0) > CurTime() then return 0 end
end)

----------------------------------------------------------------------------------------------------
-- Client: power-up HUD meter + vignette, pickup flash, viewmodel copies
----------------------------------------------------------------------------------------------------

if CLIENT then

    local POWERUP_COLOR = Color(255, 153, 0) -- canon (1, 0.6, 0)
    local flashUntil = 0

    net.Receive("UKSoulOrbs_Flash", function()
        flashUntil = RealTime() + 0.12
    end)

    hook.Add("HUDPaint", "UKSoulOrbs_HUD", function()
        local w, h = ScrW(), ScrH()

        -- canon ParryFlash: short white blink on orb pickup
        if flashUntil > RealTime() then
            local a = 190 * (flashUntil - RealTime()) / 0.12
            surface.SetDrawColor(255, 255, 255, a)
            surface.DrawRect(0, 0, w, h)
        end

        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end
        local stacks = UKSoulOrbs.GetStacks(ply)
        if stacks <= 0 then return end

        local remaining = math.max(0, UKSoulOrbs.GetEndTime(ply) - CurTime())
        local frac = math.Clamp(remaining / math.max(UKSoulOrbs.GetMaxJuice(ply), 0.01), 0, 1)

        -- canon vignette: powerUpColor with alpha = juice/latestMaxJuice
        local va = math.floor(70 * frac)
        if va > 0 then
            local t = math.floor(h * 0.06)
            surface.SetDrawColor(POWERUP_COLOR.r, POWERUP_COLOR.g, POWERUP_COLOR.b, va)
            surface.DrawRect(0, 0, w, t)
            surface.DrawRect(0, h - t, w, t)
            surface.DrawRect(0, t, math.floor(w * 0.03), h - t * 2)
            surface.DrawRect(w - math.floor(w * 0.03), t, math.floor(w * 0.03), h - t * 2)
        end

        -- canon power-up timer: small hollow white ring beside the crosshair
        -- that depletes clockwise (gap grows from 12 o'clock)
        if frac > 0 then
            local r = math.max(6, math.floor(h * 0.016))
            local thick = math.max(1, math.floor(r * 0.22))
            local cx, cy = w / 2, h / 2
            local a1 = (1 - frac) * math.pi * 2 -- sweep edge, moves clockwise
            local a2 = math.pi * 2
            local n = math.max(2, math.ceil(48 * frac))
            draw.NoTexture()
            surface.SetDrawColor(255, 255, 255, 230)
            local ri = r - thick
            local sx, sy = math.sin(a1), -math.cos(a1)
            local ox, oy, ix, iy = cx + sx * r, cy + sy * r, cx + sx * ri, cy + sy * ri
            for i = 1, n do
                local a = a1 + (a2 - a1) * (i / n)
                sx, sy = math.sin(a), -math.cos(a)
                local ox2, oy2, ix2, iy2 = cx + sx * r, cy + sy * r, cx + sx * ri, cy + sy * ri
                surface.DrawPoly({
                    { x = ox, y = oy },
                    { x = ox2, y = oy2 },
                    { x = ix2, y = iy2 },
                    { x = ix, y = iy },
                })
                ox, oy, ix, iy = ox2, oy2, ix2, iy2
            end
        end
    end)

    ------------------------------------------------------------------------------------------------
    -- Viewmodel copies. Canon fans copies out sideways (±1.5 m per pair).
    -- Copies mirror the real gun's animation INSTANTLY (per spec) and
    -- each carries its own playermodel arms (bonemerged, like UseHands).
    ------------------------------------------------------------------------------------------------

    local copies = {} -- k -> ClientsideModel (gun)
    local hands = {}  -- k -> ClientsideModel (playermodel arms)

    local physBeamMat = Material("trails/physbeam")

    local function DropCopies()
        for k, mdl in pairs(copies) do
            if IsValid(mdl) then mdl:Remove() end
            copies[k] = nil
        end
        for k, mdl in pairs(hands) do
            if IsValid(mdl) then mdl:Remove() end
            hands[k] = nil
        end
    end

    hook.Add("PostDrawViewModel", "UKSoulOrbs_VMCopies", function(vm, ply, wep)
        if not IsValid(ply) or ply ~= LocalPlayer() then return end
        if vm ~= ply:GetViewModel(0) then return end

        local stacks = UKSoulOrbs.GetStacks(ply)
        if stacks <= 0 or not IsValid(wep) then
            if next(copies) then DropCopies() end
            return
        end

        local n = math.min(stacks, math.max(CVAR_VISUAL:GetInt(), 1))
        local mdlName = vm:GetModel()
        if not mdlName or mdlName == "" then return end

        -- playermodel arms, one set per copy. Engine weapons (HL2 pistol etc.)
        -- have no SWEP.UseHands field but their c_ viewmodels DO use hands
        local usesHands = wep.UseHands == true
            or mdlName:lower():find("weapons/c_", 1, true) ~= nil
        local realHands = ply:GetHands()
        local handsMdl = usesHands and IsValid(realHands) and realHands:GetModel() or nil
        if handsMdl == "" then handsMdl = nil end

        -- (re)create the fleet; weapon switch swaps copies instantly (canon)
        for k = 1, n do
            local c = copies[k]
            if not IsValid(c) or c:GetModel() ~= mdlName then
                if IsValid(c) then c:Remove() end
                if IsValid(hands[k]) then hands[k]:Remove() hands[k] = nil end
                c = ClientsideModel(mdlName, RENDERGROUP_OPAQUE)
                if not IsValid(c) then return end
                c:SetNoDraw(true)
                copies[k] = c
                c:ResetSequence(vm:GetSequence())
            end

            local hc = hands[k]
            if handsMdl then
                if not IsValid(hc) or hc:GetModel() ~= handsMdl then
                    if IsValid(hc) then hc:Remove() end
                    hc = ClientsideModel(handsMdl, RENDERGROUP_OPAQUE)
                    if IsValid(hc) then
                        hc:SetNoDraw(true)
                        -- same rig as UseHands: bonemerge the arms onto the gun copy
                        hc:SetParent(c)
                        hc:AddEffects(EF_BONEMERGE)
                        hands[k] = hc
                    end
                end
            elseif IsValid(hc) then
                hc:Remove()
                hands[k] = nil
            end
        end
        for k = n + 1, #copies do
            if IsValid(copies[k]) then copies[k]:Remove() end
            if IsValid(hands[k]) then hands[k]:Remove() end
            copies[k] = nil
            hands[k] = nil
        end

        local eyeAng = vm:GetAngles()
        local pos = vm:GetPos()
        local right, up = eyeAng:Right(), eyeAng:Up()
        local seq = vm:GetSequence()

        -- physgun: each copy fires its own beam toward the grab point
        local beamEnd, beamCol
        if wep:GetClass() == "weapon_physgun" and ply:KeyDown(IN_ATTACK) then
            beamEnd = ply:GetEyeTrace().HitPos
            local wc = ply:GetWeaponColor()
            beamCol = Color(wc.x * 255, wc.y * 255, wc.z * 255, 255)
        end

        for k = 1, n do
            local c = copies[k]
            if IsValid(c) then
                -- instant mirror: same sequence, same cycle, every frame
                if c:GetSequence() ~= seq then c:ResetSequence(seq) end
                c:SetCycle(vm:GetCycle())
                c:SetPlaybackRate(vm:GetPlaybackRate())

                -- canon layout: pairs fan out left/right, each ring a bit lower
                local ring = math.ceil(k / 2)
                local side = (k % 2 == 1) and 1 or -1
                c:SetPos(pos + right * (side * ring * 7) - up * (ring * 0.9))
                c:SetAngles(eyeAng)

                c:SetSkin(vm:GetSkin() or 0)
                for b = 0, vm:GetNumBodyGroups() - 1 do
                    c:SetBodygroup(b, vm:GetBodygroup(b))
                end

                c:DrawModel()

                local hc = hands[k]
                if IsValid(hc) then
                    if IsValid(realHands) then
                        hc:SetSkin(realHands:GetSkin() or 0)
                        for b = 0, realHands:GetNumBodyGroups() - 1 do
                            hc:SetBodygroup(b, realHands:GetBodygroup(b))
                        end
                    end
                    hc:DrawModel()
                end

                if beamEnd then
                    local attId = c:LookupAttachment("muzzle")
                    if not attId or attId <= 0 then attId = c:LookupAttachment("core") end
                    local att = (attId and attId > 0) and c:GetAttachment(attId) or nil
                    local beamStart = att and att.Pos
                        or (c:GetPos() + eyeAng:Forward() * 24)
                    render.SetMaterial(physBeamMat)
                    render.DrawBeam(beamStart, beamEnd, 3, 0,
                        beamStart:Distance(beamEnd) / 128, beamCol)
                end
            end
        end
    end)

end
