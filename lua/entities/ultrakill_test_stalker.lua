AddCSLuaFile()

local BaseClass = baseclass.Get( "ultrakillbase_nextbot" )

ENT.Type        = "nextbot"
ENT.Base        = "ultrakillbase_nextbot"
ENT.PrintName   = "Stalker"
ENT.Author      = "ultragmod"
ENT.Spawnable   = true
ENT.Category    = "ULTRAKILL - Enemies"

ENT.Models      = { "models/ultrakill_prelude_test/stalker.mdl" }
ENT.ModelScale  = 1.5
ENT.SpawnHealth = 3500
ENT.CollisionBounds   = Vector( 30, 30, 90 )
ENT.SurroundingBounds = Vector( 50, 50, 100 )

-- ─────────────────────────────────────────────────────────────────────────
-- Canon-derived constants. 1 Unity unit = 1 metre. Source conversion taken
-- from source/filth_v6.qc:2 ("Unity 1m = 39.3701 inches").
-- ─────────────────────────────────────────────────────────────────────────
local UNITS_PER_METRE     = 39.3701

-- Timing (canon Stalker.cs:59-60, 256, 264, 266, 283, 285)
local PREP_TIME           = 5.0
local PREP_WARNING_TIME   = 3.0
local ARMED_GATE_TIME     = 6.0    -- prepareTime + 1f
local COUNTDOWN_DURATION  = 2.0    -- countDownAmount ramps from 0 → 2

-- Distances (canon Stalker.cs:194, 290)
local TRIGGER_DISTANCE    = 8.0 * UNITS_PER_METRE   -- ≈ 315
local CLOSE_THRESHOLD     = 100  * UNITS_PER_METRE  -- canon "close" pass

-- Explosion (canon Stalker.cs:389, 392, 397-401)
local EXPLOSION_Z_OFFSET     = 2.5 * UNITS_PER_METRE  -- ≈ 98
local EXPLOSION_RADIUS_BASE  = 250
local EXPLOSION_SELF_MULT    = 1.5
local EXPLOSION_DAMAGE       = 10

-- Blink cadence (canon Stalker.cs:324)
local BLINK_INTERVAL         = 0.1

-- Fall-death threshold: total airborne descent (max-Z-while-airborne minus
-- current Z) that triggers a self-detonate via Suicide(DMG_FALL). Canon: ANY
-- death triggers SandExplode (Stalker.cs:418 GoLimp; OnDeath path here calls
-- SandExplode(1)). Using the airborne-descent method (rather than instantaneous
-- velocity) so stepping off a small ledge into a longer drop still counts.
local FALL_DEATH_DISTANCE    = 400        -- ~10m of fall

-- Frame in the Explode sequence where the canister visually impacts/lands.
-- Sequence is 90 frames @ 30fps (~3.0s total — see HLMV); the impact pose
-- lands around frame 44 (≈1.467s into countdown). The remaining ~1.5s of
-- the sequence is post-impact follow-through and doesn't get to play since
-- the Stalker is destroyed at hit. The detonation fires on the impact frame
-- so the blast is sync'd to the visible canister landing, not to the end of
-- the sequence or a fixed timer.
local EXPLODE_HIT_FRAME      = 43
local EXPLODE_HIT_TIME       = EXPLODE_HIT_FRAME / 30

-- Per-state light/sound — re-derived from canon (decomp audit).
-- Canon flow (Stalker.cs:78-81, 264-281, 315-324, 368-380):
--   Phase A (0..prepareWarning):   green_steady   — no audio, no blink
--   Phase B (prepareWarning..prepareTime): green_blink — STILL green color (currentColor not yet
--                                  switched to lightColors[1]), but `blinking=true`. lightSounds[0]
--                                  (Stalker_Arming.ogg, vol 0.35, pitch 1.0, loop=false) plays
--                                  via the blink branch on each black half.
--   Phase C (>=prepareTime):       yellow_solid — currentColor→lightColors[1], blinking=false,
--                                  clip switched to lightSounds[1] (Stalker_Armed.ogg, vol 0.65,
--                                  pitch 0.5, loop=true) and immediately Play()'d.
--   Phase D (Countdown()):         red_blink — currentColor→lightColors[2], blinking=true,
--                                  clip→lightSounds[2] (Stalker_Countdown_1.ogg, vol 0.65, pitch
--                                  1.0, loop=false). Plus a one-shot `screamSound` (we map this
--                                  to Stalker_Warning.ogg — name is misleading, it's the canon
--                                  scream prefab) instantiated immediately at Countdown entry.
-- Blink semantics (Stalker.cs:315-324): unconditional Stop on color half, unconditional Play on
-- black half — for BOTH looped (yellow armed if blinking) and one-shot (countdown beep) clips.
-- Format: color, sound, pitch (0-255 GMod, 100=1.0×), volume (0-1), loop, blink, size
local LightState = {
  green_steady = {                                -- Phase A: charge < prepareWarningTime
    color  = Color(  60, 255,  60 ),
    sound  = nil,
    pitch  = 100, volume = 0.35,
    loop   = false, blink = false,
    size   = 40,
  },
  green_blink  = {                                -- Phase B: charge >= prepareWarningTime
    color  = Color(  60, 255,  60 ),              -- canon: STILL green here, not yellow
    sound  = "ultrakill_test/stalker_arming.wav", -- lightSounds[0]
    pitch  = 100, volume = 0.35,
    loop   = false, blink = true,
    size   = 60,
  },
  yellow_solid = {                                -- Phase C: charge >= prepareTime
    color  = Color( 255, 200,   0 ),
    sound  = "ultrakill_test/stalker_armed.wav",  -- lightSounds[1]
    pitch  = 50,  volume = 0.65,                  -- canon SetPitch(0.5) + vol 0.65, loop=true
    loop   = true, blink = false,
    size   = 90,
  },
  red_blink    = {                                -- Phase D: Countdown()
    color  = Color( 255,  30,  30 ),
    sound  = "ultrakill_test/stalker_countdown.wav", -- lightSounds[2]
    pitch  = 100, volume = 0.65,                  -- canon SetPitch(1f) + vol 0.65, loop=false
    loop   = false, blink = true,
    size   = 110,
  },
}

-- AI/range. ReachEnemyRange must be SMALLER than TRIGGER_DISTANCE so the bot
-- keeps walking right up until the trigger fires. If they're equal/close, the
-- chase coroutine halts at the trigger boundary and the Stalker just stands.
ENT.MeleeAttackRange = 0
ENT.ReachEnemyRange  = 80
ENT.AvoidEnemyRange  = 0
ENT.RunOnDistance    = TRIGGER_DISTANCE * 2.5

-- Detection
ENT.EyeBone = "Head"

-- Locomotion (canon GetSpeed: angularSpeed=1600, accel=64 — Unity NavMesh values,
-- not directly portable; tune via DrGBase fields).
ENT.Acceleration   = 2000
ENT.Deceleration   = 1500
ENT.JumpHeight     = 120
ENT.StepHeight     = 20
ENT.MaxYawRate     = 360
ENT.DeathDropHeight = 30
ENT.UseWalkframes  = false
ENT.WalkSpeed      = 50
ENT.RunSpeed       = 110

-- Animations (canon: SetBool("Walking", v>0), SetBool("Running", v>5), SetTrigger("Explode"))
ENT.IdleAnimation    = "Idle"
ENT.IdleAnimRate     = 1
ENT.WalkAnimation    = "Walking"
ENT.WalkAnimRate     = 1
ENT.RunAnimation     = "Running"
ENT.RunAnimRate      = 1
ENT.JumpAnimation    = "Falling"
ENT.JumpAnimRate     = 1
ENT.FallingAnimation = "Falling"
ENT.FallingAnimRate  = 1

ENT.Factions = { "FACTION_ULTRAKILL_ENEMIES" }
ENT.RagdollOnDeath = false

-- Possession --

ENT.PossessionCrosshair = true
ENT.PossessionEnabled = true
ENT.PossessionMovement = POSSESSION_MOVE_1DIR
ENT.PossessionViews = {

  {

    offset = Vector( 0, 14, 41 ),
    distance = 140,
    eyepos = false

  },

  {

    offset = Vector( 7, 0, 0 ),
    distance = 0,
    eyepos = true

  }

}

ENT.PossessionBinds = {

  [ IN_ATTACK2 ] = { { coroutine = true, onkeydown = function( self )

    -- Deliberate detonation. Same gates as the AI proximity trigger: must be
    -- armed (charge past ARMED_GATE_TIME) and not already counting down —
    -- otherwise a held key would reset UKStalker_CountdownT every tick and
    -- the bomb would never go off.
    if self.UKStalker_InAction or self.UKStalker_AlreadyExploded then return end
    if self.UKStalker_ChargeTime < ARMED_GATE_TIME then return end

    self:UKStalker_StartCountdown()

  end } },

}

-- NW2 keys (server publishes, client reads in glow hook)
local NW_LIGHT  = "UKStalker_LightState"
local NW_BLINK  = "UKStalker_BlinkOn"
local NW_HPFRAC = "UKStalker_HPFrac"

hook.Add( "Initialize", "UKStalker_RegisterRank", function()
  if UKIdol and UKIdol.RegisterRank then
    UKIdol.RegisterRank( "ultrakill_test_stalker", 4 )
  end
end )

function ENT:CustomInitialize()
  -- Permanently sandified mechanically; visually overridden in _BaseDraw.
  self:SetNW2Bool( UKSand.NW2.Sand,     true  )
  self:SetNW2Bool( UKSand.NW2.Sandable, false )

  -- Randomize starting charge so multiple Stalkers spawned at the same time
  -- desync — otherwise they all reach prepareTime simultaneously and detonate
  -- as one "timer for the whole group". 0..2.5s spread keeps everyone within
  -- one warning-cycle of each other, so they still feel like a coordinated
  -- threat without a literal countdown chorus.
  self.UKStalker_ChargeTime      = math.Rand( 0, 2.5 )
  self.UKStalker_CountdownT      = 0
  self.UKStalker_LightState      = "green_steady"
  self.UKStalker_InAction        = false
  self.UKStalker_AlreadyExploded = false
  self.UKStalker_BlinkAccum      = 0
  self.UKStalker_BlinkOn         = false          -- true = light is BLACK (off-frame)
  self.UKStalker_MaxHP           = self.SpawnHealth or 3500
  self.UKStalker_CurrentTarget   = nil
  self.UKStalker_Sound           = nil

  self:SetNW2String( NW_LIGHT, "green_steady" )
  self:SetNW2Bool( NW_BLINK, false )
  self:SetNW2Float( NW_HPFRAC, 1.0 )

  -- Canon Stalker.cs:74-85 Start() only configures lightSounds[0], it does NOT
  -- call Play(). The arming clip is first heard via the blink branch in Phase B.
  -- (Earlier ports played it as a spawn beep — wrong.)

  self:NextThink( CurTime() + 0.5 )
end

function ENT:UKStalker_SetLight( s )
  self.UKStalker_LightState = s
  if SERVER then self:SetNW2String( NW_LIGHT, s ) end
end

if SERVER then

-- ─── Target lifecycle (canon ChangeTarget/RemoveTarget, Stalker.cs:225-247) ───

function ENT:UKStalker_HateAndChase( target )
  if not IsValid( target ) then return end
  -- DrGBase chase coroutine reads HL2-style AddEntityRelationship, NOT the
  -- nextbot-specific SetEntityRelationship. Use both so any framework path
  -- picks up the override. ClearEnemyMemory flushes any cached ally state
  -- from the faction system — without it, the override is silently ignored.
  if self.AddEntityRelationship then
    self:AddEntityRelationship( target, D_HT, 99 )
  end
  if self.SetEntityRelationship then
    self:SetEntityRelationship( target, D_HT, 99 )
  end
  if self.ClearEnemyMemory then self:ClearEnemyMemory() end
  self:SetEnemy( target )
end

function ENT:UKStalker_ChangeTarget( newTarget )
  if IsValid( self.UKStalker_CurrentTarget ) and self.UKStalker_CurrentTarget ~= newTarget then
    UKStalker.Release( self, self.UKStalker_CurrentTarget )
  end
  UKStalker.Reserve( self, newTarget )
  self.UKStalker_CurrentTarget = newTarget
  self:UKStalker_HateAndChase( newTarget )
end

function ENT:UKStalker_RemoveTarget()
  if IsValid( self.UKStalker_CurrentTarget ) then
    UKStalker.Release( self, self.UKStalker_CurrentTarget )
  end
  self.UKStalker_CurrentTarget = nil
  self:SetEnemy( NULL )
end

-- ─── Canon SlowUpdate (Stalker.cs:162-223) — 7-tier rank pass ───────────────

function ENT:SlowUpdate()
  if self.UKStalker_InAction then return end

  local pool = {}
  for _, e in ipairs( ents.GetAll() ) do
    if UKSand.IsValidStalkerTarget( e, self ) then
      table.insert( pool, e )
    end
  end

  local function rankOf( e )
    return ( UKIdol and UKIdol.GetRank and UKIdol.GetRank( e ) ) or 0
  end
  local function distTo( e ) return self:GetPos():Distance( e:GetPos() ) end

  local currentTarget = self.UKStalker_CurrentTarget
  -- Canon: at each rank tier 7→0, pick closest. Within tier, "flag" (close, untaken)
  -- wins immediately; "flag2" (taken-by-other OR far) is held as fallback across tiers.
  local foundClose, foundFar = nil, nil
  local closeDist, farDist   = math.huge, math.huge

  for tier = 7, 0, -1 do
    for _, e in ipairs( pool ) do
      if rankOf( e ) == tier then
        local d = distTo( e )
        local takenByOther = UKStalker.IsTaken( e ) and UKStalker.Owner( e ) ~= self
        -- Currently-targeted self-claim doesn't count as taken by another (canon flag3).
        if IsValid( currentTarget ) and e == currentTarget then takenByOther = false end

        if takenByOther or d >= CLOSE_THRESHOLD then
          if d < farDist then foundFar, farDist = e, d end
        else
          if d < closeDist then foundClose, closeDist = e, d end
        end
      end
    end
    if IsValid( foundClose ) then
      self:UKStalker_ChangeTarget( foundClose )
      return
    end
  end
  if IsValid( foundFar ) then
    self:UKStalker_ChangeTarget( foundFar )
    return
  end

  -- No enemy candidates — canon: release prior, fall back to player.
  if IsValid( currentTarget ) then self:UKStalker_RemoveTarget() end

  -- fallback-скан игроков ОБЯЗАН уважать ai_ignoreplayers (DrGBase-опция
  -- "ignore players"), иначе стокер гонится вопреки настройке
  local cvIgnore = GetConVar( "ai_ignoreplayers" )
  if cvIgnore and cvIgnore:GetBool() then return end

  local plyTarget, plyBestDist = nil, math.huge
  for _, ply in ipairs( player.GetAll() ) do
    if ply:Alive() then
      local d = self:GetPos():Distance( ply:GetPos() )
      if d < plyBestDist then plyTarget, plyBestDist = ply, d end
    end
  end
  if IsValid( plyTarget ) then
    self:UKStalker_HateAndChase( plyTarget )
  end
end

-- ─── State machine (canon Stalker.cs:249-296) ──────────────────────────────

-- Canon Stalker.cs separates "configure clip" from "actually Play()".
-- Start() and Countdown() only assign clip/loop/pitch/volume — they don't Play().
-- The yellow_solid transition is the ONLY transition that immediately Plays the
-- loop (Stalker.cs:281). All blink-gated states (green_blink, red_blink) wait for
-- the blink branch to call Play() on each black half.
function ENT:UKStalker_StateTransition( newState )
  if newState == self.UKStalker_LightState then return end
  self:UKStalker_SetLight( newState )

  if self.UKStalker_Sound then
    self.UKStalker_Sound:Stop()
    self.UKStalker_Sound = nil
  end

  local spec = LightState[ newState ]
  if spec and spec.sound then
    self.UKStalker_Sound = CreateSound( self, spec.sound )
    self.UKStalker_Sound:SetSoundLevel( 90 )
    -- Only the armed loop plays immediately; blink-states will be Play'd by the
    -- blink branch.
    if not spec.blink then
      self.UKStalker_Sound:PlayEx( spec.volume, spec.pitch )
    end
  end
end

function ENT:UpdateStateMachine()
  -- HP fraction for client glow (canon Stalker.cs:309)
  local maxhp = self.UKStalker_MaxHP
  local hp    = self:Health()
  local frac  = ( hp + 0.2 ) / ( maxhp + 0.2 )
  if frac < 0 then frac = 0 end
  self:SetNW2Float( NW_HPFRAC, frac )

  -- DrGBase totalSpeedModifier approximation (canon Stalker.cs:256, 266, 285)
  local mod = ( self.IsRadiant and self:IsRadiant() ) and 1.5 or 1.0

  if self.UKStalker_InAction then
    self.UKStalker_CountdownT = self.UKStalker_CountdownT + FrameTime() * mod
    -- Detonate at the canister-impact frame in the Explode sequence (synced
    -- to the visible animation hit, not to a timer or sequence end).
    if self.UKStalker_CountdownT >= EXPLODE_HIT_TIME then
      self:SandExplode( 0 )
    end
    return
  end

  if self.UKStalker_ChargeTime < ARMED_GATE_TIME then
    self.UKStalker_ChargeTime = math.min(
      self.UKStalker_ChargeTime + FrameTime() * mod, ARMED_GATE_TIME )
  end

  local ct = self.UKStalker_ChargeTime
  local s  = self.UKStalker_LightState
  -- Canon (Stalker.cs:264-281):
  --   PREP_WARNING_TIME: blinking=true, but currentColor stays at lightColors[0] (green)
  --   PREP_TIME:         currentColor switches to lightColors[1] (yellow), blinking=false
  if ct >= PREP_WARNING_TIME and s == "green_steady" then
    self:UKStalker_StateTransition( "green_blink" )
  elseif ct >= PREP_TIME and s == "green_blink" then
    self:UKStalker_StateTransition( "yellow_solid" )
  end

  -- Proximity trigger only once ARMED_GATE_TIME reached (canon: explosionCharge >= prepareTime+1).
  -- While possessed, detonation is the possessor's deliberate call (IN_ATTACK2 bind),
  -- so the auto-trigger stays off; the charge/light machine above keeps running.
  if ct >= ARMED_GATE_TIME and not self:IsPossessed() then
    local enemy = self:GetEnemy()
    if IsValid( enemy ) and self:GetPos():Distance( enemy:GetPos() ) < TRIGGER_DISTANCE then
      self:UKStalker_StartCountdown()
    end
  end

  -- Blink tick: toggle BlinkOn flag every BLINK_INTERVAL when state.blink.
  -- Canon Stalker.cs:316-323: lightAud.Play() when light → BLACK; lightAud.Stop() when → color.
  local lstate = LightState[ self.UKStalker_LightState ]
  if lstate and lstate.blink then
    self.UKStalker_BlinkAccum = self.UKStalker_BlinkAccum + FrameTime()
    if self.UKStalker_BlinkAccum >= BLINK_INTERVAL then
      self.UKStalker_BlinkAccum = 0
      self.UKStalker_BlinkOn = not self.UKStalker_BlinkOn
      self:SetNW2Bool( NW_BLINK, self.UKStalker_BlinkOn )

      -- Canon audio gating (Stalker.cs:315-324): unconditional Play on BLACK,
      -- unconditional Stop on color — for BOTH loop (would be the case if armed
      -- entered blink) and one-shot (countdown beep). Replaying restarts the
      -- clip from t=0, giving the canon "beep-beep-beep" rhythm for short clips.
      if self.UKStalker_Sound then
        if self.UKStalker_BlinkOn then
          self.UKStalker_Sound:PlayEx( lstate.volume, lstate.pitch )
        else
          self.UKStalker_Sound:Stop()
        end
      end
    end
  elseif self.UKStalker_BlinkOn then
    self.UKStalker_BlinkOn = false
    self:SetNW2Bool( NW_BLINK, false )
  end
end

function ENT:UKStalker_StartCountdown()
  self.UKStalker_InAction      = true
  self.UKStalker_CountdownT    = 0
  self.UKStalker_CountdownDur  = COUNTDOWN_DURATION   -- default fallback
  self:UKStalker_StateTransition( "red_blink" )

  -- Canon Stalker.cs:379: Object.Instantiate(screamSound, base.transform) — a
  -- separate scream prefab attached to the Stalker. Plays once at Countdown
  -- entry, independent of the blink-gated lightSounds[2] beep. We approximate
  -- the prefab via a world one-shot of stalker_warning.wav (the canon scream
  -- clip — name "Warning" is misleading; the audio audit traced it to the
  -- screamSound slot, not lightSounds[1]).
  sound.Play( "ultrakill_test/stalker_warning.wav", self:GetPos(), 95, 100, 1 )

  -- Canon: anim.SetTrigger("Explode") — one-shot. Source equivalent: DrGBase's
  -- fresh-sequence trinity (animations.lua:162-166): SetSequence + ResetSequenceInfo
  -- + SetCycle(0). Skipping the last two means the second Stalker spawned in a
  -- session inherits cycle != 0 from somewhere, and because DrGBase's UpdateAnimation
  -- only runs its own reset when current sequence DIFFERS from the lookup (we
  -- already made Explode current here), it never gets re-zeroed → broken anim.
  if self.SetSequence and self.LookupSequence then
    local seqId = self:LookupSequence( "Explode" )
    if seqId and seqId >= 0 then
      self:SetSequence( seqId )
      if self.ResetSequenceInfo then self:ResetSequenceInfo() end
      self:SetCycle( 0 )
      self:SetPlaybackRate( 1 )
      if self.SequenceDuration then
        local dur = self:SequenceDuration( seqId )
        if dur and dur > 0 then self.UKStalker_CountdownDur = dur end
      end
    end
  end

  -- Canon stops via SetDestination(transform.position) — target kept, locomotion frozen.
  -- We don't clear the enemy: OnUpdateAnimation override forces Idle pose, and DrGBase chase
  -- coroutine will simply not advance us out of trigger range during the 2s countdown.
end

-- During countdown, play the Explode animation (canon: walk/run anims blocked
-- when inAction, Explode trigger fires). Returning "Explode" here keeps it as
-- the active anim every tick — otherwise OnUpdateAnimation would overwrite the
-- SetSequence call from StartCountdown back to Idle on the very next frame.
--
-- Use a hardcoded playback rate (1.0). CalculateRate() pulls in framework
-- modifiers that can return 0 in some entity states (radiance reset, recently
-- killed entity, etc.), which would freeze the Explode anim on a second-spawn
-- Stalker after the first one detonated. The 2s countdown timer in
-- UpdateStateMachine doesn't depend on the anim rate, so the bot still
-- explodes on schedule even if rate were ever degenerate.
function ENT:OnUpdateAnimation()
  if self.UKStalker_InAction then
    return "Explode", 1.0
  end
  if BaseClass and BaseClass.OnUpdateAnimation then
    return BaseClass.OnUpdateAnimation( self )
  end
end

-- ─── Explosion (canon Stalker.cs:383-432) ──────────────────────────────────
-- Canon ORDER:
--   line 389: explosion prefab Instantiate (FX + AOE damage happens HERE)
--   line 407: survival check (onDeath != 1 && (Hard+ || blessed || invincible))
--             → reset state, return BEFORE setting `exploded = true` and BEFORE
--             GoLimp/Death/Destroy
--   line 417: exploded = true; GoLimp; Death; Destroy
--
-- I had this inverted earlier (survival check FIRST) which produced the "Stalker
-- under Idol bless plays anim but no boom" symptom: a blessed Stalker reached
-- countdown → SandExplode(0) → survival branch returned BEFORE any FX, so no
-- explosion was visible. Canon: explosion VISUAL+DAMAGE happens; the Stalker
-- itself just doesn't die.

function ENT:SandExplode( onDeath )
  if self.UKStalker_AlreadyExploded then return end
  self.UKStalker_AlreadyExploded = true

  local pos = self:GetPos() + Vector( 0, 0, EXPLOSION_Z_OFFSET )
  local scale = 1.0
  if onDeath == 0 then scale = scale * EXPLOSION_SELF_MULT end
  -- Magnet penalty (canon Stalker.cs:397-401): stub — magnets system not present in mod.
  local radius = EXPLOSION_RADIUS_BASE * scale

  -- Kill the looped warning / scream channel so it doesn't bleed through
  -- the explosion clip. Canon: scream prefab is parented to the Stalker
  -- transform and gets destroyed when the Stalker is (Stalker.cs:431
  -- Object.Destroy(base.gameObject)). For blessed-survival case the
  -- Stalker resumes after — StateTransition("green_steady") below will
  -- spin up the green-phase audio channel fresh.
  if self.UKStalker_Sound then
    self.UKStalker_Sound:Stop()
    self.UKStalker_Sound = nil
  end

  -- Kevin's base ships a dedicated big detonation particle for the Stalker;
  -- round 2 (2026-07-10): play BOTH — the big blast plus the small
  -- sandify puff layered on top
  ParticleEffect( "Ultrakill_SandExplosionStalker", pos, Angle() )
  ParticleEffect( "Ultrakill_SandExplosion", pos, Angle() )
  sound.Play( "ultrakill_test/sand_explosion.wav", pos, 100, 100, 1 )

  for _, e in ipairs( ents.FindInSphere( pos, radius ) ) do
    if IsValid( e ) and e ~= self and ( e:IsNPC() or e:IsNextBot() or e:IsPlayer() ) then
      -- Canon-faithful filter: sandified targets are immune to sand explosions
      -- (Stalker.cs:182 explicitly skips sandified from the target list; the
      -- canon Explosion prefab additionally carries a serialized `toIgnore` list
      -- — not exposed in the extraction but consistent with the design). Without
      -- this filter, ONE Stalker detonating chain-kills nearby Stalkers because
      -- their OnDeath → SandExplode(1) re-explodes. Tag this branch with class
      -- check too — covers any other permanently-sand husks in the future.
      local isStalker  = e:GetClass() == "ultrakill_test_stalker"
      local isAlrSand  = UKSand and UKSand.IsSand and UKSand.IsSand( e )
      if not isStalker and not isAlrSand then
        -- canon SandificationZone.Enter (round-3 follow-up, 2026-07-10):
        -- NPCs are only SANDIFIED — the sand is support, not an attack (in
        -- 7-2 it even buffs enemies); ONLY the player takes blast damage.
        -- The old code hurt every NPC in the radius (originally 200 landed,
        -- briefly x100 during the damage sweep) — removed entirely.
        if e:IsPlayer() then
          local dmg = DamageInfo()
          dmg:SetDamage( EXPLOSION_DAMAGE )
          dmg:SetDamageType( DMG_BLAST )
          dmg:SetAttacker( self )
          dmg:SetInflictor( self )
          e:TakeDamageInfo( dmg )
        end
        if UKSand and UKSand.Apply then UKSand.Apply( e, self ) end
      end
    end
  end

  -- Canon survival check (Stalker.cs:407-415): runs AFTER the explosion FX/AOE
  -- already fired above. Only blocks the SELF-KILL — the world still saw the
  -- blast. For self-detonate (onDeath == 0), bless / Hard+ / InvincibleEnemies
  -- skip GoLimp/Death/Destroy. For damage-induced death (onDeath == 1) the
  -- Stalker dies regardless.
  local isSurvival = false
  if onDeath ~= 1 then
    if UKIdol and UKIdol.Blessed and UKIdol.Blessed[ self ] then isSurvival = true end
    -- canon Stalker.cs:407: on Brutal+ the self-detonation never kills the
    -- Stalker — he sheds the charge and walks away (2026-07-10, was a stub)
    local diff = self.UltrakillBase_Difficulty
      or ( UltrakillBase.GetDifficulty and UltrakillBase.GetDifficulty() ) or 3
    if diff > 3 then isSurvival = true end
  end

  if isSurvival then
    self.UKStalker_InAction        = false
    self.UKStalker_CountdownT      = 0
    self.UKStalker_ChargeTime      = 0
    self.UKStalker_AlreadyExploded = false
    self:UKStalker_StateTransition( "green_steady" )
    if self.SetSequence and self.LookupSequence then
      local idle = self:LookupSequence( "Idle" )
      if idle and idle >= 0 then self:SetSequence( idle ) end
    end
    return
  end

  -- Guaranteed kill via DrGBase's own Suicide → Kill → OnKilled path (drgbase
  -- nextbots track health internally; TakeDamageInfo with self:Health() does not
  -- actually reach OnKilled because Entity:Health() isn't the framework HP).
  -- _AlreadyExploded gate stops reentry from OnDeath → SandExplode(1).
  if self.Suicide then
    self:Suicide( DMG_BLAST )
  elseif self.Kill then
    self:Kill( self, self, DMG_BLAST )
  else
    -- Last-resort fallback
    self:Remove()
  end
end

function ENT:OnDeath()
  if not self.UKStalker_AlreadyExploded then
    self:SandExplode( 1 )
  end
  if IsValid( self.UKStalker_CurrentTarget ) then
    UKStalker.Release( self, self.UKStalker_CurrentTarget )
  end
  if self.UKStalker_Sound then self.UKStalker_Sound:Stop() end
  if BaseClass and BaseClass.OnDeath then BaseClass.OnDeath( self ) end
end

-- ─── Step prefab sound (canon Stalker.cs:472-475 / Step() anim event) ──────
-- Canon spawns `stepSound` GameObject via animation event. GMod nextbot SMD
-- anim events would need a recompile, so we drive it from server-side velocity:
-- emit a step at the canon Running threshold (velocity > 5 unity units → ~197 hu),
-- with cadence scaling between walk and run.

local STEP_THRESHOLD_HU      = 5 * UNITS_PER_METRE   -- canon Walking gate, ~197 hu
local STEP_INTERVAL_WALK     = 0.55
local STEP_INTERVAL_RUN      = 0.32
local STEP_RUN_VELOCITY_HU   = 80                    -- velocity above which we treat as run cadence

-- ─── Fall death (canon: any death triggers SandExplode) ────────────────────
-- Track highest Z reached while airborne; on landing, if drop ≥ threshold,
-- Suicide(DMG_FALL) → OnDeath → SandExplode(1).

function ENT:UKStalker_TickFall()
  if self.UKStalker_AlreadyExploded then return end
  local pos = self:GetPos()

  if not self:IsOnGround() then
    -- airborne: track peak altitude
    if not self.UKStalker_FallPeakZ or pos.z > self.UKStalker_FallPeakZ then
      self.UKStalker_FallPeakZ = pos.z
    end
    return
  end

  -- on ground: evaluate drop relative to peak
  if self.UKStalker_FallPeakZ then
    local drop = self.UKStalker_FallPeakZ - pos.z
    self.UKStalker_FallPeakZ = nil
    if drop >= FALL_DEATH_DISTANCE then
      if self.Suicide then
        self:Suicide( DMG_FALL )
      elseif self.Kill then
        self:Kill( self, self, DMG_FALL )
      end
    end
  end
end

function ENT:UKStalker_TickStep()
  if self.UKStalker_InAction then return end
  local v = self:GetVelocity():Length2D()
  if v < STEP_THRESHOLD_HU then return end
  local interval = ( v >= STEP_RUN_VELOCITY_HU ) and STEP_INTERVAL_RUN or STEP_INTERVAL_WALK
  if self.UKStalker_LastStep and CurTime() - self.UKStalker_LastStep < interval then return end
  self.UKStalker_LastStep = CurTime()
  sound.Play( "ultrakill_test/stalker_step.wav", self:GetPos(), 75, math.random( 95, 105 ), 1 )
end

function ENT:Think()
  if BaseClass and BaseClass.Think then BaseClass.Think( self ) end
  -- ai_disabled / per-bot disable: замораживает таргет-скан, машину
  -- состояний детонации и шаги (канон: только этот чит стопит стокера)
  if self:IsAIDisabled() then return end
  -- Possessed: only the autonomous target scan pauses (the possessor steers);
  -- the state machine, steps and fall death below stay live — the IN_ATTACK2
  -- detonation bind depends on them.
  if not self:IsPossessed() then
    if not self.UKStalker_LastSlow or CurTime() - self.UKStalker_LastSlow >= 0.5 then
      self:SlowUpdate()
      self.UKStalker_LastSlow = CurTime()
    end
  end
  self:UpdateStateMachine()
  self:UKStalker_TickStep()
  self:UKStalker_TickFall()
end

hook.Add( "EntityRemoved", "UKStalker_StopSounds", function( ent )
  if IsValid( ent ) and ent.UKStalker_Sound then ent.UKStalker_Sound:Stop() end
end )

-- Debug: dumps every live Stalker's state to server console. Use to verify
-- per-instance timers aren't actually shared:
--   `lua_run_sv UKStalker_Dump()` or via concommand `stalker_dump` (admin only).
function UKStalker_Dump()
  for _, e in ipairs( ents.FindByClass( "ultrakill_test_stalker" ) ) do
    if IsValid( e ) then
      print( string.format(
        "[Stalker #%d] charge=%.2f state=%s inAction=%s countdownT=%.2f hp=%d/%d",
        e:EntIndex(),
        e.UKStalker_ChargeTime or -1,
        tostring( e.UKStalker_LightState ),
        tostring( e.UKStalker_InAction ),
        e.UKStalker_CountdownT or -1,
        e:Health(),
        e.UKStalker_MaxHP or -1 ) )
    end
  end
end
concommand.Add( "stalker_dump", function( ply )
  if IsValid( ply ) and not ply:IsAdmin() then return end
  UKStalker_Dump()
end )

end -- SERVER

if CLIENT then

-- Skip UltrakillBase sand-material overlay — Stalker's model already has T_StalkerSand baked in.
function ENT:_BaseDraw()
  if self.IsRadiant and self:IsRadiant() and self.DrawRadiant then self:DrawRadiant() end
  if self.UltrakillBase_Enraged_Draw and self.DrawEnraged then self:DrawEnraged() end
  render.MaterialOverride()
  if self.RenderShake then self:RenderShake() end
end

end -- CLIENT _BaseDraw

if CLIENT then

-- ─── Canister glow: native VMT $selfillum on stalker_can material ───────────
-- Canon Stalker.cs:334 paints `_EmissiveColor` on the canRenderer's material.
-- We mirror that natively: stalker_can.vmt declares $selfillum + $selfillummask
-- (T_SandCanEmission) + UKStalkerGlow MaterialProxy. The proxy reads NW2 state
-- per-entity and writes $selfillumtint each frame. No runtime SubMaterial swap
-- needed — the material itself is canon-emissive, and the mask shape ensures
-- only the canon "hot" elements of the canister UV light up (not the whole
-- glass shell — per glow audit DIV-A and emission-mask shape analysis).

-- DynamicLight ambient for the canister bone — supplements the model emissive
-- so the Stalker also illuminates the world during night-time / dark maps.
hook.Add( "Think", "UKStalker_DynLights", function()
  for _, ent in ipairs( ents.FindByClass( "ultrakill_test_stalker" ) ) do
    if not IsValid( ent ) or ent:IsDormant() then continue end

    -- Canon hard blink: skip the dlight on the black half.
    if ent:GetNW2Bool( "UKStalker_BlinkOn", false ) then continue end

    local state  = ent:GetNW2String( "UKStalker_LightState", "green_steady" )
    local hpFrac = ent:GetNW2Float( "UKStalker_HPFrac", 1.0 )
    -- Canon: Phase B keeps the light GREEN (only blinking changes); switch to
    -- yellow only at Phase C / yellow_solid.
    local col
    if state == "green_steady" then col = { r =  60, g = 255, b =  60, size = 160 }
    elseif state == "green_blink"  then col = { r =  60, g = 255, b =  60, size = 240 }
    elseif state == "yellow_solid" then col = { r = 255, g = 200, b =   0, size = 320 }
    elseif state == "red_blink"    then col = { r = 255, g =  30, b =  30, size = 400 }
    else col = { r = 60, g = 255, b = 60, size = 160 } end

    local pos
    local can = ent:LookupBone( "Can" )
    if can then
      local m = ent:GetBoneMatrix( can )
      if m then pos = m:GetTranslation() end
    end
    if not pos then pos = ent:WorldSpaceCenter() + ent:GetUp() * 25 end

    local dl = DynamicLight( ent:EntIndex() )
    if dl then
      dl.Pos        = pos
      dl.r          = math.floor( col.r * hpFrac )
      dl.g          = math.floor( col.g * hpFrac )
      dl.b          = math.floor( col.b * hpFrac )
      dl.Brightness = 1.5
      dl.Size       = col.size
      dl.Decay      = 1000
      dl.DieTime    = CurTime() + 0.1
    end
  end
end )

end -- CLIENT glow wire

-- The engine calls OnTakeDamage directly (hitgroup=nil) BEFORE DrGBase's
-- OnInjured re-calls it with a real hitgroup; without this gate the base
-- DamageMultiplier runs twice (x10 player damage twice = x100).
if SERVER then
  function ENT:OnTakeDamage( dmg, hitgroup )
    if not isnumber( hitgroup ) then return end
    BaseClass.OnTakeDamage( self, dmg, hitgroup )
  end
end

-- DrGBase nextbot registration — required for list.Get("NPC") membership / Q-menu.
DrGBase.AddNextbot( ENT )
