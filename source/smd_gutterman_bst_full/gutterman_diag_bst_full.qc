$modelname "ultrakill_prelude_test/gutterman_diag_bst_full.mdl"
$scale 25.0
$cdmaterials "models/ultrakill_prelude_test/gutterman/"
$surfaceprop "metal_bouncy"
$contents "solid"
$body "body" "Gutterman.002.smd"
$body "shield" "Shield.001.smd"
$body "casket_door" "Casket_Door.smd"
$sequence Ref "Gutterman.002.smd" loop fps 1
$sequence Idle "anims/Idle" loop fps 30
$sequence Walk "anims/Walk" loop fps 30
