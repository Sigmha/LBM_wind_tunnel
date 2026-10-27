extends Node
class_name WingConfig

const NX := 1600
const NY := 800
const N := NX * NY
const U_IN := 0.06
const C := 160.0                 # corde (mailles)
const T_REL := 0.12              # épaisseur relative NACA 0012
const ALPHA_DEG := 5.0           # angle d'attaque (> 0 : bord d'attaque en haut)
const XP := 480.0                # pivot au quart de corde
const YP := 399.5                # (NY-1)/2 : plan de symétrie exact
const T_RAMP := 6000.0
const SCALE := 1
const PROBE_X := 900
const PROBE_Y := 400
const SAMPLE_EVERY := 5          # lire la sonde toutes les 5 frames physique
const THRESH := 1e-3             
const FORCE_SCALE := 100000.0
const STATS_FROM := 30000       # pas à partir duquel on moyenne (régime établi)
const LAMBDA := 3.0 / 16.0       # -1.0 => BGK (taum = tau), pour le test de régression
const ALPHA_RATE := 0.1         # degrés par frame quand une touche est enfoncée
const SETTLE := 20000            # pas d'attente après un changement d'angle avant de moyenner
const SMOKE_SPACING := 32        # écart entre filets (mailles)
const SMOKE_THICK := 4           # épaisseur d'un filet
const NU_AIR := 1.5e-5           # viscosité cinématique de l'air (m²/s)
const C_PHYS := 0.05             # corde physique (m)
const RE_MIN := 100.0
const RE_MAX := 1700.0
const RE_RATE := 0.003           # variation max de ln(Re) par frame
const SUBSTEPS_MIN := 4
const SUBSTEPS_MAX := 200
const MIN_FPS := 50.0
const ALPHA_PER_STEP := 0.002    # degrés par pas LBM (= 0,05 / 25 : même ω qu'avant)
