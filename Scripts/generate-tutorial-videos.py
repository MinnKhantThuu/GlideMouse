#!/usr/bin/env python3
"""Encode native tutorial captures with captions and optional local English speech."""
import argparse,json,subprocess,shutil
from pathlib import Path
from collections import defaultdict
parser=argparse.ArgumentParser()
parser.add_argument('scenes',type=Path)
parser.add_argument('--output',type=Path,default=Path('Docs/media/videos'))
args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=True)
work=Path('build/tutorial-video-parts');work.mkdir(parents=True,exist_ok=True)
rows=json.loads((args.scenes/'manifest.json').read_text());groups=defaultdict(list)
for row in rows:groups[(row['language'],row['topic'])].append(row)
def run(command):subprocess.run(command,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
def duration(file):return float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','default=noprint_wrappers=1:nokey=1',str(file)],text=True))
def timestamp(seconds):
 ms=round(seconds*1000);return f'{ms//3600000:02}:{ms//60000%60:02}:{ms//1000%60:02},{ms%1000:03}'
outputs=[]
for (lang,topic),scenes in groups.items():
 parts=[];captions=[];elapsed=0
 for row in scenes:
  stem=f"{lang}-{topic}-{row['step']}";part=work/(stem+'.mp4');image=args.scenes/row['image'];seconds=row['seconds']
  command=['ffmpeg','-y','-loglevel','error','-loop','1','-framerate','2','-i',str(image)]
  if lang=='en':
   voice=work/(stem+'.aiff');run(['say','-v','Samantha','-r','155','-o',str(voice),row['caption']]);seconds=max(seconds,duration(voice)+1.2)
   command+=['-i',str(voice),'-af','apad','-c:a','aac','-b:a','96k','-ar','48000','-ac','1']
  command+=['-t',str(seconds),'-vf','fps=24,format=yuv420p','-c:v','libx264','-preset','veryfast','-crf','21','-threads','2',str(part)]
  run(command);parts.append(part.resolve());actual=duration(part)
  captions.append(f"{row['step']}\n{timestamp(elapsed)} --> {timestamp(elapsed+actual)}\n{row['caption']}\n")
  elapsed+=actual
 listing=work/f'{lang}-{topic}.ffconcat';listing.write_text('ffconcat version 1.0\n'+''.join("file '"+str(p).replace("'","'\\''")+"'\n" for p in parts))
 target=args.output/f'{lang}-{topic}.mp4';run(['ffmpeg','-y','-loglevel','error','-f','concat','-safe','0','-i',str(listing),'-c','copy','-movflags','+faststart',str(target)])
 (args.output/f'{lang}-{topic}.srt').write_text('\n'.join(captions));shutil.copy2(args.scenes/scenes[0]['image'],args.output/f'{lang}-{topic}.png')
 outputs.append({'language':lang,'topic':topic,'title':scenes[0]['title'],'file':target.name,'seconds':round(duration(target),2),'bytes':target.stat().st_size,'narration':'local English text-to-speech' if lang=='en' else 'Myanmar captions, no narration','captureType':'native SwiftUI guided sample workflow; not a physical-input recording'})
 print(f"Encoded {target.name} ({elapsed:.1f}s)",flush=True)
(args.output/'manifest.json').write_text(json.dumps(outputs,ensure_ascii=False,indent=2)+'\n')
