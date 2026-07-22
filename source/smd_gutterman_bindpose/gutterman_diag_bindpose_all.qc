$modelname "ultrakill_prelude_test/gutterman_diag_bindpose_all.mdl"
$upaxis Y
$scale 2500.0
$cdmaterials "models/ultrakill_prelude_test/gutterman/"
$surfaceprop "metal_bouncy"
$contents "solid"
$body "body" "gutterman_bindpose_body.smd"
$sequence Ref "gutterman_bindpose_body" loop fps 1
$sequence Idle "idle_abs" loop fps 30
$sequence Walk "walk_abs" loop fps 40.5
$sequence IdleShieldless "idleshieldless_abs" loop fps 30
$sequence WalkShieldless "walkshieldless_abs" loop fps 30
$sequence ShieldBreak "shieldbreak_abs" fps 30
$sequence ShieldBash "shieldbash_abs" fps 45
$sequence Smack "smack_abs" fps 37.5
$sequence Death "death_abs" fps 19.5
$sequence Shoot "shoot_abs" loop fps 60
