// Sentry (Turret) — canon overhaul 2026-07-03.
// SMD sources: sentry_bake_anims.py (Blender headless; ROOT_YAW Ry(+90) baked
// into SMD roots so file space is Y-up / forward=+X — gutterman recipe:
// $upaxis Y and NO $origin; the old '$origin 0 0 0 90' left the model side-on).
$modelname "ultrakill_prelude_test/sentry.mdl"
$upaxis Y
$scale 25.0
$body "body" "sentry_ref.smd"
$cdmaterials "models/ultrakill_prelude_test/"
$surfaceprop "metal_box"
$contents "solid"

// UnlitGeneric materials ignore lighting; garbage auto-illum (z~1939) came
// from the missing explicit value ($illumposition is multiplied by $scale).
$illumposition 0 0 0

// barrel_tip: beam/flash origin (Barrel base bone; Lua pushes forward along
// the attachment axis). antenna_tip: beep sparkle at the very top of the
// antenna. antenna: canon interrupt weakzone (mid-antenna). KEEP antenna
// LAST — ukcoin targets GetAttachment(#GetAttachments()) on interruptable NPCs.
$attachment "barrel_tip" "Barrel" 0 0 0
$attachment "head" "Head" 0 0 0
$attachment "antenna_tip" "Antena_04" 0 0 0
$attachment "antenna" "Antena_02" 0 0 0

$sequence Idle         "idle"         loop fps 30
$sequence Running      "running"      loop fps 30
$sequence AimStart     "aimstart"          fps 30
$sequence Aiming       "aiming"       loop fps 30
$sequence Shoot        "shoot"             fps 30
$sequence CancelAim    "cancelaim"         fps 30
$sequence Falling      "falling"      loop fps 30
$sequence InterruptAim "interruptaim"      fps 30
$sequence Kick         "kick"              fps 30

// Explicit hitboxes (antenna = hitgroup 9, generous boxes so revolver shots
// register) + jointed ragdoll collision for RagdollOnDeath. Values in RAW SMD
// units — studiomdl multiplies by $scale ($hbox x $scale trap).
$include "sentry_hbox_qc.txt"
