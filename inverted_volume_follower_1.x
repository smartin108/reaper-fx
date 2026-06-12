desc:Inverted volume follow flagger (smartin)
tags:volume follow_flagger
// author: smartin
// revised: 2026-01-01, 2026-01-31

/*

CONFIGURATION

ch 1-2 spl0-spl1 : noise to bring up to fill gaps
ch 3-4 spl2-spl3 : pass-through programme

*/

options:no_meter

slider1:threshhold=-48<-90,0,1>input threshhold (dB rms)
slider2:hold=500<0,20000,1>hold (ms)
slider4:attack=250<1,10000,1>attack (ms)
slider5:release=10<0,1000,1>release (ms)

in_pin:left input
in_pin:right input
in_pin:left trigger
in_pin:right trigger
out_pin:left output
out_pin:right output


@init
SRATE_INV = 1000/srate;             // sample duration in ms
DITHER0_DB = -120;                  // baseline dither level dB
                                    //   bear in mind this is added to the dither level 
                                    //   (it does not set the level) 
DITHER0_DEC = 10^(DITHER0_DB/20);   // baseline dither level float

programme_level_accum = 0;          // accumulator for program rms level (decimal)
programme_rms_db = 0;               // program rms level (dB)
programme_rms_dec = 0;              // program rms level (decimal)
low_flag = 0;                       // bool
hold_timer = 0;                     // ms
dither_triggered = 0;               // bool
dither_level = DITHER0_DEC;         // dither level modifier (decimal)
dither_change_rms = 0;              // dither change amount (dB)
dither_change = 1;                  // dither change amount (decimal)
dither_level_accum = 0;             // accumulator for dither level (decimal)
dither_rms_db = DITHER0_DB;         // dither level (dB)
dither_rms_dec = DITHER0_DEC;       // dither level (decimal)
block_counter = 0;                  // just for monitoring


// cgpt -->
// ---------------------------
// Audio side: RMS smoothing
// ---------------------------
// ---------------------------
// Sliders (optional quick tweaks)
// --------------------------
panel_width_px = 600;       // Panel width (px)
panel_height_px = 22;        // Panel height (px)
offset_x = 30;             // Offset X (px)
offset_y = 18;             // Offset Y (px)
pad_inner = 4;             // Inner padding (px)
rms_avg_dur_ms = hold;  // RMS averaging (ms)
//@slider
// Convert averaging time to one-pole smoothing coefficient.
// alpha close to 1 = slower.
ms = max(1, rms_duration_slider6);
alpha = exp(-1 / (ms*0.001*srate));


rms2 = 0;
alpha = 0.999;

db_min = -60;  // left of meter
db_max = 0;    // right of meter

// scale ticks you want to show (dB)
t0 = -60; t1 = -48; t2 = -36; t3 = -24; t4 = -12; t5 = 0;



// ---------------------------
// Helpers
// --------------------------
function clamp(x, lo, hi) ( x < lo ? lo : (x > hi ? hi : x); );

function lin2db(x) (
  x <= 10^(-20) ? -200 : (20*log(x)/log(10));
);

// Map dB range [db_min..db_max] to x pixel [x0..x1]
function db_to_x(db, db_min, db_max, x0, x1) (
  t = (db - db_min) / (db_max - db_min);
  t = clamp(t, 0, 1);
  x0 + t*(x1-x0);
);

// Draw rectangle outline
function draw_rect_outline(x,y,w,h, r,g,b,a) (
  gfx_set(r,g,b,a);
  // gfx_rect(x,y,w,h,fill) with fill=0 draws outline
  gfx_rect(x,y,w,h,0);
);

// Draw filled rectangle
function draw_rect_filled(x,y,w,h, r,g,b,a) (
  gfx_set(r,g,b,a);
  gfx_rect(x,y,w,h,1);
);

// Draw a vertical tick
function draw_tick(x, y0, y1, r,g,b,a) (
  gfx_set(r,g,b,a);
  gfx_line(x, y0, x, y1);
);

// Text (top-left anchored)
function draw_text(x,y, str, r,g,b,a) (
  gfx_set(r,g,b,a);
  gfx_x = x; gfx_y = y;
  gfx_drawstr(str);
);
// <-- cgpt
// end @init


@slider
// end @slider


@block
block_time = SRATE_INV*samplesblock;

programme_rms_dec = sqrt(0.5*programme_level_accum/samplesblock);
programme_rms_db = 20*log10(programme_rms_dec);
dither_rms_dec = sqrt(0.5*dither_level_accum/samplesblock);
dither_rms_db = 20*log10(dither_rms_dec);

low_flag = programme_rms_db < threshhold;
low_flag ? hold_timer += block_time : hold_timer = 0;
dither_triggered = hold_timer > hold;

dither_triggered ? (
  // when trigger is on, set an increment to smoothly increase the dither level

  block_increment = block_time/attack;    
  
  da_db = -SRATE_INV*DITHER0_DB/attack;
  dither_change = 10^(da_db/20);
) : (
  // when trigger is off, set an increment to smoothly decreasse the dither level

  block_increment = -1*block_time/release;
  
  dither_change_rms = -SRATE_INV*DITHER0_DB/release;
  dither_change = 10^(-da_db/20);     // note sneaky negative sign
);
programme_level_accum = 0;
dither_level_accum  = 0;
block_counter += 1;
// end @block


@sample
programme_level_accum += (spl2*spl2 + spl3*spl3);

dither_level *= dither_change;
dither_level > 1 ? dither_level = 1;
dither_level < DITHER0_DEC ? dither_level = DITHER0_DEC;

spl0 *= dither_level;
spl1 *= dither_level;
dither_level_accum  += (spl0*spl0 + spl1*spl1);

// cgpt --> 
//@sample
// simple RMS estimator: smooth squared signal, then sqrt
in = (spl2 + spl3)*0.5;     // mono-ish
//rms2 = alpha*rms2 + (1-alpha)*(in*in);
rms2 = programme_rms_dec;
// <-- cgpt
// end @sample


@gfx 640 160
function color1() ( gfx_r=0.1; gfx_g=1.0; gfx_b=0.1; );
function color2() ( gfx_r=0.8; gfx_g=0.1; gfx_b=0.1; );
function color_black() ( gfx_r=0.2; gfx_g=0.2; gfx_b=0.2; );


// --> cgpt
//@gfx 480 180
// ---------------------------
// Layout
// ---------------------------
gfx_clear = 0; // don't auto-clear; we'll paint background ourselves

W = gfx_w;
H = gfx_h;

ox = offset_x;
oy = offset_y;

panel_w = panel_width_px;
panel_h = panel_height_px;
pad = pad_inner;

// Keep panel inside window even if sliders get goofy
panel_w = min(panel_w, W - ox - 10);
panel_h = min(panel_h, H - oy - 10);

v_space = 80;
x0 = ox;
y0 = oy;
y1 = oy + 1 * v_space;
y2 = oy + 2 * v_space;

// We'll reserve some space below panel for the dB scale labels
scale_h = 18;              // ticks + text area
gap = 6;                   // gap between panel and scale
meter_x0 = x0 + pad;
meter_y0 = y0 + pad;
meter_x1 = x0 + panel_w - pad;
meter_y1 = y0 + panel_h - pad;

meter2_x0 = x0 + pad;
meter2_y0 = y1 + pad;
meter2_x1 = x0 + panel_w - pad;
meter2_y1 = y1 + panel_h - pad;

meter3_x0 = x0 + pad;
meter3_y0 = y2 + pad;
meter3_x1 = x0 + panel_w - pad;
meter3_y1 = y2 + panel_h - pad;

meter_w = meter_x1 - meter_x0;
meter_h = meter_y1 - meter_y0;

// ---------------------------
// Background
// ---------------------------
draw_rect_filled(0,0,W,H, 0.08,0.08,0.08,1);

// ---------------------------
// Panel outline + interior
// ---------------------------
draw_rect_filled(x0,y0,panel_w,panel_h, 0.12,0.12,0.12,1);
draw_rect_outline(x0,y0,panel_w,panel_h, 0.8,0.8,0.8,1);

draw_rect_filled(x0,y1,panel_w,panel_h, 0.12,0.12,0.12,1);
draw_rect_outline(x0,y1,panel_w,panel_h, 0.8,0.8,0.8,1);

draw_rect_filled(x0,y2,panel_w,panel_h, 0.12,0.12,0.12,1);
draw_rect_outline(x0,y2,panel_w,panel_h, 0.8,0.8,0.8,1);

// ---------------------------
// Compute current RMS dB + bar width
// ---------------------------
//rms = sqrt(rms2);
//rms_db = lin2db(rms);
rms_db = programme_rms_db;

// Map dB to fill proportion
t = (rms_db - db_min) / (db_max - db_min);
t = clamp(t, 0, 1);
fill_w = meter_w * t;

// ---------------------------
// Meter bar (filled) + subtle "empty" background
// ---------------------------
draw_rect_filled(meter_x0, meter_y0, meter_w, meter_h, 0.18,0.18,0.18,1);
rms_db >= threshhold ? rms_alpha = 1 : rms_alpha = clamp(rms_db/threshhold,0,1);
draw_rect_filled(meter_x0, meter_y0, fill_w, meter_h, 0.15,0.75,0.2,rms_alpha);
draw_rect_outline(meter_x0, meter_y0, meter_w, meter_h, 0,0,0,0.35);

// Optional readout
sprintf(#tmp, "RMS: %.1f dB", rms_db);
draw_text(x0, y0 + panel_h + gap + scale_h + 4, #tmp, 0.85,0.85,0.85,1);

// ---------------------------
// Countdown bar (filled) + subtle "empty" background
// ---------------------------
t22 = hold_timer / hold;
t22 = clamp(t22, 0, 1);
fill_w2 = meter_w * t22;
draw_rect_filled(meter2_x0, meter2_y0, meter_w, meter_h, 0.18,0.18,0.18,1);
draw_rect_filled(meter2_x0, meter2_y0, fill_w2, meter_h, 0.15,0.15,0.85,0.9);
draw_rect_outline(meter2_x0, meter2_y0, meter_w, meter_h, 0,0,0,0.35);

hold_timer > hold ? hold_display = hold : hold_display = hold_timer;
sprintf(#t2, "HOLD: %4d ms", hold_display);
draw_text(x0, y1 + panel_h + gap , #t2, 0.85,0.85,0.85,1);

// ---------------------------
// Attack bar (filled) + subtle "empty" background
// ---------------------------
t33 = dither_level;
t33 = clamp(t33, 0, 1);
fill_w3 = meter_w * t33;
draw_rect_filled(meter3_x0, meter3_y0, meter_w, meter_h, 0.18,0.18,0.18,1);
draw_rect_filled(meter3_x0, meter3_y0, fill_w3, meter_h, 0.83,0.15,0.18,0.8);
draw_rect_outline(meter3_x0, meter3_y0, meter_w, meter_h, 0,0,0,0.35);

sprintf(#t3, "ATTACK: %4d ms", dither_level * attack); 
draw_text(x0, y2 + panel_h + gap , #t3, 0.85,0.85,0.85,1);

// ---------------------------
// dB Scale under the panel
// ---------------------------
scale_y0 = y0 + panel_h + gap;
tick_top = scale_y0;
tick_bot_major = scale_y0 + 8;
tick_bot_minor = scale_y0 + 5;
text_y = scale_y0 + 8;

gfx_setfont(1, "Arial", 12);

// Major ticks & labels
function draw_major(db) local(x) (
  x = db_to_x(db, db_min, db_max, meter_x0, meter_x1);
  draw_tick(x, tick_top, tick_bot_major, 0.8,0.8,0.8,1);
  sprintf(#lbl, "%d", db);
  // center-ish label under tick
  gfx_measurestr(#lbl, tw, th);
  draw_text(x - tw*0.5, text_y, #lbl, 0.8,0.8,0.8,1);
);

draw_major(t0);
draw_major(t1);
draw_major(t2);
draw_major(t3);
draw_major(t4);
draw_major(t5);

// Minor ticks halfway between majors (optional)
function draw_minor(db) local(x) (
  x = db_to_x(db, db_min, db_max, meter_x0, meter_x1);
  draw_tick(x, tick_top, tick_bot_minor, 0.55,0.55,0.55,1);
);

draw_minor((-60+-48)*0.5);
draw_minor((-48+-36)*0.5);
draw_minor((-36+-24)*0.5);
draw_minor((-24+-12)*0.5);
draw_minor((-12+0)*0.5);

// <-- cgpt

// end @gfx

// EOF
