-- lua/entities/ultrakill_test_mdk_crash.lua
-- MDK suicide dive — canon Drone.cs Death/ProcessCrashing (EnemyType.Mandalore):
-- после смерти рыцарь пикирует по прямой с разгоном 50 м/с² и roll-спином;
-- 0.5 c неуязвимого разгона, дальше любой урон или касание -> взрыв (циан,
-- 50 dmg, как у Mindflayer); авто-взрыв через 5 c. Панч ридиректит (home run).
-- Отдельная сущность (паттерн virtue_ragdoll_sphere) — без борьбы с DrGBase AI.

AddCSLuaFile()

if not UKMDK then include( "autorun/ultrakill_test_mdk_shared.lua" ) end

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "MDK Crash"
ENT.Spawnable = false

ENT.UKMDK_IsMDK = true

if SERVER then

  function ENT:Initialize()
    self:SetModel( UKMDK.MODEL )
    self:SetModelScale( UKMDK.SCALE )
    self:SetMoveType( MOVETYPE_NOCLIP )
    self:SetSolid( SOLID_BBOX )
    self:SetCollisionBounds( Vector( -30, -30, -30 ), Vector( 30, 30, 46 ) )
    self:DrawShadow( true )
    self:SetHealth( 2 ^ 30 )

    self.UKMDKCrash_Dir = self.UKMDKCrash_Dir or self:GetForward()
    self.UKMDKCrash_Speed = self.UKMDKCrash_Speed or 400
    self.UKMDKCrash_Spawned = CurTime()
    self.UKMDKCrash_LastThink = CurTime()

    self:SetNW2Int( "UKMDK_Tint", self.UKMDKCrash_Tint or 0 )

    -- canon: оба голоса играют Death одновременно (script = сабтитры +
    -- перебивание фазовых реплик по приоритету)
    local v = UKMDK.VOICE.death
    UltrakillBase.SoundScript( v.script, self:GetPos(), self )
    if v.secondary then
      self:EmitSound( v.secondary, 92, 100, 1, CHAN_VOICE2 )
    end

    -- canon Invoke("Explode", 5f)
    timer.Simple( UKMDK.CRASH_FUSE, function()
      if IsValid( self ) then self:UKMDKCrash_Explode() end
    end )
  end

  function ENT:Think()
    local now = CurTime()
    local dt = math.min( now - self.UKMDKCrash_LastThink, 0.1 )
    self.UKMDKCrash_LastThink = now

    -- canon ProcessCrashing: AddForce(forward * 50, Acceleration)
    self.UKMDKCrash_Speed = math.min(
      self.UKMDKCrash_Speed + UKMDK.CRASH_ACCEL * dt, UKMDK.CRASH_MAX_SPEED )

    local from = self:GetPos()
    local to = from + self.UKMDKCrash_Dir * self.UKMDKCrash_Speed * dt

    local tr = util.TraceHull( {
      start = from, endpos = to,
      mins = Vector( -30, -30, -30 ), maxs = Vector( 30, 30, 50 ),
      mask = MASK_SHOT,
      filter = function( ent )
        if ent == self then return false end
        if IsValid( ent ) and ( ent.UKMDK_IsMDK or ent.IsUltrakillProjectile ) then
          return false
        end
        return true
      end,
    } )

    if tr.Hit then
      self:SetPos( tr.HitPos )
      self:UKMDKCrash_Explode()
      return
    end
    self:SetPos( to )

    -- канонный roll-спин убран (фидбек юзера) — просто нос по курсу
    self:SetAngles( self.UKMDKCrash_Dir:Angle() )

    self:NextThink( now )
    return true
  end

  function ENT:OnTakeDamage( dmginfo )
    local attacker = dmginfo:GetAttacker()
    local hitter = IsValid( attacker ) and attacker.UltrakillBase_LastHitterTag or nil
    local melee = hitter == "punch" or hitter == "hammerzone"
              or dmginfo:IsDamageType( DMG_CLUB )

    -- canon parry (работает и в грейс-окне): redirect по направлению удара,
    -- velocity = forward * 40 м/с
    if melee and IsValid( attacker ) and attacker:IsPlayer() then
      self.UKMDKCrash_Dir = attacker:GetAimVector()
      self.UKMDKCrash_Speed = UKMDK.PARRY_REDIRECT_SPEED
      if UltrakillBase and UltrakillBase.SoundScript then
        UltrakillBase.SoundScript( "Ultrakill_Parry", self:GetPos() )
      end
      return
    end

    -- canon Invoke("CanInterruptCrash", 0.5f): полсекунды неуязвимого разгона
    if CurTime() < self.UKMDKCrash_Spawned + UKMDK.CRASH_GRACE then return end

    -- canon: любой другой урон >= 1 прерывает пике взрывом
    if dmginfo:GetDamage() >= 1 then self:UKMDKCrash_Explode() end
  end

  function ENT:UKMDKCrash_Explode()
    if self.UKMDKCrash_Exploded then return end
    self.UKMDKCrash_Exploded = true
    UKMDK.Explode( self, self:GetPos(), UKMDK.EXPLOSION_RADIUS, UKMDK.EXPLOSION_DAMAGE )
    self:Remove()
  end

end

if CLIENT then

  local SandMaterial = Material( "models/ultrakill/vfx/Sand" )

  function ENT:Draw()
    local tint = self:GetNW2Int( "UKMDK_Tint", 0 )
    if tint == 2 then
      -- Sanded: тот же материал, что у _BaseDraw базы
      render.MaterialOverride( SandMaterial )
      self:DrawModel()
      render.MaterialOverride()
    elseif tint == 1 then
      local t = UKMDK.TINT_ENRAGED
      render.SetColorModulation( t[1], t[2], t[3] )
      self:DrawModel()
      render.SetColorModulation( 1, 1, 1 )
    else
      -- пике: лёгкий циановый перегрев
      local pulse = 0.75 + 0.25 * math.sin( CurTime() * 20 )
      render.SetColorModulation( 0.7, 1.1 * pulse, 1.25 * pulse )
      self:DrawModel()
      render.SetColorModulation( 1, 1, 1 )
    end

    local dl = DynamicLight( self:EntIndex() )
    if dl then
      dl.pos = self:WorldSpaceCenter()
      dl.r, dl.g, dl.b = 60, 220, 255
      dl.brightness = 3
      dl.size = 220
      dl.decay = 1000
      dl.dietime = CurTime() + 0.1
    end
  end

end
