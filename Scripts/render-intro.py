#!/usr/bin/env python3
"""Render the 32-second product film locally. Requires Pillow, NumPy and FFmpeg.

Only existing native UI captures and the app icon are used. The soundtrack is
an original, deterministic synthesis (no samples, voices or cloud services).
Run from any directory: python3 Scripts/render-intro.py
"""
import math
from functools import lru_cache
import shutil
import subprocess
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Docs/media/intro'
WORK = ROOT / 'build/intro-video'
W, H, FPS, SECONDS = 1920, 1080, 30, 32
INK, BLUE, MUTED = '#17323d', '#0672d3', '#58707b'
BG = '#f7faf9'
FONT = '/System/Library/Fonts/Avenir Next.ttc'

@lru_cache(maxsize=32)
def font(size, bold=False):
    return ImageFont.truetype(FONT, size, index=2 if bold else 7)

def text(image, xy, value, size=32, color=INK, bold=False, anchor=None):
    ImageDraw.Draw(image).text(xy, value, font=font(size, bold), fill=color, anchor=anchor)

def ease(v):
    v = max(0, min(1, v))
    return 1 - (1-v)**3

def paste(image, layer, xy):
    image.paste(layer, (round(xy[0]), round(xy[1])), layer if layer.mode == 'RGBA' else None)

def rounded_ui(file, crop, width):
    source = Image.open(ROOT / file).convert('RGB').crop(crop)
    height = round(source.height * width/source.width)
    source = source.resize((width,height), Image.Resampling.LANCZOS)
    layer = Image.new('RGBA', (width+70, height+110))
    shadow = Image.new('RGBA',layer.size)
    ImageDraw.Draw(shadow).rounded_rectangle((29,35,width+41,height+79),radius=24,fill=(23,50,61,37))
    layer.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(15)))
    d=ImageDraw.Draw(layer)
    d.rounded_rectangle((20,12,width+50,height+62),radius=20,fill='white',outline='#dce6e6',width=2)
    for x,c in [(38,'#ff6059'),(61,'#ffbd2e'),(84,'#28c840')]:
        d.ellipse((x,27,x+13,40), fill=c)
    d.text((110,23),'GlideMouse',font=font(19),fill=MUTED)
    layer.paste(source,(35,54))
    return layer

def soundtrack():
    """Warm plucked chords, a light pulse, and a restrained original melody."""
    sr=48000
    audio=np.zeros((SECONDS*sr,2),np.float64)
    rng=np.random.default_rng(2718)
    beat=0.625  # 96 BPM; changes on the four-bar phrase.
    chords=[(50,57,62,66),(47,54,59,62),(43,50,55,59),(45,52,57,61)]
    def note(start,duration,midi,gain,pan=0.0):
        n=min(round(duration*sr),len(audio)-round(start*sr))
        if n<=0:return
        t=np.arange(n)/sr
        f=440*2**((midi-69)/12)
        env=np.minimum(t/0.012,1)*np.exp(-t*3.4)*np.minimum((duration-t)/0.14,1)
        signal=(np.sin(2*np.pi*f*t)+.25*np.sin(4*np.pi*f*t)+.06*np.sin(6*np.pi*f*t))*env*gain
        pos=round(start*sr)
        audio[pos:pos+n,0]+=signal*math.sqrt((1-pan)/2)
        audio[pos:pos+n,1]+=signal*math.sqrt((1+pan)/2)
    for bar in range(13):
        chord=chords[bar%4]
        for i in range(8):
            start=bar*4*beat+i*beat/2
            if start>=31:break
            note(start,1.4,chord[[0,2,1,3,0,2,1,3][i]]+12,.10,(-.18 if i%2 else .18))
        note(bar*4*beat,2.1,chord[0]-.0,.13)
    melody=[(5,74),(6.25,73),(7.5,69),(10,71),(11.25,74),(12.5,73),(15,71),(16.25,69),(17.5,67),(20,69),(21.25,73),(22.5,74),(25,78),(26.25,76),(27.5,74),(30,74)]
    for start,midi in melody: note(start,1.6,midi,.055,.1)
    for b in range(4,49):
        start=b*beat
        if start>=30:break
        n=round(.18*sr);t=np.arange(n)/sr
        if b%2==0:
            kick=np.sin(2*np.pi*(55*t+2.4*(1-np.exp(-22*t))))*np.exp(-32*t)*.10
            audio[round(start*sr):round(start*sr)+n]+=kick[:,None]
        else:
            tap=rng.normal(0,1,n)*np.exp(-55*t)*.012
            audio[round(start*sr):round(start*sr)+n]+=tap[:,None]
    time=np.arange(len(audio))/sr
    fade=np.minimum(time/1.1,1)*np.clip((SECONDS-time)/1.6,0,1)
    audio*=fade[:,None]
    audio*=.56/max(abs(audio).max(),1e-9)
    path=WORK/'original-soundtrack.wav'
    with wave.open(str(path),'wb') as f:
        f.setnchannels(2);f.setsampwidth(2);f.setframerate(sr)
        f.writeframes((audio*32767).astype('<i2').tobytes())
    return path

def assets():
    return {
        'icon':Image.open(ROOT/'Assets/AppIcon-transparent.png').convert('RGBA').resize((230,230),Image.Resampling.LANCZOS),
        'buttons':rounded_ui('Docs/media/screenshots/en-buttons.png',(203,291,1003,647),1060),
        'gestures':rounded_ui('Docs/media/screenshots/en-buttons.png',(611,294,1002,647),630),
        'actions':rounded_ui('Docs/media/screenshots/en-actions.png',(13,19,487,491),430),
        'scroll':rounded_ui('Docs/media/intro/source/scrolling.png',(0,0,1210,300),1100),
        'profiles':rounded_ui('Docs/media/intro/source/app-settings.png',(0,0,1216,554),1035),
    }

def brand_corner(image):
    text(image,(98,61),'GlideMouse',30,bold=True)
    text(image,(1820,67),'For macOS',22,color=MUTED,anchor='ra')

def title(image, lines, sub, p):
    y=342+round(24*(1-ease(p*2)))
    for line in lines:
        text(image,(100,y),line,76,bold=True)
        y+=96
    text(image,(104,y+40),sub,29,color=MUTED)

def scene(index, t, a):
    image=Image.new('RGB',(W,H),BG)
    d=ImageDraw.Draw(image)
    brand_corner(image)
    # A single mint stage places the real UI in the same visual language as the site.
    d.rounded_rectangle((713,177,1860,911),radius=60,fill='#e5f2ec')
    if index==0:
        image=Image.new('RGB',(W,H),BG)
        v=ease(t/1.0)
        paste(image,a['icon'],(845,167+28*(1-v)))
        text(image,(960,464),'GlideMouse',112,bold=True,anchor='mm')
        text(image,(960,580),'Mouse controls for your Mac.',51,color=MUTED,anchor='mm')
        text(image,(960,934),'Made for everyday Mac controls.',27,color=MUTED,anchor='mm')
    elif index==1:
        title(image,['Set actions','for your','buttons.'],'Switch desktops. Show your windows.',t/6)
        x=737+20*(1-ease(t/.8));y=266-9*min(t/6,1)
        paste(image,a['buttons'],(x,y))
        # Focus outlines annotate the capture; they never simulate a hardware action.
        if 1<t<5.7:
            alpha=ease((t-1)/.3)
            ox=x+35;oy=y+54
            d.rounded_rectangle((ox+545,oy+175,ox+1038,oy+233),radius=13,outline=BLUE,width=3)
        text(image,(1280,851),'Desktop left  /  Desktop right  /  Mission Control',26,color=MUTED,anchor='mm')
    elif index==2:
        title(image,['Click once.','Double click.','Hold.'],'Set an action for each press.',t/5)
        paste(image,a['gestures'],(730,231-9*min(t/5,1)))
        paste(image,a['actions'],(1365+14*(1-ease(t/.9)),289))
        # Use the actual segmented control as the focal point, without selecting it.
        pos=min(2,int(max(0,t-1)/1.2))
        gx=730+35+(18+pos*101)*630/391;gy=231-9*min(t/5,1)+54+66*630/391
        if t>1:d.rounded_rectangle((gx-4,gy-3,gx+102*630/391,gy+32*630/391),radius=14,outline=BLUE,width=3)
    elif index==3:
        title(image,['Adjust your','scrolling.'],'Choose the speed and direction.',t/6)
        paste(image,a['scroll'],(720,271-10*min(t/6,1)))
        text(image,(1300,850),'Standard     Smooth     Custom',31,color=BLUE,anchor='mm')
        d.line((882,900,1720,900),fill='#c5d9d1',width=4)
        xx=882+838*ease((t-.6)/4.6)
        d.ellipse((xx-9,891,xx+9,909),fill=BLUE)
    elif index==4:
        title(image,['Settings for','each app.'],'Use defaults or set an app-specific action.',t/6)
        paste(image,a['profiles'],(750,215-10*min(t/6,1)))
        text(image,(1300,852),'Defaults for every app. Back and Forward in Safari.',30,color=MUTED,anchor='mm')
    else:
        image=Image.new('RGB',(W,H),BG)
        paste(image,a['icon'],(845,116))
        text(image,(960,432),'GlideMouse',104,bold=True,anchor='mm')
        text(image,(960,546),'Buttons, scrolling and app settings.',43,color=MUTED,anchor='mm')
        d=ImageDraw.Draw(image)
        d.rounded_rectangle((655,643,1265,747),radius=22,fill=BLUE)
        text(image,(960,693),'Download for macOS',39,color='white',bold=True,anchor='mm')
        text(image,(960,830),'minnkhantthuu.github.io/GlideMouse',29,color=MUTED,anchor='mm')
        text(image,(960,935),'English  ·  Myanmar  ·  Chinese',25,color=MUTED,anchor='mm')
    return image

def render():
    OUT.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True)
    a=assets()
    starts=[0,3,9,14,20,26]
    music=soundtrack()
    destination=OUT/'glidemouse-intro.mp4'
    ffmpeg=shutil.which('ffmpeg')
    if not ffmpeg:raise SystemExit('FFmpeg is required')
    command=[ffmpeg,'-y','-hide_banner','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r',str(FPS),'-i','pipe:0','-i',str(music),'-map','0:v:0','-map','1:a:0','-c:v','libx264','-preset','veryfast','-crf','19','-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-ar','48000','-ac','2','-t',str(SECONDS),'-movflags','+faststart',str(destination)]
    process=subprocess.Popen(command,stdin=subprocess.PIPE)
    for frame in range(FPS*SECONDS):
        t=frame/FPS
        index=max(i for i,start in enumerate(starts) if start<=t)
        image=scene(index,t-starts[index],a)
        if index and t-starts[index]<.4:
            previous=scene(index-1,starts[index]-starts[index-1],a)
            image=Image.blend(previous,image,ease((t-starts[index])/.4))
        if t<.45:image=Image.blend(Image.new('RGB',(W,H),BG),image,ease(t/.45))
        process.stdin.write(image.tobytes())
        if frame%150==0:print(f'Rendered {t:.0f}s / {SECONDS}s',flush=True)
    process.stdin.close()
    if process.wait():raise SystemExit('FFmpeg render failed')
    scene(0,2,a).resize((1280,720),Image.Resampling.LANCZOS).save(OUT/'poster.jpg',quality=92)
    times=[1.8,6,11.5,17,23,29]
    sheet=Image.new('RGB',(960,810),'white')
    for i,t in enumerate(times):
        ix=max(j for j,start in enumerate(starts) if start<=t)
        shot=scene(ix,t-starts[ix],a).resize((480,270),Image.Resampling.LANCZOS)
        sheet.paste(shot,((i%2)*480,(i//2)*270))
    sheet.save(WORK/'contact-sheet.jpg',quality=95)
    print(destination,flush=True)

if __name__=='__main__':render()
