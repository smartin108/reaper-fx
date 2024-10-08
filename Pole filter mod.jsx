// (C) 2008-2009, Lubomir I. Ivanov

// NO WARRANTY IS GRANTED. THIS PLUG-IN IS PROVIDED ON AN "AS IS" BASIS, WITHOUT
// WARRANTY OF ANY KIND. NO LIABILITY IS GRANTED, INCLUDING, BUT NOT LIMITED TO,
// ANY DIRECT OR INDIRECT,  SPECIAL,  INCIDENTAL OR CONSEQUENTIAL DAMAGE ARISING
// OUT OF  THE  USE  OR INABILITY  TO  USE  THIS PLUG-IN,  COMPUTER FAILTURE  OF
// MALFUNCTION INCLUDED.  THE USE OF THE SOURCE CODE,  EITHER  PARTIALLY  OR  IN
// TOTAL, IS ONLY GRANTED,  IF USED IN THE SENSE OF THE AUTHOR'S INTENTION,  AND
// USED WITH ACKNOWLEDGEMENT OF THE AUTHOR. FURTHERMORE IS THIS PLUG-IN A  THIRD
// PARTY CONTRIBUTION,  EVEN IF INCLUDED IN REAPER(TM),  COCKOS INCORPORATED  OR
// ITS AFFILIATES HAVE NOTHING TO DO WITH IT.  LAST BUT NOT LEAST, BY USING THIS
// PLUG-IN YOU RELINQUISH YOUR CLAIM TO SUE IT'S AUTHOR, AS WELL AS THE CLAIM TO
// ENTRUST SOMEBODY ELSE WITH DOING SO.
// 
// Released under GPL:
// <http://www.gnu.org/licenses/>.

//=================================================
desc: Simple 1-Pole Filter (smartin mod)
//tags: filter
//author: Liteon

slider1:0<0,1,1{Stereo,Mono}>Processing
slider2:0<0,1,1{LP,HP}>Filter Type
slider3:100<0,100,0.05>Cutoff (Scale)
slider4:0<-25,25,0.05>Output (dB)
slider5:3<0.1,10,0.01>Rate Multiple

in_pin:left input
in_pin:right input
out_pin:left output
out_pin:right output

//=================================================
@init
ext_tail_size = -1;

@slider
//mono
mono = slider1;

//type
hp = slider2;

//exp scale
sx = 16+slider3*1.20103;
cutoff = floor(exp(sx*log(1.059))*8.17742);

//coeff
cutoff = min(cutoff,20000);
lp_cut = 2*$pi*cutoff;
lp_n = 1/(lp_cut+ slider5*srate);
// lp_n = 1/(lp_cut+ 3*srate);
lp_b1 = (slider5*srate - lp_cut)*lp_n;
// lp_b1 = (3*srate - lp_cut)*lp_n;
lp_a0 = lp_cut*lp_n;

//outgain
outgain = 10^(slider4/20);

//=================================================
@sample
//stereo
mono == 0 ? (

//recursion
inl = spl0;
inr = spl1;
lp_outl = 2*inl*lp_a0 + lp_outl*lp_b1;
lp_outr = 2*inr*lp_a0 + lp_outr*lp_b1;

//type
hp == 0 ? (
  spl0 = lp_outl*outgain;
  spl1 = lp_outr*outgain;
) : (
  spl0 = (inl-lp_outl)*outgain;
  spl1 = (inr-lp_outr)*outgain;
);

) : (
//mono

//recursion
inl = (spl0+spl1)/2;
lp_outl = 2*inl*lp_a0 + lp_outl*lp_b1;

//type
hp == 0 ? (
  spl0=spl1=lp_outl*outgain;
) : (
  spl0=spl1=(inl-lp_outl)*outgain;
);

);

//=================================================
@gfx 100 16
//draw freq scale numbers
gfx_x=gfx_y=5;
gfx_lineto(gfx_x, gfx_y,0);
gfx_r=gfx_b=0;
gfx_g=gfx_a=1;
gfx_drawchar($'F');
gfx_drawchar($' ');
gfx_drawchar($'=');
gfx_drawchar($' ');
gfx_drawnumber(cutoff,0);
gfx_drawchar($' ');
gfx_drawchar($'H');
gfx_drawchar($'z');
