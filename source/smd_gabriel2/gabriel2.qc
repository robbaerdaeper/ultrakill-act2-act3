// Gabriel, Apostate of Hate (Gabriel 2nd, 6-2) — canon 1:1 port.
// SMD source: gabriel2_build_assets.py (prefab-skeleton bake, no Blender).
// Prefab: gameprefabs 'Gabriel 2nd'; model child gabrielRigged_Swords_Held
// (local scale 0.03) => 1 model unit = 0.03 m; $scale = 0.03 * 40 su/m = 1.2.
$modelname "ultrakill_prelude_test/gabriel2.mdl"
$upaxis Y
// mirror_X bake leaves the model facing +Z (ferryman-verified): yaw 0.
$origin 0 0 0 0
$scale 0.54 // 2026-07-10 workshop size report: rescaled to match Kevin-pack proportions (was 1.2)

$bodygroup "body" {
    studio "gabriel2_ref.smd"
}
// held blades: hidden while the combined swords are formed / in flight
// (canon GabrielSecond.Gattai / UnGattai toggles the sword renderers)
$bodygroup "swords" {
    studio "gabriel2_swords.smd"
    blank
}

$cdmaterials "models/ultrakill_prelude_test/gabriel2/"
$surfaceprop "metal"
$contents "solid"
// all materials UnlitGeneric; $illumposition is multiplied by $scale
$illumposition 0 0 0

// skin 0 = phase 1 (enraged red, canon spawn state); skin 1 = phase 2 normal
$texturegroup "skinfamilies" {
    { "gabriel2_body_rage" "gabriel2_wings_rage" }
    { "gabriel2_body"      "gabriel2_wings"      }
}

// "head" LAST: ukcoin ricochets target the last attachment
$attachment "chest"     "spine.002" 0 0 0
$attachment "lefthand"  "weaponbone.L" 0 0 0
$attachment "righthand" "weaponbone.R" 0 0 0
$attachment "head"      "head" 0 0 0

$sequence Idle                "gabriel2_idle" loop fps 30
$sequence BasicCombo          "gabriel2_basiccombo" fps 30
$sequence FastComboDash       "gabriel2_fastcombodash" fps 30
$sequence FastCombo           "gabriel2_fastcombo" fps 30
$sequence SwordsCombine       "gabriel2_swordscombine" fps 30
$sequence SwordsCombinedThrow "gabriel2_swordscombinedthrow" fps 30
$sequence Juggle              "gabriel2_juggle" fps 30
$sequence Enrage              "gabriel2_enrage" fps 30
$sequence ThrowCombo          "gabriel2_throwcombo" fps 30

$collisionmodel "gabriel2_phys.smd" {
}
