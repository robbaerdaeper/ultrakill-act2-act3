if not CLIENT then return end

local sandMat = Material( "effects/uktest_sand" )

-- One scrolling-sand additive pass over the entity model.
-- Called by the unified status_layering coordinator. Does NOT install its own hook.
function UKSand.RenderSandLayer( ent )
  if not IsValid( ent ) then return end
  render.MaterialOverride( sandMat )
  ent:DrawModel()
  render.MaterialOverride( nil )
end
