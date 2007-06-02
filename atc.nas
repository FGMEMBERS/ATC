####    Player Mode ATC ####
Tower_lat = props.globals.getNode("/sim/tower/latitude-deg",1);
Tower_lon = props.globals.getNode("/sim/tower/longitude-deg",1);
Tower_alt = props.globals.getNode("/sim/tower/altitude-ft",1);
ATC_lat = props.globals.getNode("/position/latitude-deg",1);
ATC_lon = props.globals.getNode("/position/longitude-deg",1);
ATC_alt = props.globals.getNode("/position/altitude-ft",1);
ATC_target_brg = props.globals.getNode("/orientation/heading-deg",1);
ATC_target_pitch = props.globals.getNode("/orientation/pitch-deg",1);
ATC_target_id = props.globals.getNode("/sim/atc/target-id",1);
ATC_target_alt = props.globals.getNode("/sim/atc/target-alt",1);
ATC_target_range = props.globals.getNode("/sim/atc/target-range",1);
ATC_target_speed = props.globals.getNode("/sim/atc/target-kt",1);
ATC_target_hdg = props.globals.getNode("/sim/atc/target-hdg",1);
ATC_target_norm = props.globals.getNode("/sim/atc/target-nm-norm",1);
ATC_num =props.globals.getNode("/sim/atc/target-number",1);
ATC_total =props.globals.getNode("/sim/atc/target-total",1);
RADAR =props.globals.getNode("/instrumentation/radar",1);
var ViewNum = 0;
var FDM_ON = 0;
var counter =0;

setlistener("/sim/signals/fdm-initialized", func {
    props.globals.getNode("/sim/current-view/view-number",1).setValue(100);
    ATC_lat.setValue(Tower_lat.getValue());
    ATC_lon.setValue(Tower_lon.getValue());
    ATC_alt.setValue(Tower_alt.getValue());
    ATC_num.setIntValue(0);
    ATC_target_id.setValue("");
    ATC_target_alt.setDoubleValue(0);
    ATC_target_speed.setDoubleValue(0);
    ATC_target_hdg.setDoubleValue(0);
    RADAR.getNode("factor").setDoubleValue((1/RADAR.getNode("range").getValue())*10);
    FDM_ON =1;
    settimer(update_systems, 1);
    });

setlistener("/sim/current-view/view-number", func {
    if(FDM_ON !=0){
        ViewNum = cmdarg().getValue();
        ATC_lat.setValue(Tower_lat.getValue());
        ATC_lon.setValue(Tower_lon.getValue());
        ATC_alt.setValue(Tower_alt.getValue());
        if(ViewNum != 100){
            ViewNum = 100;
        }
        props.globals.getNode("/sim/current-view/view-number").setValue(100);
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

setlistener("/instrumentation/radar/range", func {
    var factor = 1.0 / cmdarg().getValue();
    factor *=300;
    RADAR.getNode("factor").setDoubleValue(factor);
});

update_target = func{
    var brg = 0;
    var norm=0;
    var number = arg[0];
    MP =props.globals.getNode("/ai/models/multiplayer["~ number ~"]",1);
    var brg = MP.getNode("radar/bearing-deg").getValue();
    var pitch = MP.getNode("radar/elevation-deg").getValue();
    var alt = MP.getNode("position/altitude-ft").getValue();
    if(brg == nil){brg = 0;}
    ATC_target_brg.setValue(brg);
    ATC_target_pitch.setValue(pitch);
    ATC_target_alt.setValue(alt);
    ATC_target_id.setValue(MP.getNode("callsign").getValue());
    ATC_target_range.setValue(MP.getNode("radar/range-nm").getValue());
    norm = ATC_target_range.getValue() / RADAR.getNode("range").getValue();
    ATC_target_norm.setValue(norm);
    ATC_target_speed.setValue(MP.getNode("velocities/true-airspeed-kt").getValue());
    ATC_target_hdg.setValue(MP.getNode("orientation/true-heading-deg").getValue());
}

update_systems = func {
    if(FDM_ON != 0){
    #### RADAR BLIPS ####
    var mp_craft = props.globals.getNode("/ai/models").getChildren("multiplayer");
    var ttl = size(mp_craft);
    ATC_total.setIntValue(ttl);
    var num =ATC_num.getValue();
    if(num >= ttl)num = ttl-1;
    if(num < 0){num = 0;}
    ATC_num.setValue(num);
    setprop("instrumentation/radar/mp[" ~ counter ~ "]/callsign",getprop("/ai/models/multiplayer["~ counter ~"]/callsign"));
    if(getprop("/ai/models/multiplayer["~ counter ~"]/valid")){
        setprop("instrumentation/radar/mp[" ~ counter ~ "]/valid",getprop("/ai/models/multiplayer["~ counter ~"]/radar/in-range"));
        }else{setprop("instrumentation/radar/mp[" ~ counter ~ "]/valid",0);}
    setprop("instrumentation/radar/mp[" ~ counter ~ "]/x",getprop("/ai/models/multiplayer["~ counter ~"]/radar/x-shift"));
    setprop("instrumentation/radar/mp[" ~ counter ~ "]/y",getprop("/ai/models/multiplayer["~ counter ~"]/radar/y-shift"));
    counter +=1;
    if(counter >=ttl){counter = 0;}
    if(ttl > 0){
        update_target(num);
    }
    }
    settimer(update_systems, 0);
}

