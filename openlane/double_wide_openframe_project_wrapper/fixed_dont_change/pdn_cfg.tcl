# Copyright 2020-2022 Efabless Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

source $::env(SCRIPTS_DIR)/openroad/common/set_global_connections.tcl
set_global_connections

set secondary []
foreach vdd $::env(VDD_NETS) gnd $::env(GND_NETS) {
    if { $vdd != $::env(VDD_NET)} {
        lappend secondary $vdd

        set db_net [[ord::get_db_block] findNet $vdd]
        if {$db_net == "NULL"} {
            set net [odb::dbNet_create [ord::get_db_block] $vdd]
            $net setSpecial
            $net setSigType "POWER"
        }
    }

    if { $gnd != $::env(GND_NET)} {
        lappend secondary $gnd

        set db_net [[ord::get_db_block] findNet $gnd]
        if {$db_net == "NULL"} {
            set net [odb::dbNet_create [ord::get_db_block] $gnd]
            $net setSpecial
            $net setSigType "GROUND"
        }
    }
}

set_voltage_domain -name CORE -power $::env(VDD_NET) -ground $::env(GND_NET) \
    -secondary_power $secondary

# Assesses whether the design is the core of the chip or not based on the
# value of $::env(DESIGN_IS_CORE) and uses the appropriate stdcell section
if { $::env(DESIGN_IS_CORE) == 1 } {
    # Used if the design is the core of the chip
    define_pdn_grid \
        -name stdcell_grid \
        -starts_with POWER \
        -voltage_domain CORE \
        -pins "$::env(FP_PDN_VERTICAL_LAYER) $::env(FP_PDN_HORIZONTAL_LAYER)"

    add_pdn_stripe \
        -grid stdcell_grid \
        -layer $::env(FP_PDN_VERTICAL_LAYER) \
        -width $::env(FP_PDN_VWIDTH) \
        -pitch $::env(FP_PDN_VPITCH) \
        -offset $::env(FP_PDN_VOFFSET) \
        -spacing $::env(FP_PDN_VSPACING) \
        -starts_with POWER -extend_to_core_ring

    add_pdn_stripe \
        -grid stdcell_grid \
        -layer $::env(FP_PDN_HORIZONTAL_LAYER) \
        -width $::env(FP_PDN_HWIDTH) \
        -pitch $::env(FP_PDN_HPITCH) \
        -offset $::env(FP_PDN_HOFFSET) \
        -spacing $::env(FP_PDN_HSPACING) \
        -starts_with POWER -extend_to_core_ring

    add_pdn_connect \
        -grid stdcell_grid \
        -layers "$::env(FP_PDN_VERTICAL_LAYER) $::env(FP_PDN_HORIZONTAL_LAYER)"
} else {
    # Used if the design is a macro in the core
    define_pdn_grid \
        -name stdcell_grid \
        -starts_with POWER \
        -voltage_domain CORE \
        -pins $::env(FP_PDN_VERTICAL_LAYER)

    add_pdn_stripe \
        -grid stdcell_grid \
        -layer $::env(FP_PDN_VERTICAL_LAYER) \
        -width $::env(FP_PDN_VWIDTH) \
        -pitch $::env(FP_PDN_VPITCH) \
        -offset $::env(FP_PDN_VOFFSET) \
        -starts_with POWER
}

# Adds the standard cell rails if enabled.
if { $::env(FP_PDN_ENABLE_RAILS) == 1 } {
    add_pdn_stripe \
        -grid stdcell_grid \
        -layer $::env(FP_PDN_RAIL_LAYER) \
        -width $::env(FP_PDN_RAIL_WIDTH) \
        -followpins \
        -starts_with POWER

    add_pdn_connect \
        -grid stdcell_grid \
        -layers "$::env(FP_PDN_RAIL_LAYER) $::env(FP_PDN_VERTICAL_LAYER)"
}


# Adds the core ring if enabled.
if { $::env(FP_PDN_CORE_RING) == 1 } {
    add_pdn_ring \
        -grid stdcell_grid \
        -layers "$::env(FP_PDN_VERTICAL_LAYER) $::env(FP_PDN_HORIZONTAL_LAYER)" \
        -widths "$::env(FP_PDN_CORE_RING_VWIDTH) $::env(FP_PDN_CORE_RING_HWIDTH)" \
        -spacings "$::env(FP_PDN_CORE_RING_VSPACING) $::env(FP_PDN_CORE_RING_HSPACING)" \
        -core_offset "$::env(FP_PDN_CORE_RING_VOFFSET) $::env(FP_PDN_CORE_RING_HOFFSET)"
}

define_pdn_grid \
    -macro \
    -default \
    -name macro \
    -starts_with POWER \
    -halo "$::env(FP_PDN_HORIZONTAL_HALO) $::env(FP_PDN_VERTICAL_HALO)"

add_pdn_connect \
    -grid macro \
    -layers "$::env(FP_PDN_VERTICAL_LAYER) $::env(FP_PDN_HORIZONTAL_LAYER)"

# Power connection macros.
#
# The padframe ends the vccd1 and vssd1 pad straps on met3 ports at the east
# edge of the user area. Each macro below is a met3 plate with via3 arrays
# that carries one pad's two ports onto that supply's leg of the core ring:
# vccd1 on the inner leg, vssd1 on the outer leg. They are placed here, not
# in the RTL or in config.json, so every hardened wrapper has them in the
# same place. The locations are tied to pin_template.def and to the
# FP_PDN_CORE_RING_* values in config.json.
namespace eval dw_power {
    # {macro x y} in microns, orientation N.
    variable connections {
        {dw_vccd1_connection 6710.515 4327.505}
        {dw_vssd1_connection 6710.515 2088.510}
    }
}

proc dw_power::place_connections {} {
    variable connections
    set db [ord::get_db]
    set block [ord::get_db_block]
    set dbu [$block getDbUnitsPerMicron]

    if { !$::env(FP_PDN_CORE_RING) } {
        error "the power connection macros need the vccd1/vssd1 core ring; keep FP_PDN_CORE_RING on"
    }
    foreach connection $connections {
        lassign $connection name x y
        set master [$db findMaster $name]
        if { $master eq "NULL" } {
            error "power connection macro $name is not loaded; keep its MACROS entry\
                (fixed_dont_change/$name.lef and .gds) in config.json"
        }
        set inst [$block findInst $name]
        if { $inst eq "NULL" } {
            set inst [odb::dbInst_create $block $master $name]
        }
        $inst setOrient R0
        $inst setLocation [expr { round($x * $dbu) }] [expr { round($y * $dbu) }]
        $inst setPlacementStatus FIRM
    }
    puts "\[INFO\] Placed [llength $connections] power connection macros."
}

dw_power::place_connections
