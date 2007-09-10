####    Player Mode ATC ####
var ATClog_dialog = gui.Dialog.new("/sim/gui/dialogs/ATC-log/dialog", "Aircraft/ATC/Dialogs/ATC-log.xml");
var ATCchat_dialog = gui.Dialog.new("/sim/gui/dialogs/ATC-chat/dialog", "Aircraft/ATC/Dialogs/ATCchat.xml");
Tower_lat = props.globals.getNode("/sim/tower/latitude-deg",1);
Tower_lon = props.globals.getNode("/sim/tower/longitude-deg",1);
Tower_alt = props.globals.getNode("/sim/tower/altitude-ft",1);
ATC_lat = props.globals.getNode("/position/latitude-deg",1);
ATC_lon = props.globals.getNode("/position/longitude-deg",1);
ATC_alt = props.globals.getNode("/position/altitude-ft",1);
ATC_heading = props.globals.getNode("/orientation/heading-deg",1);
ATC_pitch = props.globals.getNode("/orientation/pitch-deg",1);
ATC_fov = props.globals.getNode("/sim/current-view/field-of-view",1);
ATC_target_brg = props.globals.getNode("/sim/current-view/goal-heading-offset-deg",1);
ATC_target_pitch = props.globals.getNode("/sim/current-view/goal-pitch-offset-deg",1);
ATC_target_id = props.globals.getNode("/sim/atc/target-id",1);
ATC_target_alt = props.globals.getNode("/sim/atc/target-alt",1);
ATC_target_range = props.globals.getNode("/sim/atc/target-range",1);
ATC_target_speed = props.globals.getNode("/sim/atc/target-kt",1);
ATC_target_hdg = props.globals.getNode("/sim/atc/target-hdg",1);
ATC_num =props.globals.getNode("/sim/atc/target-number",1);
ATC_panel_visibility = props.globals.getNode("/sim/panel/visibility", 1);
RADAR =props.globals.getNode("/instrumentation/radar", 1);

var ViewNum = 0;
var FDM_ON = 0;
var follow = 1;

var do_init = func {
    props.globals.getNode("/sim/current-view/view-number",1).setValue(100);
    ATC_lat.setValue(Tower_lat.getValue());
    ATC_lon.setValue(Tower_lon.getValue());
    ATC_alt.setValue(Tower_alt.getValue());
    ATC_num.setIntValue(0);
    ATC_target_id.setValue("");
    ATC_target_alt.setDoubleValue(0);
    ATC_target_speed.setDoubleValue(0);
    ATC_target_hdg.setDoubleValue(0);
    aircraft.data.add("/instrumentation/radar/font");
    FDM_ON =1;
    settimer(update_systems, 1);
#    setprop("/sim/gui/dialogs/ATC-log/dialog/width", 400 * (getprop("/sim/startup/xsize") - 10) / 1014);
#    setprop("/sim/gui/dialogs/ATC-log/dialog/height", 344 * (getprop("/sim/startup/ysize") - 40) / 728);
    ATClog_dialog.open();
    ATCchat_dialog.open();
}

setlistener("/sim/signals/fdm-initialized", do_init);
setlistener("/sim/signals/reinit", func {
    cmdarg().getBoolValue() and return;
    # HACK: something overwrites view & position if we call do_init from here
    settimer(do_init, 1);
});

setlistener("/sim/current-view/view-number", func {
    if(FDM_ON !=0){
        ATC_lat.setValue(Tower_lat.getValue());
        ATC_lon.setValue(Tower_lon.getValue());
        ATC_alt.setValue(Tower_alt.getValue());
        if (cmdarg().getValue() != 100) {
                props.globals.getNode("/sim/current-view/view-number").setValue(100);
        }
    }
});

setlistener("/sim/tower/airport-id", func {
    if(FDM_ON !=0){
        ATC_lat.setValue(Tower_lat.getValue());
        ATC_lon.setValue(Tower_lon.getValue());
        ATC_alt.setValue(Tower_alt.getValue());
    }
});

setlistener("/sim/tower/altitude-ft", func {
    if(FDM_ON !=0){
        ATC_lat.setValue(Tower_lat.getValue());
        ATC_lon.setValue(Tower_lon.getValue());
        ATC_alt.setValue(Tower_alt.getValue());
    }
});

is_valid_target = func(target) {
    return target.getNode("valid").getValue() and target.getNode("radar/in-range").getValue();
}

tan = func(x) {
    return math.sin(x) / math.cos(x);
}

# adjust view so that it is centered at the given position 
# position 0 is center, position 1 is edge
adjust_view = func(fov, position) {
    return ATC_panel_visibility.getValue() ? math.atan2(tan(fov * 0.00872665) * position, 1) * 57.3 : 0;
}

update_target = func(MP) {
    var brg = -MP.getNode("radar/h-offset").getValue() - adjust_view(ATC_fov.getValue(), 0.586);
    var pitch = ATC_pitch.getValue() + MP.getNode("radar/elevation-deg").getValue() - adjust_view(ATC_fov.getValue() * 0.75, 0.5);
    var alt = MP.getNode("position/altitude-ft").getValue();
    if (follow) {
        ATC_target_brg.setValue(brg);
        ATC_target_pitch.setValue(pitch);
    }
    ATC_target_alt.setValue(alt);
    ATC_target_id.setValue(MP.getNode("callsign").getValue());
    ATC_target_range.setValue(MP.getNode("radar/range-nm").getValue());
    ATC_target_speed.setValue(MP.getNode("velocities/true-airspeed-kt").getValue());
    ATC_target_hdg.setValue(MP.getNode("orientation/true-heading-deg").getValue());
}

add_with_wrap = func(value, step, limit) {
    value += step;
    if (value < 0) value = limit - 1;
    if (value >= limit) value = 0;
    
    return value;
}

step_target = func(step) {
    var mp_craft = props.globals.getNode("/ai/models").getChildren("multiplayer");
    var num = ATC_num.getValue();
    var ttl = size(mp_craft);

    if (ttl > 0) {
        num = add_with_wrap(num, step, ttl);
        if (step == 0) {
            # search upwards by default
            step = 1;
        }
    
        for(var tries = 0; tries < ttl; tries += 1) {
            if (is_valid_target(mp_craft[num])) {
                ATC_num.setValue(num);
                RADAR.getNode("selected-id", 1).setValue(mp_craft[num].getNode("id").getValue());
                return mp_craft[num];
            }
            num = add_with_wrap(num, step, ttl);
        }
    }

    ATC_num.setValue(-1);
    RADAR.getNode("selected-id", 1).setValue(-1);
    return nil;
}

update_systems = func {
    if (FDM_ON != 0) {
        # verify current target is valid,
        # try to find another if not
        var target = step_target(0);
        if (target != nil) {
            update_target(target);
        } else {
            ATC_target_alt.setValue("");
            ATC_target_id.setValue("");
            ATC_target_range.setValue(0);
            ATC_target_speed.setValue(0);
            ATC_target_hdg.setValue(0);
        }
        settimer(update_systems, 0);
    }
}

var select_font_callback = func { 
    var font = cmdarg().getValue();
    setprop("/instrumentation/radar/font", font);
}

select_atc_font = func {
    var font = getprop("/instrumentation/radar/font");
    var dir = getprop("/sim/fg-root") ~ "/Fonts";
    var file = "";
    if (font != nil and size(font) > 0) {
        file = font;
        for(var i = size(font) - 2; i >= 0; i -= 1) {
            if (font[i] == `/`) {
                dir = substr(font, 0, i);
                file = substr(font, i + 1);
                break;
            }
        }
    }
    var selector = gui.FileSelector.new(select_font_callback, "Select ATC radar font", "Select", nil, dir, file);
    selector.open();
}

toggle_tracking = func() {
    follow = !follow;
}

step_radar_range = func(dir) {
    var range_node = RADAR.getNode("range");
    var range = range_node.getValue();
    range *= dir > 0 ? 2 : 0.5;
    if (range < 1) range = 1;
    range_node.setValue(range);
}
