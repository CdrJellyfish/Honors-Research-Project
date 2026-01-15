extensions [csv table string]

breed [bacteria bacterium]
breed [sources source]

globals [
  ; --- Data Tables ---
  bacteria-data-table chemical-data-table obstacle-data-table environment-data-table

  ; --- Active Simulation Elements ---
  active-chemicals active-bacteria active-obstacles
  background-color-rgb

  ; --- Environment Properties ---
  environment-names env-ph env-temperature env-oxygen env-salinity env-viscosity env-flow-rate
  env-nutrient-availability env-microbial-diversity env-biofilm-zones?

  total-deaths

  ; --- Scaling & Simulation Parameters ---
  tick-duration-s

  ; --- Cached Properties for Performance ---
  chemical-properties-table

  ; --- Lists for Setup ---
  chemical-names bacteria-species obstacle-types

  ; --- Death Counters ---
  deaths-by-starvation deaths-by-old-age deaths-by-toxin

  ; --- Model Constants ---
  energy-cost-normal energy-cost-biofilm energy-cost-produce-ai2 energy-cost-produce-toxin
  consumption-rate-normal consumption-rate-biofilm toxin-uptake-rate-normal toxin-uptake-rate-biofilm
  biofilm-conversion-factor toxin-neutralization-rate reproduction-energy-threshold
]

patches-own [
  ; --- Core Environment Properties ---
  nutrient_lvl biofilm-mass
  base-r base-g base-b

  ; --- Obstacle Properties ---
  obstacle-here? obstacle-type obstacle-permeability obstacle-toxicity?

  ; --- NEW: Specific Chemical Concentrations ---
  glucose-conc aspartate-conc phenol-conc butanol-conc ai-2-conc polymyxin-b-conc

  ; --- Potentials for Chemotaxis (Unchanged) ---
  attractant-potential repellent-potential
  glucose-potential aspartate-potential phenol-potential
  butanol-potential ai-2-potential polymyxin-b-potential
]

turtles-own [
  ; Bacterial properties (Unchanged)
  bacteria-type motility-type flagella-arrangement speed-um-s run-duration-s
  tumble-duration-s taxis-sensitivity attractants repellents energy age-min
  lifespan-min division-rate stress-tolerance mutation-rate biofilm-forming?
  swarming-behavior? size-um base-color energy-source produces gram-stain
  chemotaxis-on?
  reason-for-death

  ; Properties for toxin model (Unchanged)
  preferred-ph
  ph-performance-modifier
  toxin-level
  toxin-threshold

  ; Current state (Unchanged)
  state state-timer last-nutrient-intake in-biofilm?
]

sources-own [
  chemical-type
  source-conc
  source-radius
]

to load-files
  set bacteria-data-table table:make
  set chemical-data-table table:make
  set obstacle-data-table table:make
  set environment-data-table table:make

  set bacteria-species []
  set chemical-names []
  set obstacle-types []
  set environment-names []

  foreach (but-first csv:from-file "bacteria.csv") [ [row] ->
    let name item 0 row
    table:put bacteria-data-table name row
    set bacteria-species lput name bacteria-species
  ]
  foreach (but-first csv:from-file "chemicals.csv") [ [row] ->
    let name item 0 row
    table:put chemical-data-table name row
    set chemical-names lput name chemical-names
  ]
  if file-exists? "obstacles.csv" [
    foreach (but-first csv:from-file "obstacles.csv") [ [row] ->
      let name item 0 row
      table:put obstacle-data-table name row
      set obstacle-types lput name obstacle-types
    ]
  ]
  foreach (but-first csv:from-file "environments.csv") [ [row] ->
    let name item 0 row
    table:put environment-data-table name row
    set environment-names lput name environment-names
  ]

  print "All CSV files have been loaded."
  print "---------------------------------"
  print "--- Bacteria Data Table ---"
  print  bacteria-data-table
  print "--- Chemical Data Table ---"
  print  chemical-data-table
  print "--- Obstacle Data Table ---"
  print  obstacle-data-table
  print "--- Environment Data Table ---"
  print  environment-data-table
end

to print-loaded-environments
  clear-output
  print "--- LOADED SIMULATION DATA ---"
  let environment-headers ["Name" "Description" "pH" "Temperature-C" "Oxygen Level" "Salinity" "Viscosity" "Flow Rate-um-s" "Nutrient Availability" "Microbial Diversity" "Biofilm Zones?"]
  print "\n~~~~~~~~~~~~~~~~~~~~~~~~~~"
  print "     ENVIRONMENTS DATA"
  print "~~~~~~~~~~~~~~~~~~~~~~~~~~"
  foreach (sort (table:keys environment-data-table)) [ key ->
    print-record key (table:get environment-data-table key) environment-headers
  ]
end

to print-loaded-bacterias
  clear-output
  print "--- LOADED SIMULATION DATA ---"
  let bacteria-headers ["Species" "Motility Type" "Flagella Arrangement" "Speed" "Run Duration" "Tumble Duration" "Taxis Sensitivity" "Preferred Attractants" "Repelled By" "Receptor Types" "Energy Source" "Lifespan" "Division Rate" "Stress Tolerance" "Mutation Rate" "Biofilm Forming" "Swarming Behavior" "Preferred pH" "Size-um" "Chemicals Produced" "Color" "Gram Stain"]
   print "\n~~~~~~~~~~~~~~~~~~~~~~~~~~"
  print "     BACTERIA DATA"
  print "~~~~~~~~~~~~~~~~~~~~~~~~~~"
  foreach (sort (table:keys bacteria-data-table)) [ key ->
    print-record key (table:get bacteria-data-table key) bacteria-headers
  ]
end

to print-loaded-chemicals
  clear-output
  print "--- LOADED SIMULATION DATA ---"
  let chemical-headers ["Name" "Type" "Diffusion Rate" "Decay Rate" "Toxicity" "Effective Range" "Source" "Metabolizable" "Signal Role" "pH Sensitivity" "Concentration Threshold" "Charge" "Hydrophobicity" "Color" "Target Gram Type"]
  print "\n~~~~~~~~~~~~~~~~~~~~~~~~~~"
  print "     CHEMICALS DATA"
  print "~~~~~~~~~~~~~~~~~~~~~~~~~~"
  foreach (sort (table:keys chemical-data-table)) [ key ->
    print-record key (table:get chemical-data-table key) chemical-headers
  ]
end


to print-loaded-obstacles
  clear-output
  print "--- LOADED SIMULATION DATA ---"
   let obstacle-headers ["Type" "Shape" "Size-um" "Permeability" "Surface Adhesion" "Reflectivity" "Decay Over Time?" "Toxicity Zone?" "Mechanical Pressure" "Dynamic?" "Interactivity?" "Color"]
  print "\n~~~~~~~~~~~~~~~~~~~~~~~~~~"
  print "     OBSTACLES DATA"
  print "~~~~~~~~~~~~~~~~~~~~~~~~~~"
    foreach (sort (table:keys obstacle-data-table)) [ key ->
      print-record key (table:get obstacle-data-table key) obstacle-headers
    ]
end

to print-record [record-key data-row headers-list]
  print (word "\n--- " record-key " ---")
  foreach (range 1 (length headers-list)) [ i ->
    let header item i headers-list
    let value item i data-row
    let padding "                           "
    let padded-header (word header ":")
    set padded-header substring (word padded-header padding) 0 27
    print (word "  " padded-header value)
  ]
end

to setup
  let new-max-pxcor floor (world-width-setting / 2)
  let new-max-pycor floor (world-height-setting / 2)
  resize-world (- new-max-pxcor) new-max-pxcor (- new-max-pycor) new-max-pycor

  clear-turtles
  clear-patches
  reset-ticks
  set energy-cost-normal 1
  set energy-cost-biofilm 0.1
  set energy-cost-produce-ai2 2
  set energy-cost-produce-toxin 2
  set consumption-rate-normal 3
  set consumption-rate-biofilm 0.5
  set toxin-uptake-rate-normal 1
  set toxin-uptake-rate-biofilm 0.5
  set biofilm-conversion-factor 0.5
  set toxin-neutralization-rate 0.3
  set reproduction-energy-threshold 70
  set tick-duration-s 0.1
  set total-deaths 0
  clear-all-plots

  if not is-list? bacteria-species or empty? bacteria-species [
    print "Error: Data not loaded. Please press 'load-files' first."
    stop
  ]

  ; Create the chemical properties cache for efficiency
  set chemical-properties-table table:make
  foreach (table:keys chemical-data-table) [ chem-name ->
    let chem-data table:get chemical-data-table chem-name
    let properties table:make

    ; --- THIS IS THE CORRECTED LOGIC ---
    ; It now checks for "yes" OR "true", ignoring case and spaces.
    let metabolizable-text (item 7 chem-data)
    table:put properties "is-metabolizable" (metabolizable-text = "Yes" or metabolizable-text = "True")

    table:put properties "toxicity" (item 4 chem-data)
    table:put properties "target-gram" (item 14 chem-data)
    let color-name item 13 chem-data
    table:put properties "rgb-color" extract-rgb (read-from-string color-name)
    table:put chemical-properties-table chem-name properties
  ]

  setup-environment-by-name enviroment-chosen
  setup-bacteria-by-choice
  setup-chemicals-by-choice
  setup-obstacles-by-choice

  update-trackers
  update-visualization
  reset-ticks
end

to setup-environment-by-name [env-name]
  if not table:has-key? environment-data-table env-name [
    print (word "Error: Env '" env-name "' not found.") stop
  ]

  let env-row table:get environment-data-table env-name

  ; --- THIS IS THE CORRECTED LINE ---
  set env-ph (safe-read-from-string (item 2 env-row))

  set env-temperature (safe-read-from-string (item 3 env-row)) ; (You already had this one right)
  set env-oxygen (item 4 env-row)
  set env-nutrient-availability (item 8 env-row)
  let env-viscosity-str (item 6 env-row)

  let nutrient-value 0
  if env-nutrient-availability = "Abundant" [ set nutrient-value 100 ]
  if env-nutrient-availability = "Moderate" [ set nutrient-value 50 ]
  if env-nutrient-availability = "Scarce" [ set nutrient-value 10 ]

  if env-viscosity-str = "High" [ set env-viscosity 0.25 ]
  if env-viscosity-str = "Moderate" [ set env-viscosity 0.5 ]
  if env-viscosity-str = "Low" [ set env-viscosity 1.0 ]

  set background-color-rgb [255 255 204]

  ask patches [
    set obstacle-here? false
    set nutrient_lvl nutrient-value
    set base-r item 0 background-color-rgb
    set base-g item 1 background-color-rgb
    set base-b item 2 background-color-rgb
    let factor (nutrient_lvl / 100)
    let r (base-r * factor) + (255 * (1 - factor))
    let g (base-g * factor) + (255 * (1 - factor))
    let b (base-b * factor) + (255 * (1 - factor))
    set pcolor rgb r g b
  ]
end

to setup-chemicals-by-choice
  ; REVISED: Clear all specific concentration variables
  ask patches [
    set glucose-conc 0
    set aspartate-conc 0
    set phenol-conc 0
    set butanol-conc 0
    set ai-2-conc 0
    set polymyxin-b-conc 0
  ]

  ; REVISED: Build a list of active chemicals for efficient looping later
  set active-chemicals []
  if Glucose? [
    create-chemical-zones-for "Glucose" Glucose-sources Glucose-zone
    set active-chemicals lput "Glucose" active-chemicals
  ]
  if Aspartate? [
    create-chemical-zones-for "Aspartate" Aspartate-sources Aspartate-zone
    set active-chemicals lput "Aspartate" active-chemicals
  ]
  if Phenol? [
    create-chemical-zones-for "Phenol" Phenol-sources Phenol-zone
    set active-chemicals lput "Phenol" active-chemicals
  ]
  if Butanol? [
    create-chemical-zones-for "Butanol" Butanol-sources Butanol-zone
    set active-chemicals lput "Butanol" active-chemicals
  ]
  if Autoinducer-2? [
    create-chemical-zones-for "Autoinducer-2" Autoinducer-2-sources Autoinducer-2-zone
    set active-chemicals lput "Autoinducer-2" active-chemicals
  ]
  ; Also add chemicals that are produced by bacteria, so they are visualized correctly
  if any? bacteria with [ member? "Polymyxin B" produces ] [
     if not member? "Polymyxin B" active-chemicals [
       set active-chemicals lput "Polymyxin B" active-chemicals
     ]
  ]
   if any? bacteria with [ member? "Autoinducer-2" produces ] [
     if not member? "Autoinducer-2" active-chemicals [
       set active-chemicals lput "Autoinducer-2" active-chemicals
     ]
  ]
end

to create-chemical-zones-for [chem-name num-zones chosen-zone]
  ; REVISED: This now updates the specific concentration variable for the given chemical.
  if num-zones > 0 [
    repeat num-zones [
      let coords get-random-coords-in-zone chosen-zone
      let center-x item 0 coords
      let center-y item 1 coords
      let radius (world-width / 20) + random-float (world-width / 20)
      let max-conc 100

      ask patches with [distancexy center-x center-y < radius] [
        let d distancexy center-x center-y
        let falloff (1 - (d / radius))
        let added-conc (max-conc * falloff)

        if chem-name = "Glucose"       [ set glucose-conc (glucose-conc + added-conc) ]
        if chem-name = "Aspartate"     [ set aspartate-conc (aspartate-conc + added-conc) ]
        if chem-name = "Phenol"        [ set phenol-conc (phenol-conc + added-conc) ]
        if chem-name = "Butanol"       [ set butanol-conc (butanol-conc + added-conc) ]
        if chem-name = "Autoinducer-2" [ set ai-2-conc (ai-2-conc + added-conc) ]
      ]
    ]
  ]
end

to setup-bacteria-by-choice
  set active-bacteria []
  if Vibrio-cholerae? [
    set active-bacteria lput "Vibrio cholerae" active-bacteria
    create-n-bacteria "Vibrio cholerae" Vibrio-cholerae-num Vibrio-cholerae-zone
  ]
  if Bacillus-subtilis? [
    set active-bacteria lput "Bacillus subtilis" active-bacteria
    create-n-bacteria "Bacillus subtilis" Bacillus-subtilis-num Bacillus-subtilis-zone
  ]
  if Escherichia-coli? [
    set active-bacteria lput "Escherichia coli" active-bacteria
    create-n-bacteria "Escherichia coli" Escherichia-coli-num Escherichia-coli-zone
  ]
  if Pseudomonas-aeruginosa? [
    set active-bacteria lput "Pseudomonas aeruginosa" active-bacteria
    create-n-bacteria "Pseudomonas aeruginosa" Pseudomonas-aeruginosa-num Pseudomonas-aeruginosa-zone
  ]
  if Salmonella-enterica? [
    set active-bacteria lput "Salmonella enterica" active-bacteria
    create-n-bacteria "Salmonella enterica" Salmonella-enterica-num Salmonella-enterica-zone
  ]
  if Paenibacillus-polymyxa? [
    set active-bacteria lput "Paenibacillus polymyxa" active-bacteria
    create-n-bacteria "Paenibacillus polymyxa" Paenibacillus-polymyxa-num Paenibacillus-polymyxa-zone
  ]
  if Burkholderia-cenocepacia? [
    set active-bacteria lput "Burkholderia cenocepacia" active-bacteria
    create-n-bacteria "Burkholderia cenocepacia" Burkholderia-cenocepacia-num Burkholderia-cenocepacia-zone
  ]
end

to create-n-bacteria [name num chosen-zone]
  create-bacteria num [
    let b-data table:get bacteria-data-table name
    set bacteria-type name
    ifelse chemotaxis-enabled? [
      ifelse
        (name = "Escherichia coli" and E-coli-chemotaxis?) or
        (name = "Vibrio cholerae" and V-cholerae-chemotaxis?) or
        (name = "Bacillus subtilis" and B-subtilis-chemotaxis?) or
        (name = "Pseudomonas aeruginosa" and P-aeruginosa-chemotaxis?) or
        (name = "Salmonella enterica" and S-enterica-chemotaxis?) or
        (name = "Paenibacillus polymyxa" and P-polymyxa-chemotaxis?) or
        (name = "Burkholderia cenocepacia" and B-cenocepacia-chemotaxis?)
      [ set chemotaxis-on? true ]
      [ set chemotaxis-on? false ]
    ]
    [ set chemotaxis-on? false ]

    set attractants csv:from-row (item 7 b-data)
    set repellents csv:from-row (item 8 b-data)
    set speed-um-s parse-value (item 3 b-data)
    set run-duration-s parse-value (item 4 b-data)
    set tumble-duration-s parse-value (item 5 b-data)
    set taxis-sensitivity parse-value (item 6 b-data)
    set energy-source (item 10 b-data)
    set lifespan-min parse-value (item 11 b-data)
    set division-rate parse-value (item 12 b-data)
    set stress-tolerance item 13 b-data
    set biofilm-forming? (item 15 b-data)
    set swarming-behavior? (item 16 b-data)
    set preferred-ph safe-read-from-string (item 17 b-data)
    set size-um parse-value (item 18 b-data)
    set produces csv:from-row (item 19 b-data)
    set base-color read-from-string (item 20 b-data)
    set gram-stain (item 21 b-data)
    set color base-color
    set energy 100
    set age-min random-float division-rate
    set toxin-level 0
    ifelse stress-tolerance = "Extreme" [ set toxin-threshold 100 ] [
      ifelse stress-tolerance = "High" [ set toxin-threshold 75 ] [
        set toxin-threshold 50
      ]
    ]
    let ph-difference abs (env-ph - preferred-ph)
    let ph-impact (ph-difference * 0.2) ; Each pH unit away from optimal reduces performance by 20%

    if stress-tolerance = "High" [ set ph-impact (ph-impact * 0.5) ] ; 50% reduction in penalty
    if stress-tolerance = "Extreme" [ set ph-impact (ph-impact * 0.25) ] ; 75% reduction in penalty
    ; The final modifier is between 0 (total shutdown) and 1 (perfect performance)
    set ph-performance-modifier max (list 0 (1 - ph-impact))

    set state "running"
    set state-timer run-duration-s / tick-duration-s
    set in-biofilm? false

    ifelse bacteria-size-scale? [
      set size (size-um / patch-scale-um)
    ] [ set size 1 ]
    set shape "circle"

    let coords get-random-coords-in-zone chosen-zone
    setxy item 0 coords item 1 coords
  ]
end

to setup-obstacles-by-choice
  if Agar-Wall? [ create-n-obstacles "Agar Wall" Agar-Wall-num Agar-Wall-zone ]
  if Polystyrene-Bead? [ create-n-obstacles "Polystyrene Bead" Polystyrene-Bead-num Polystyrene-Bead-zone ]
  if Necrotic-Tissue? [ create-n-obstacles "Necrotic Tissue" Necrotic-Tissue-num Necrotic-Tissue-zone ]
  if Oil-Droplet? [ create-n-obstacles "Oil Droplet" Oil-Droplet-num Oil-Droplet-zone ]
  if Metal-Oxide-NP? [ create-n-obstacles "Metal Oxide NP" Metal-Oxide-NP-num Metal-Oxide-NP-zone ]
end

to create-n-obstacles [obs-name num-zones chosen-zone]
  if num-zones > 0 and table:has-key? obstacle-data-table obs-name [
    let obs-data table:get obstacle-data-table obs-name
    let obs-size parse-value (item 2 obs-data)
    let obs-perm-str item 3 obs-data
    let is-toxic (item 7 obs-data = "Yes")
    let obs-color-name item 11 obs-data
    let base-rgb extract-rgb (read-from-string obs-color-name)
    let perm-value 0
    if obs-perm-str = "Low" [ set perm-value 0.2 ]    if obs-perm-str = "Moderate" [ set perm-value 0.5 ]
    if obs-perm-str = "High" [ set perm-value 0.8 ]
    repeat num-zones [
      let coords get-random-coords-in-zone chosen-zone
      let center-x item 0 coords
      let center-y item 1 coords
      let radius (obs-size / patch-scale-um / 2)
      ask patches with [distancexy center-x center-y < radius] [
        set obstacle-here? true
        set obstacle-type obs-name
        set obstacle-toxicity? is-toxic
        set obstacle-permeability perm-value
        let opacity (1 - obstacle-permeability) * 255
        set pcolor (list (item 0 base-rgb) (item 1 base-rgb) (item 2 base-rgb) opacity)
      ]
    ]
  ]
end

;----------------------------------------------------------
; Main Simulation Procedures
;----------------------------------------------------------

to go
  if (ticks > 0 and ticks mod 500 = 0) [ export-view (word "chemotaxis-sim-" ticks ".png") ]

  produce-chemicals


  ask bacteria [
    if state != "dying" [
      set age-min age-min + (tick-duration-s / 10)
      let cost ifelse-value in-biofilm? [energy-cost-biofilm] [energy-cost-normal]
      set energy energy - (cost * tick-duration-s)

      interact-with-environment

      if biofilm-forming? and not in-biofilm? and energy < 30 and state != "seeking-biofilm" [
        set state "seeking-biofilm"
      ]

      if state = "running" [ run-behavior ]
      if state = "tumbling" [ tumble-behavior ]
      if state = "seeking-biofilm" [ seek-biofilm-behavior ]

      if in-biofilm? and [biofilm-mass] of patch-here > 200 and random-float 1 < 0.01 [
        set in-biofilm? false
        set state "running"
        set energy 50
        let other-biofilm-members-here other bacteria-here with [in-biofilm?]
        ask patch-here [
          ifelse not any? other-biofilm-members-here [
            set biofilm-mass 0
          ] [
            set biofilm-mass max (list 0 (biofilm-mass - 50))
          ]
        ]
      ]

      if (age-min >= division-rate) and (energy > reproduction-energy-threshold) [
        reproduce
      ]
      check-for-death
    ]
  ]

  ask bacteria with [state = "dying"] [
    set total-deaths total-deaths + 1
    if reason-for-death = "starvation" [ set deaths-by-starvation deaths-by-starvation + 1 ]
    if reason-for-death = "old-age" [ set deaths-by-old-age deaths-by-old-age + 1 ]
    if reason-for-death = "toxin" [ set deaths-by-toxin deaths-by-toxin + 1 ]
    die
  ]

  update-trackers
  update-visualization
   update-chemical-potentials
  if any? turtles [ tick ]
end

to produce-chemicals
  ; REVISED: Updates the specific concentration for Autoinducer-2
  ask bacteria with [state = "seeking-biofilm" and member? "Autoinducer-2" produces] [
    set energy energy - energy-cost-produce-ai2
    ask patch-here [
      set ai-2-conc min (list 100 (ai-2-conc + 10))
    ]
  ]

  ; REVISED: Updates the specific concentration for Polymyxin B
  ask bacteria with [member? "Polymyxin B" produces] [
    let producers-nearby other bacteria with [member? "Polymyxin B" produces] in-radius 3
    let competitors-nearby other bacteria with [not member? "Polymyxin B" produces] in-radius 3
    if (count producers-nearby > 4) and (any? competitors-nearby) and (energy > 80) [
      set energy energy - energy-cost-produce-toxin
      ask patch-here [
        set polymyxin-b-conc min (list 100 (polymyxin-b-conc + 10))
      ]
    ]
  ]
end

to check-for-death
  if state = "dying" [ stop ]
  if energy <= 0 [
    set state "dying"
    set reason-for-death "starvation"
    stop
  ]
  if age-min > lifespan-min [
    set state "dying"
    set reason-for-death "old-age"
    stop
  ]
  if toxin-level >= toxin-threshold [
    set state "dying"
    set reason-for-death "toxin"
    stop
  ]
end

to reproduce
  set age-min 0
  hatch 1 [
    set state "running"
    set state-timer run-duration-s / tick-duration-s
    rt random 360
  ]
end

to update-visualization
  ; Blends colors of multiple chemicals on each patch.
  ask patches [
    ; Only update the color of patches that are NOT obstacles.
    if not obstacle-here? [
      ; Start with the base nutrient color
      let max-nutrient 100
      let capped-nutrient min (list nutrient_lvl max-nutrient)
      let factor (capped-nutrient / max-nutrient)
      let final-r (base-r * factor) + (255 * (1 - factor))
      let final-g (base-g * factor) + (255 * (1 - factor))
      let final-b (base-b * factor) + (255 * (1 - factor))

      ; Blend in colors of all active chemicals
      foreach active-chemicals [ chem ->
          let chem-conc 0
          if chem = "Glucose"       [ set chem-conc glucose-conc ]
          if chem = "Aspartate"     [ set chem-conc aspartate-conc ]
          if chem = "Phenol"        [ set chem-conc phenol-conc ]
          if chem = "Butanol"       [ set chem-conc butanol-conc ]
          if chem = "Autoinducer-2" [ set chem-conc ai-2-conc ]
          if chem = "Polymyxin B"   [ set chem-conc polymyxin-b-conc ]

          if chem-conc > 0.1 [
            let props table:get chemical-properties-table chem
            let chem-rgb table:get props "rgb-color"
            let blend-factor (min (list chem-conc 100) / 100) * 0.7
            set final-r (final-r * (1 - blend-factor)) + ((item 0 chem-rgb) * blend-factor)
            set final-g (final-g * (1 - blend-factor)) + ((item 1 chem-rgb) * blend-factor)
            set final-b (final-b * (1 - blend-factor)) + ((item 2 chem-rgb) * blend-factor)
          ]
      ]
      ; The set pcolor command is now correctly INSIDE the if-statement
      set pcolor rgb final-r final-g final-b
    ]
  ]

  ; Bacteria health and biofilm status visualization (Unchanged)
  ask bacteria [
    if state != "dying" [
      ifelse in-biofilm?
        [ set color (scale-color base-color 0.8 0 1) ]
        [ let energy-factor (energy / 100)
          let toxin-factor (1 - (min (list toxin-level toxin-threshold) / toxin-threshold))
          let health-factor (energy-factor * toxin-factor)
          set color my-blend-colors black base-color health-factor ]
    ]
  ]

  ; Bacteria glow effect (Unchanged)
  if bacteria-size-scale? [
    ask patches with [any? bacteria-here] [
      let current-rgb pcolor
      let bacteria-colors [color] of bacteria-here
      let avg-r mean (map [c -> item 0 (ensure-rgb-list c)] bacteria-colors)
      let avg-g mean (map [c -> item 1 (ensure-rgb-list c)] bacteria-colors)
      let avg-b mean (map [c -> item 2 (ensure-rgb-list c)] bacteria-colors)
      let glow-rgb (list avg-r avg-g avg-b)
      let density count bacteria-here
      let max-density 15
      let capped-density min (list density max-density)
      let glow-factor (capped-density / max-density)
      let final-r ((item 0 current-rgb) * (1 - glow-factor)) + ((item 0 glow-rgb) * glow-factor)
      let final-g ((item 1 current-rgb) * (1 - glow-factor)) + ((item 1 glow-rgb) * glow-factor)
      let final-b ((item 2 current-rgb) * (1 - glow-factor)) + ((item 2 glow-rgb) * glow-factor)
      set pcolor rgb final-r final-g final-b
    ]
  ]
end

to update-chemical-potentials
  ; This bonus value is added to any patch with a real chemical source.
  ; It's set high to guarantee that a patch with concentration > 0 is always
  ; more attractive than an empty patch with only a diffused "ghost scent".
  let reality-bonus 100

  ;; Step 1: Set the base potential directly from the current concentrations.
  ask patches [
    set glucose-potential glucose-conc
    set aspartate-potential aspartate-conc
    set phenol-potential phenol-conc
    set butanol-potential butanol-conc
    set ai-2-potential (ai-2-potential * 0.95 + ai-2-conc)
    set polymyxin-b-potential (polymyxin-b-potential * 0.95 + polymyxin-b-conc)
  ]

  ;; Step 2: Diffuse the potentials to create the scent gradients.
  ;; Reducing the repeat count makes the scent more localized and disappear faster.
  repeat 5 [
    diffuse glucose-potential 0.9
    diffuse aspartate-potential 0.9
    diffuse phenol-potential 0.9
    diffuse butanol-potential 0.9
    diffuse ai-2-potential 0.9
    diffuse polymyxin-b-potential 0.8
  ]

  ;; Step 3: Add the "Reality Bonus".
  ;; This is the key step that solves the "potential well" problem.
  ask patches [
    if glucose-conc > 0.1 [ set glucose-potential (glucose-potential + reality-bonus) ]
    if aspartate-conc > 0.1 [ set aspartate-potential (aspartate-potential + reality-bonus) ]
    ; Note: We don't add a bonus to repellents.
  ]
end
to interact-with-environment
  let p patch-here
  let base-consumption-rate ifelse-value in-biofilm? [consumption-rate-biofilm] [consumption-rate-normal]
  let current-consumption-rate (base-consumption-rate * ph-performance-modifier) ; Apply pH effect

  let current-toxin-uptake-rate ifelse-value in-biofilm? [toxin-uptake-rate-biofilm] [toxin-uptake-rate-normal]
  let oxygen-modifier ifelse-value (energy-source = "Aerobic" and env-oxygen != "Aerobic") [0.1] [1.0]

  ;; --- 1. GAIN ENERGY & CONSUME NUTRIENTS ---
  let consumption 0
  if [nutrient_lvl] of p > 0 [
    set consumption min (list (current-consumption-rate * tick-duration-s) [nutrient_lvl] of p)
    set energy min (list 100 (energy + (consumption * oxygen-modifier)))
    if in-biofilm? [ ask p [ set biofilm-mass biofilm-mass + (consumption * biofilm-conversion-factor) ] ]
    ask p [ set nutrient_lvl nutrient_lvl - consumption ]
  ]

  ;; --- 2. DEPLETE "FLAVOR" CHEMICALS ---
  if consumption > 0 [
    let metabolizable-chemicals-here []
    if [glucose-conc] of p > 0 [ set metabolizable-chemicals-here lput "Glucose" metabolizable-chemicals-here ]
    if [aspartate-conc] of p > 0 [ set metabolizable-chemicals-here lput "Aspartate" metabolizable-chemicals-here ]

    let num-metabolizable length metabolizable-chemicals-here
    if num-metabolizable > 0 [
      let reduction-per-chemical (consumption / num-metabolizable)
      ask p [
        if member? "Glucose" metabolizable-chemicals-here [
          let amount-to-reduce min (list glucose-conc reduction-per-chemical)
          set glucose-conc (glucose-conc - amount-to-reduce)
          set glucose-potential (glucose-potential - amount-to-reduce)
        ]
        if member? "Aspartate" metabolizable-chemicals-here [
           let amount-to-reduce min (list aspartate-conc reduction-per-chemical)
           set aspartate-conc (aspartate-conc - amount-to-reduce)
           set aspartate-potential (aspartate-potential - amount-to-reduce)
        ]
      ]
    ]
  ]

  ;; --- 3. HANDLE TOXINS ---
 foreach active-chemicals [ chem ->
    let props table:get chemical-properties-table chem
    let toxicity-type table:get props "toxicity"
    if toxicity-type != "None" [
      let target-gram-type table:get props "target-gram"
      let is-susceptible (target-gram-type = "Both" or target-gram-type = gram-stain)
      if member? chem produces [ set is-susceptible false ]
      if is-susceptible [
        let patch-conc 0
        if chem = "Phenol" [ set patch-conc [phenol-conc] of p ]
        if chem = "Butanol" [ set patch-conc [butanol-conc] of p ]
        if chem = "Polymyxin B" [ set patch-conc [polymyxin-b-conc] of p ]

        if patch-conc > 0 [
          ;; --- NEW: Define multiplier based on CSV data ---
          let toxicity-multiplier 1.0 ; Default for "Moderate"
          if toxicity-type = "High" [ set toxicity-multiplier 1.5 ]
          if toxicity-type = "Extreme" [ set toxicity-multiplier 2.5 ]

          ;; --- UPDATED: Apply the multiplier to toxin uptake ---
          set toxin-level toxin-level + (current-toxin-uptake-rate * tick-duration-s * toxicity-multiplier)

          ask p [
            let neutralized-amount (toxin-neutralization-rate * tick-duration-s)
            if chem = "Phenol" [ set phenol-conc max (list 0 (phenol-conc - neutralized-amount)) ]
            if chem = "Butanol" [ set butanol-conc max (list 0 (butanol-conc - neutralized-amount)) ]
            if chem = "Polymyxin B" [ set polymyxin-b-conc max (list 0 (polymyxin-b-conc - neutralized-amount)) ]
          ]
        ]
      ]
    ]
  ]
  if [obstacle-here?] of p and [obstacle-toxicity?] of p [
    set toxin-level toxin-level + (current-toxin-uptake-rate * tick-duration-s)
  ]
end

to seek-biofilm-behavior
  let nearby-targets (other bacteria with [in-biofilm? or state = "seeking-biofilm"]) in-radius 5
  ifelse any? nearby-targets [
    let target min-one-of nearby-targets [distance myself]
    face target
    fd 0.5
    if any? other bacteria-here with [in-biofilm?] or state = "seeking-biofilm" [
      set in-biofilm? true
      set state "in-biofilm"
    ]
  ]
  [
    let target-heading calculate-best-tumble-direction
    let turn-angle (subtract-headings target-heading heading)
    rt (turn-angle * 0.5) + (random 90 - 45)
    let speed-modifier env-viscosity
    if [obstacle-here?] of patch-here [
      set speed-modifier (speed-modifier * obstacle-permeability)
    ]
    let step-length ((speed-um-s * speed-modifier) / patch-scale-um)
    fd step-length
  ]
end

to run-behavior
  let speed-modifier (env-viscosity * ph-performance-modifier)
  if [obstacle-here?] of patch-here [
    set speed-modifier (speed-modifier * obstacle-permeability)
  ]
  let step-length ((speed-um-s * speed-modifier) / patch-scale-um)
  fd step-length

  set state-timer state-timer - 1
  if state-timer <= 0 [
    set state "tumbling"
    set state-timer (tumble-duration-s / tick-duration-s)
  ]

  if [obstacle-here?] of patch-here and obstacle-permeability < 1 [
    set state "tumbling"
    set state-timer (tumble-duration-s / tick-duration-s)
    rt random 180 - 90
  ]
end

to tumble-behavior
  let target-heading calculate-best-tumble-direction
  let turn-angle (subtract-headings target-heading heading)
  rt (turn-angle * 0.5) + (random 90 - 45)

  set state-timer state-timer - 1
  if state-timer <= 0 [
    set state "running"
    set state-timer (run-duration-s / tick-duration-s)
  ]
end

to-report calculate-best-tumble-direction
  if not chemotaxis-on? [
    let best-neighbor max-one-of neighbors [nutrient_lvl]
    ifelse [nutrient_lvl] of best-neighbor > 0 [ report towards best-neighbor ] [ report random 360 ]
  ]
  ifelse state = "seeking-biofilm" [
    ; ... (this part remains unchanged) ...
    let p-here patch-here
    let current-score [ai-2-potential] of p-here
    let best-chem-heading heading
    let best-chem-score current-score
    let sensing-radius (taxis-sensitivity * 2 / patch-scale-um)
    foreach (shuffle [0 45 90 135 180 225 270 315]) [ angle ->
      let sample-patch patch-at-heading-and-distance angle sensing-radius
      if sample-patch != nobody [
        let sample-score [ai-2-potential] of sample-patch
        if sample-score > best-chem-score [
          set best-chem-score sample-score
          set best-chem-heading angle
        ]
      ]
    ]
    if best-chem-score <= current-score [ set best-chem-heading random 360 ]
    report best-chem-heading
  ]
  [
    ;; --- NORMAL BEHAVIOR: Standard Chemotaxis (MODIFIED) ---
    let p-here patch-here

    ; --- NEW ESCAPE RULE ---
    ; Check if the ACTUAL food on the current patch is gone.
    if [nutrient_lvl] of p-here < 0.1 [
      report random 360
    ]
    ; --- END OF NEW RULE ---

    let current-score -100
    foreach attractants [ chem ->
      if chem = "Glucose" [ set current-score current-score + [glucose-potential] of p-here ]
      if chem = "Aspartate" [ set current-score current-score + [aspartate-potential] of p-here ]
    ]
    foreach repellents [ chem ->
      if chem = "Phenol" [ set current-score current-score - [phenol-potential] of p-here ]
      if chem = "Butanol" [ set current-score current-score - [butanol-potential] of p-here ]
      if chem = "Polymyxin B" [ set current-score current-score - [polymyxin-b-potential] of p-here]
    ]

    let best-chem-heading heading
    let best-chem-score current-score
    let sensing-radius (taxis-sensitivity / patch-scale-um)
    foreach (shuffle [0 45 90 135 180 225 270 315]) [ angle ->
      let sample-patch patch-at-heading-and-distance angle sensing-radius
      if sample-patch != nobody [
        let sample-score 0
        foreach attractants [ chem ->
          if chem = "Glucose" [ set sample-score sample-score + [glucose-potential] of sample-patch ]
          if chem = "Aspartate" [ set sample-score sample-score + [aspartate-potential] of sample-patch ]
        ]
        foreach repellents [ chem ->
          if chem = "Phenol" [ set sample-score sample-score - [phenol-potential] of sample-patch ]
          if chem = "Butanol" [ set sample-score sample-score - [butanol-potential] of sample-patch ]
          if chem = "Polymyxin B" [ set sample-score sample-score - [polymyxin-b-potential] of sample-patch]
        ]
        if sample-score > best-chem-score [
          set best-chem-score sample-score
          set best-chem-heading angle
        ]
      ]
    ]

    if best-chem-score <= current-score [
      let best-neighbor max-one-of neighbors [nutrient_lvl]
      ifelse [nutrient_lvl] of best-neighbor > 0 [
        set best-chem-heading towards best-neighbor
      ] [ set best-chem-heading random 360 ]
    ]

    let momentum-weight 0.5
    let momentum-x cos heading
    let momentum-y sin heading
    let chem-x cos best-chem-heading
    let chem-y sin best-chem-heading
    let final-x (chem-x * (1 - momentum-weight)) + (momentum-x * momentum-weight)
    let final-y (chem-y * (1 - momentum-weight)) + (momentum-y * momentum-weight)
    let final-heading atan final-y final-x

    if swarming-behavior? [
      let flocking-weight 0.3
      let flockmates other bacteria with [bacteria-type = [bacteria-type] of myself] in-radius 4
      if any? flockmates [
        let avg-flock-heading mean-heading-of flockmates
        let weighted-x cos final-heading
        let weighted-y sin final-heading
        let flock-x cos avg-flock-heading
        let flock-y sin avg-flock-heading
        let swarm-x (weighted-x * (1 - flocking-weight)) + (flock-x * flocking-weight)
        let swarm-y (weighted-y * (1 - flocking-weight)) + (flock-y * flocking-weight)
        set final-heading atan swarm-y swarm-x
      ]
    ]
    report final-heading
  ]
end

;----------------------------------------------------------
; Data Plotting and Export
;----------------------------------------------------------
to update-trackers
  set-current-plot "Population Counts"
  set-current-plot-pen "Total"
  plot count bacteria
  foreach active-bacteria [ species ->
    let agents-of-species bacteria with [bacteria-type = species]
    if any? agents-of-species [
      set-current-plot-pen species
      plot count agents-of-species
    ]
  ]

  set-current-plot "Biofilm Stats"
  set-current-plot-pen "Biofilm Bacteria"
  plot count bacteria with [in-biofilm?]
  set-current-plot-pen "Biofilm Mass"
  plot sum [biofilm-mass] of patches

  set-current-plot "Environment Stats"
  set-current-plot-pen "Avg Nutrients"
  plot mean [nutrient_lvl] of patches

  set-current-plot "Toxin Levels"
  foreach active-bacteria [ species ->
    let agents-of-species bacteria with [bacteria-type = species]
    if any? agents-of-species [
      set-current-plot-pen species
      plot mean [toxin-level] of agents-of-species
    ]
  ]

  set-current-plot "Energy Levels"
  foreach active-bacteria [ species ->
    let agents-of-species bacteria with [bacteria-type = species]
    if any? agents-of-species [
      set-current-plot-pen species
      plot mean [energy] of agents-of-species
    ]
  ]

  set-current-plot "Cause of Death"
  set-current-plot-pen "Starvation"
  plot deaths-by-starvation
  set-current-plot-pen "Old Age"
  plot deaths-by-old-age
  set-current-plot-pen "Toxin"
  plot deaths-by-toxin
end

;----------------------------------------------------------
; Helper Procedures
;----------------------------------------------------------

to-report parse-value [val]
  if is-number? val [ report val ]
  let dash-pos position "-" val
  ifelse dash-pos != false [
    let part1 safe-read-from-string (substring val 0 dash-pos)
    let part2 safe-read-from-string (substring val (dash-pos + 1) length val)
    report (part1 + part2) / 2
  ] [
    report safe-read-from-string val
  ]
end

to-report safe-read-from-string [s]
  let result 0
  let success false
  (carefully [ set result read-from-string s set success true ] [])
  if not success [ set result 0 ]
  report result
end

to-report my-blend-colors [color1 color2 factor]
  let rgb1 extract-rgb color1
  let rgb2 extract-rgb color2
  let new-r ((item 0 rgb1) * (1 - factor)) + ((item 0 rgb2) * factor)
  let new-g ((item 1 rgb1) * (1 - factor)) + ((item 1 rgb2) * factor)
  let new-b ((item 2 rgb1) * (1 - factor)) + ((item 2 rgb2) * factor)
  report rgb new-r new-g new-b
end

to-report mean-heading-of [turtleset]
  if not any? turtleset [ report 0 ]
  let avg-sin mean [sin heading] of turtleset
  let avg-cos mean [cos heading] of turtleset
  if avg-sin = 0 and avg-cos = 0 [ report random 360 ]
  report atan avg-sin avg-cos
end

to-report get-random-coords-in-zone [zone-name]
  let x 0
  let y 0
  let max-x max-pxcor
  let max-y max-pycor
  ifelse zone-name = "Center" [
    let angle random-float 360
    let radius center-zone-radius * sqrt(random-float 1)
    set x radius * cos(angle)
    set y radius * sin(angle)
  ]
  [ifelse zone-name = "Top-Right" [ set x random-float max-x set y random-float max-y ]
  [ifelse zone-name = "Top-Left" [ set x random-float (- max-x) set y random-float max-y ]
  [ifelse zone-name = "Bottom-Right" [ set x random-float max-x set y random-float (- max-y) ]
  [ifelse zone-name = "Bottom-Left" [ set x random-float (- max-x) set y random-float (- max-y) ]
  [ set x random-xcor set y random-ycor ]]]]]
  report (list x y)
end

to-report ensure-rgb-list [a-color]
  if is-list? a-color [ report a-color ]
  report extract-rgb a-color
end
@#$#@#$#@
GRAPHICS-WINDOW
752
420
1601
1270
-1
-1
6.97
1
10
1
1
1
0
0
0
1
-60
60
-60
60
1
1
1
ticks
30.0

BUTTON
250
12
313
45
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
163
53
226
86
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
160
10
243
43
NIL
load-files
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
232
54
295
87
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
643
28
789
61
Vibrio-cholerae?
Vibrio-cholerae?
0
1
-1000

SWITCH
641
78
789
111
Bacillus-subtilis?
Bacillus-subtilis?
0
1
-1000

SWITCH
637
123
786
156
Escherichia-coli?
Escherichia-coli?
0
1
-1000

SWITCH
636
175
818
208
Pseudomonas-aeruginosa?
Pseudomonas-aeruginosa?
0
1
-1000

SWITCH
634
222
807
255
Salmonella-enterica?
Salmonella-enterica?
1
1
-1000

SWITCH
1422
38
1527
71
Glucose?
Glucose?
1
1
-1000

TEXTBOX
1420
14
1570
32
Chemicals
11
0.0
1

TEXTBOX
644
10
794
28
Bacteria
11
0.0
1

SWITCH
1423
88
1540
121
Aspartate?
Aspartate?
1
1
-1000

SWITCH
1426
134
1529
167
Phenol?
Phenol?
1
1
-1000

SWITCH
1425
186
1529
219
Butanol?
Butanol?
1
1
-1000

SWITCH
1422
236
1563
269
Autoinducer-2?
Autoinducer-2?
1
1
-1000

CHOOSER
369
13
507
58
enviroment-chosen
enviroment-chosen
"Lab Agar Plate" "Soil Microcosm" "Wound Site" "Lake Water"
3

SWITCH
1929
77
2046
110
Agar-Wall?
Agar-Wall?
1
1
-1000

SWITCH
1923
128
2082
161
Polystyrene-Bead?
Polystyrene-Bead?
1
1
-1000

SWITCH
1929
187
2078
220
Necrotic-Tissue?
Necrotic-Tissue?
1
1
-1000

SWITCH
1931
237
2054
270
Oil-Droplet?
Oil-Droplet?
1
1
-1000

SWITCH
1922
287
2071
320
Metal-Oxide-NP?
Metal-Oxide-NP?
1
1
-1000

TEXTBOX
1931
10
2081
28
Obstacle
11
0.0
1

PLOT
50
265
551
480
Population Counts
Time (ticks)
Number of Bacteria
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Total" 1.0 0 -7500403 true "" ""
"Vibrio cholerae" 1.0 0 -11221820 true "" ""
"Bacillus subtilis" 1.0 0 -955883 true "" ""
"Escherichia coli" 1.0 0 -2064490 true "" ""
"Pseudomonas aeruginosa" 1.0 0 -13840069 true "" ""
"Salmonella enterica" 1.0 0 -1184463 true "" ""
"Paenibacillus polymyxa" 1.0 0 -6459832 true "" ""
"Burkholderia cenocepacia" 1.0 0 -14835848 true "" ""

PLOT
42
1424
523
1629
Environment Stats
Time (ticks)
Average Value
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Avg Nutrients" 1.0 0 -7500403 true "" ""

BUTTON
16
200
116
233
Export Data
export-all-plots \"simulation_data.csv\"
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
314
178
558
211
patch-scale-um
patch-scale-um
1
250
11.0
1
1
NIL
HORIZONTAL

SWITCH
359
139
526
172
bacteria-size-scale?
bacteria-size-scale?
0
1
-1000

PLOT
41
733
516
964
Cause of Death
Time
Cause of Death
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Starvation" 1.0 0 -7500403 true "" ""
"Old Age" 1.0 0 -10899396 true "" ""
"Toxin" 1.0 0 -2674135 true "" ""

PLOT
45
965
494
1182
Biofilm Stats
Time
Count / Mass
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Biofilm Bacteria" 1.0 0 -7500403 true "" ""
"Biofilm Mass" 1.0 0 -2674135 true "" ""

PLOT
44
1188
504
1414
Toxin Levels
Time
Average Toxin Level
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Vibrio cholerae" 1.0 0 -11221820 true "" ""
"Bacillus subtilis" 1.0 0 -955883 true "" ""
"Escherichia coli" 1.0 0 -2064490 true "" ""
"Pseudomonas aeruginosa" 1.0 0 -13840069 true "" ""
"Salmonella enterica" 1.0 0 -1184463 true "" ""
"Paenibacillus polymyxa" 1.0 0 -6459832 true "" ""
"Burkholderia cenocepacia" 1.0 0 -14835848 true "" ""

TEXTBOX
612
35
640
61
cyan
11
85.0
1

TEXTBOX
599
84
637
110
orange
11
25.0
1

TEXTBOX
601
129
624
155
pink
11
135.0
1

TEXTBOX
602
183
640
209
lime
11
65.0
1

TEXTBOX
592
227
635
253
yellow
11
45.0
1

PLOT
44
492
501
727
Energy Levels
Time
Average Energy Level
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Vibrio cholerae" 1.0 0 -11221820 true "" ""
"Bacillus subtilis" 1.0 0 -955883 true "" ""
"Escherichia coli" 1.0 0 -2064490 true "" ""
"Pseudomonas aeruginosa" 1.0 0 -13840069 true "" ""
"Salmonella enterica" 1.0 0 -1184463 true "" ""
"Paenibacillus polymyxa" 1.0 0 -6459832 true "" ""
"Burkholderia cenocepacia" 1.0 0 -14835848 true "" ""

SWITCH
633
271
821
304
Paenibacillus-polymyxa?
Paenibacillus-polymyxa?
0
1
-1000

TEXTBOX
587
280
624
298
brown
11
35.0
1

TEXTBOX
588
330
640
354
turquois
11
75.0
1

SWITCH
634
318
828
351
Burkholderia-cenocepacia?
Burkholderia-cenocepacia?
0
1
-1000

SLIDER
795
26
968
59
Vibrio-cholerae-num
Vibrio-cholerae-num
0
5000
7.0
1
1
NIL
HORIZONTAL

SLIDER
794
76
967
109
Bacillus-subtilis-num
Bacillus-subtilis-num
0
5000
4.0
1
1
NIL
HORIZONTAL

SLIDER
791
123
965
156
Escherichia-coli-num
Escherichia-coli-num
0
5000
16.0
1
1
NIL
HORIZONTAL

SLIDER
824
175
1010
208
Pseudomonas-aeruginosa-num
Pseudomonas-aeruginosa-num
0
5000
6.0
1
1
NIL
HORIZONTAL

SLIDER
815
224
1013
257
Salmonella-enterica-num
Salmonella-enterica-num
0
5000
49.0
1
1
NIL
HORIZONTAL

SLIDER
829
270
1015
303
Paenibacillus-polymyxa-num
Paenibacillus-polymyxa-num
0
5000
9.0
1
1
NIL
HORIZONTAL

SLIDER
835
319
1024
352
Burkholderia-cenocepacia-num
Burkholderia-cenocepacia-num
0
5000
5.0
1
1
NIL
HORIZONTAL

SLIDER
1534
37
1706
70
Glucose-sources
Glucose-sources
0
40
8.0
1
1
NIL
HORIZONTAL

SLIDER
1544
89
1716
122
Aspartate-sources
Aspartate-sources
0
40
8.0
1
1
NIL
HORIZONTAL

SLIDER
1537
135
1709
168
Phenol-sources
Phenol-sources
0
40
8.0
1
1
NIL
HORIZONTAL

SLIDER
1534
184
1706
217
Butanol-sources
Butanol-sources
0
40
8.0
1
1
NIL
HORIZONTAL

SLIDER
1568
235
1740
268
Autoinducer-2-sources
Autoinducer-2-sources
0
40
0.0
1
1
NIL
HORIZONTAL

BUTTON
161
100
301
133
NIL
print-loaded-environments
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
161
208
283
241
NIL
print-loaded-bacterias
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
162
136
292
169
NIL
print-loaded-chemicals
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
163
172
282
205
NIL
print-loaded-obstacles
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
16
17
81
50
Save View
export-view (word filename-prefix \"-model-\" ticks \".png\")
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
17
54
105
87
Save Interface
export-interface (word filename-prefix \"-full-interface-\" ticks \".png\")
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
16
91
87
124
Save State
export-world (word \"world-state-\" ticks \".csv\")
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
14
136
149
196
filename-prefix
CompetitionPaBu50NotScale
1
0
String

SLIDER
356
63
528
96
world-width-setting
world-width-setting
11
401
121.0
2
1
NIL
HORIZONTAL

SLIDER
356
100
528
133
world-height-setting
world-height-setting
11
401
121.0
2
1
NIL
HORIZONTAL

CHOOSER
978
23
1119
68
Vibrio-cholerae-zone
Vibrio-cholerae-zone
"No Zone" "Center" "Top-Left" "Top-Right" "Bottom-Left" "Bottom-Right"
0

CHOOSER
978
72
1121
117
Bacillus-subtilis-zone
Bacillus-subtilis-zone
"No Zone" "Center" "Top-Left" "Top-Right" "Bottom-Left" "Bottom-Right"
0

CHOOSER
977
121
1121
166
Escherichia-coli-zone
Escherichia-coli-zone
"No Zone" "Center" "Top-Left" "Top-Right" "Bottom-Left" "Bottom-Right"
0

CHOOSER
1015
171
1216
216
Pseudomonas-aeruginosa-zone
Pseudomonas-aeruginosa-zone
"No Zone" "Center" "Top-Left" "Top-Right" "Bottom-Left" "Bottom-Right"
0

CHOOSER
1016
219
1185
264
Salmonella-enterica-zone
Salmonella-enterica-zone
"No Zone" "Center" "Top-Left" "Top-Right" "Bottom-Left" "Bottom-Right"
0

CHOOSER
1021
269
1208
314
Paenibacillus-polymyxa-zone
Paenibacillus-polymyxa-zone
"No Zone" "Center" "Top-Left" "Top-Right" "Bottom-Left" "Bottom-Right"
0

CHOOSER
1028
319
1229
364
Burkholderia-cenocepacia-zone
Burkholderia-cenocepacia-zone
"No Zone" "Center" "Top-Left" "Top-Right" "Bottom-Left" "Bottom-Right"
0

CHOOSER
1721
30
1859
75
Glucose-zone
Glucose-zone
"No Zone" "Center" "Top-Left" "Top-Right" "Bottom-Left" "Bottom-Right"
0

CHOOSER
1724
82
1862
127
Aspartate-zone
Aspartate-zone
"No Zone" "Center" "Top-Left" "Top-Right" "Bottom-Left" "Bottom-Right"
0

CHOOSER
1724
132
1862
177
Phenol-zone
Phenol-zone
"No Zone" "Center" "Top-Left" "Top-Right" "Bottom-Left" "Bottom-Right"
0

CHOOSER
1722
181
1860
226
Butanol-zone
Butanol-zone
"No Zone" "Center" "Top-Left" "Top-Right" "Bottom-Left" "Bottom-Right"
0

CHOOSER
1747
232
1885
277
Autoinducer-2-zone
Autoinducer-2-zone
"No Zone" "Center" "Top-Left" "Top-Right" "Bottom-Left" "Bottom-Right"
0

CHOOSER
2249
70
2387
115
Agar-Wall-zone
Agar-Wall-zone
"No Zone" "Center" "Top-Left" "Top-Right" "Bottom-Left" "Bottom-Right"
0

CHOOSER
2268
123
2423
168
Polystyrene-Bead-zone
Polystyrene-Bead-zone
"No Zone" "Center" "Top-Left" "Top-Right" "Bottom-Left" "Bottom-Right"
0

CHOOSER
2268
178
2412
223
Necrotic-Tissue-zone
Necrotic-Tissue-zone
"No Zone" "Center" "Top-Left" "Top-Right" "Bottom-Left" "Bottom-Right"
0

CHOOSER
2265
229
2403
274
Oil-Droplet-zone
Oil-Droplet-zone
"No Zone" "Center" "Top-Left" "Top-Right" "Bottom-Left" "Bottom-Right"
1

CHOOSER
2263
279
2407
324
Metal-Oxide-NP-zone
Metal-Oxide-NP-zone
"No Zone" "Center" "Top-Left" "Top-Right" "Bottom-Left" "Bottom-Right"
1

SLIDER
2056
75
2228
108
Agar-Wall-num
Agar-Wall-num
0
100
4.0
1
1
NIL
HORIZONTAL

SLIDER
2086
128
2264
161
Polystyrene-Bead-num
Polystyrene-Bead-num
1
100
4.0
1
1
NIL
HORIZONTAL

SLIDER
2084
186
2256
219
Necrotic-Tissue-num
Necrotic-Tissue-num
1
100
19.0
1
1
NIL
HORIZONTAL

SLIDER
2077
232
2249
265
Oil-Droplet-num
Oil-Droplet-num
1
100
9.0
1
1
NIL
HORIZONTAL

SLIDER
2080
282
2252
315
Metal-Oxide-NP-num
Metal-Oxide-NP-num
1
100
1.0
1
1
NIL
HORIZONTAL

SLIDER
348
216
520
249
center-zone-radius
center-zone-radius
1
100
1.0
1
1
NIL
HORIZONTAL

SLIDER
1924
33
2096
66
obstacle-amount
obstacle-amount
0
100
20.0
1
1
NIL
HORIZONTAL

SWITCH
563
362
735
395
chemotaxis-enabled?
chemotaxis-enabled?
0
1
-1000

SWITCH
1127
128
1284
161
E-coli-chemotaxis?
E-coli-chemotaxis?
0
1
-1000

SWITCH
1126
25
1313
58
V-cholerae-chemotaxis?
V-cholerae-chemotaxis?
0
1
-1000

SWITCH
1127
77
1304
110
B-subtilis-chemotaxis?
B-subtilis-chemotaxis?
0
1
-1000

SWITCH
1218
176
1419
209
P-aeruginosa-chemotaxis?
P-aeruginosa-chemotaxis?
0
1
-1000

SWITCH
1191
223
1376
256
S-enterica-chemotaxis?
S-enterica-chemotaxis?
0
1
-1000

SWITCH
1213
271
1406
304
P-polymyxa-chemotaxis?
P-polymyxa-chemotaxis?
0
1
-1000

SWITCH
1238
325
1446
358
B-cenocepacia-chemotaxis?
B-cenocepacia-chemotaxis?
0
1
-1000

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Test 1 - Logistic Growth" repetitions="10" runMetricsEveryStep="true">
    <preExperiment>load-files
setup</preExperiment>
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>ticks = 21685</exitCondition>
    <metric>ticks</metric>
    <metric>count bacteria</metric>
    <metric>count bacteria with [bacteria-type = "Escherichia coli"]</metric>
    <metric>count bacteria with [bacteria-type = "Paenibacillus polymyxa"]</metric>
    <metric>count bacteria with [bacteria-type = "Burkholderia cenocepacia"]</metric>
    <metric>count bacteria with [bacteria-type = "Pseudomonas aeruginosa"]</metric>
    <metric>count bacteria with [bacteria-type = "Salmonella enterica"]</metric>
    <metric>deaths-by-starvation</metric>
    <metric>deaths-by-old-age</metric>
    <metric>deaths-by-toxin</metric>
    <metric>mean [nutrient_lvl] of patches</metric>
    <enumeratedValueSet variable="enviroment-chosen">
      <value value="&quot;Lab Agar Plate&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="world-width-setting">
      <value value="121"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="world-height-setting">
      <value value="121"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-scale-um">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tick-duration-s">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Escherichia-coli?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Escherichia-coli-num">
      <value value="31"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Escherichia-coli-zone">
      <value value="&quot;Center&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Glucose?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Vibrio-cholerae?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Bacillus-subtilis?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Pseudomonas-aeruginosa?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Salmonella-enterica?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Paenibacillus-polymyxa?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Burkholderia-cenocepacia?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Aspartate?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Phenol?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Butanol?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Autoinducer-2?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Agar-Wall?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Polystyrene-Bead?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Necrotic-Tissue?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Oil-Droplet?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Metal-Oxide-NP?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
