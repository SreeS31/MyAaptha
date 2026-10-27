// Browser checks provide quick feedback; the server independently validates and scans.
export const blockedUploadExtensions = new Set(['exe','dll','com','scr','msi','msp','bat','cmd','ps1','psm1','vbs','vbe','js','jse','jar','war','class','sh','bash','zsh','php','phtml','asp','aspx','cgi','pl','py','rb','html','htm','hta','svg','apk','ipa','dmg','iso','img','deb','rpm','reg','lnk','url','scf','cpl','sys','drv','ocx','cab','appx','appxbundle','xll','doc','xls','ppt','docm','dotm','xlsm','xltm','pptm','potm','ppam','sldm']);
export const allowedUploadExtensions = new Set(['jpg','jpeg','jfif','png','webp','gif','bmp','tif','tiff','avif','heic','heif','ico','psd','dng','cr2','nef','arw','mp3','m4a','aac','wav','flac','ogg','oga','opus','amr','aif','aiff','mid','midi','mp4','m4v','mov','avi','mkv','webm','mpeg','mpg','ogv','3gp','3g2','flv','pdf','txt','csv','vcf','docx','xlsx','pptx','glb','gltf','obj','stl','fbx','3mf','dae','ply','usdz','blend']);
export const attachmentAccept=Array.from(allowedUploadExtensions,e=>`.${e}`).join(',');
export function validateUploadMetadata(file:Pick<File,'name'|'size'>){
 const parts=file.name.toLowerCase().split('.');
 if(file.name.length>255||/[\u0000-\u001f\u007f:\u202a-\u202e\u2066-\u2069]/.test(file.name)||parts.length<2||parts.slice(1).some(p=>blockedUploadExtensions.has(p))||!allowedUploadExtensions.has(parts[parts.length-1]))throw new Error('Unsupported attachment. Choose a PDF, DOCX, spreadsheet, text, image, audio or video file. Executables, scripts and macro files are blocked.');
 if(!file.size||file.size>25*1024*1024)throw new Error('Files must be non-empty and 25 MB or smaller.');
}
export async function validateUpload(file:File){
 validateUploadMetadata(file);
 const bytes=new Uint8Array(await file.slice(0,8192).arrayBuffer());
 const begins=(values:number[])=>values.every((v,i)=>bytes[i]===v);
 const text=new TextDecoder('latin1').decode(bytes);
 if(begins([77,90])||begins([127,69,76,70])||text.includes('EICAR-STANDARD-ANTIVIRUS-TEST-FILE'))throw new Error('Unsafe attachment detected. This file cannot be uploaded.');
 const ext=file.name.split('.').pop()!.toLowerCase();
 const signatures:Record<string,number[]>={pdf:[37,80,68,70,45],png:[137,80,78,71,13,10,26,10],jpg:[255,216,255],jpeg:[255,216,255],docx:[80,75,3,4],xlsx:[80,75,3,4],pptx:[80,75,3,4]};
 if(signatures[ext]&&!begins(signatures[ext]))throw new Error('File contents do not match the file extension.');
}
export async function validateUploadForm(body:FormData){
 const files=Array.from(body.values()).filter((value):value is File=>typeof value!=='string');
 if(files.length>10)throw new Error('Upload at most 10 files at a time.');
 for(const file of files)await validateUpload(file);
}
