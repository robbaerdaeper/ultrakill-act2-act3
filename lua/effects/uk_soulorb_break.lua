-- Soul orb shatter (canon BonusParticle): the orb "shatters loudly into
-- multiple particles of its colour that linger close to where the orb was".
-- Colour rides in via EffectData:SetStart as an RGB vector.

function EFFECT:Init(data)
    local pos = data:GetOrigin()
    local col = data:GetStart()
    local r, g, b = col.x, col.y, col.z

    local emitter = ParticleEmitter(pos, false)
    if not emitter then return end

    -- soul wisps: slow, draggy, lingering
    for i = 1, 22 do
        local p = emitter:Add("sprites/light_glow02_add", pos + VectorRand() * 4)
        if p then
            p:SetVelocity(VectorRand() * math.Rand(40, 130) + Vector(0, 0, math.Rand(10, 50)))
            p:SetAirResistance(120)
            p:SetGravity(Vector(0, 0, -40))
            p:SetDieTime(math.Rand(0.8, 1.7))
            p:SetStartAlpha(230)
            p:SetEndAlpha(0)
            p:SetStartSize(math.Rand(5, 10))
            p:SetEndSize(0)
            p:SetColor(r, g, b)
            p:SetLighting(false)
        end
    end

    -- bright core burst
    for i = 1, 5 do
        local p = emitter:Add("sprites/light_glow02_add", pos)
        if p then
            p:SetVelocity(VectorRand() * math.Rand(10, 40))
            p:SetAirResistance(80)
            p:SetGravity(vector_origin)
            p:SetDieTime(math.Rand(0.25, 0.5))
            p:SetStartAlpha(255)
            p:SetEndAlpha(0)
            p:SetStartSize(math.Rand(18, 30))
            p:SetEndSize(2)
            p:SetColor(255, 255, 255)
            p:SetLighting(false)
        end
    end

    emitter:Finish()
end

function EFFECT:Think()
    return false
end

function EFFECT:Render()
end
