package com.myaaptha.platform.media;

import java.nio.charset.StandardCharsets;
import java.io.ByteArrayInputStream;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

@Component
public class BasicMediaScanner implements MediaScanner {
  private static final long MAX_BYTES=25L*1024*1024;
  private static final Set<String> BLOCKED=Set.of("exe","dll","com","scr","msi","msp","bat","cmd","ps1","psm1","vbs","vbe","js","jse","jar","war","class","sh","bash","zsh","php","phtml","asp","aspx","cgi","pl","py","rb","html","htm","hta","svg","apk","ipa","dmg","iso","img","deb","rpm","reg","lnk","url","scf","cpl","sys","drv","ocx","cab","appx","appxbundle","xll","docm","dotm","xlsm","xltm","pptm","potm","ppam","sldm");
  private static final Set<String> ALLOWED=Set.of("jpg","jpeg","jfif","png","webp","gif","bmp","tif","tiff","avif","heic","heif","ico","psd","dng","cr2","nef","arw","mp3","m4a","aac","wav","flac","ogg","oga","opus","amr","aif","aiff","mid","midi","mp4","m4v","mov","avi","mkv","webm","mpeg","mpg","ogv","3gp","3g2","flv","pdf","txt","csv","vcf","docx","xlsx","pptx","glb","gltf","obj","stl","fbx","3mf","dae","ply","usdz","blend");
  public void assertClean(byte[] bytes,String name,String type){
    if(bytes==null||bytes.length==0||bytes.length>MAX_BYTES)reject("The file is empty or exceeds the 25 MB security limit");
    String safeName=name==null?"":name.replace('\\','/');
    safeName=safeName.substring(safeName.lastIndexOf('/')+1);
    if(safeName.isBlank()||safeName.length()>255||safeName.chars().anyMatch(c->c<32||c==127))reject("The file name is invalid");
    String[] parts=safeName.toLowerCase(Locale.ROOT).split("\\.");
    if(parts.length<2)reject("Files must have a supported extension");
    for(int i=1;i<parts.length;i++)if(BLOCKED.contains(parts[i]))reject("Executable, script, macro, and active-content files are not allowed");
    String extension=parts[parts.length-1];
    if(!ALLOWED.contains(extension))reject("This file type is not allowed");
    validateMime(type,extension);
    String sample=new String(bytes,0,Math.min(bytes.length,8192),StandardCharsets.ISO_8859_1);
    String lower=sample.toLowerCase(Locale.ROOT);
    if(sample.contains("EICAR-STANDARD-ANTIVIRUS-TEST-FILE")||starts(bytes,0x4d,0x5a)||starts(bytes,0x7f,0x45,0x4c,0x46)||starts(bytes,0xca,0xfe,0xba,0xbe)||starts(bytes,0xfe,0xed,0xfa,0xce)||starts(bytes,0xcf,0xfa,0xed,0xfe)||lower.startsWith("#!")||lower.contains("<?php")||lower.contains("<script")||lower.contains("javascript:")||lower.contains("vbscript:")||lower.contains("<!entity")||lower.matches("(?s).*on(load|error|click)\\s*=.*"))reject("The file was rejected by the malware scan");
    if("pdf".equals(extension)&&(lower.contains("/javascript")||lower.contains("/js ")||lower.contains("/openaction")||lower.contains("/launch")||lower.contains("/embeddedfile")||lower.contains("/richmedia")))reject("PDF files containing active or embedded content are not allowed");
    validateSignature(bytes,extension);
    if(starts(bytes,0x50,0x4b,0x03,0x04))scanArchive(bytes,extension);
  }
  private void validateSignature(byte[] b,String ext){boolean valid=switch(ext){case "jpg","jpeg","jfif"->starts(b,0xff,0xd8,0xff);case "png"->starts(b,0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a);case "gif"->ascii(b,0,"GIF87a")||ascii(b,0,"GIF89a");case "bmp"->ascii(b,0,"BM");case "webp"->b.length>12&&ascii(b,0,"RIFF")&&ascii(b,8,"WEBP");case "mp3"->ascii(b,0,"ID3")||(b.length>1&&(b[0]&255)==255&&(b[1]&224)==224);case "wav"->b.length>12&&ascii(b,0,"RIFF")&&ascii(b,8,"WAVE");case "flac"->ascii(b,0,"fLaC");case "ogg","oga","opus","ogv"->ascii(b,0,"OggS");case "webm","mkv"->starts(b,0x1a,0x45,0xdf,0xa3);case "mp4","m4v","mov","m4a","3gp","3g2"->b.length>12&&ascii(b,4,"ftyp");case "pdf"->ascii(b,0,"%PDF-");case "docx","xlsx","pptx","3mf","usdz"->starts(b,0x50,0x4b,0x03,0x04);case "glb"->ascii(b,0,"glTF");default->true;};if(!valid)reject("File contents do not match the file extension");}
  private void validateMime(String supplied,String ext){if(supplied==null||supplied.isBlank()||"application/octet-stream".equalsIgnoreCase(supplied))return;String type=supplied.toLowerCase(Locale.ROOT);boolean valid=switch(ext){case "jpg","jpeg","jfif"->type.equals("image/jpeg");case "png"->type.equals("image/png");case "gif"->type.equals("image/gif");case "webp"->type.equals("image/webp");case "pdf"->type.equals("application/pdf");case "docx"->type.equals("application/vnd.openxmlformats-officedocument.wordprocessingml.document");case "xlsx"->type.equals("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");case "pptx"->type.equals("application/vnd.openxmlformats-officedocument.presentationml.presentation");case "csv"->Set.of("text/csv","application/csv","text/plain","application/vnd.ms-excel").contains(type);case "vcf"->Set.of("text/vcard","text/x-vcard","text/plain").contains(type);default->!type.contains("javascript")&&!type.contains("html")&&!type.contains("executable")&&!type.contains("x-msdownload");};if(!valid)reject("The declared file type does not match its extension");}
  private void scanArchive(byte[] bytes,String extension){try(var input=new ZipInputStream(new ByteArrayInputStream(bytes))){int entries=0;long expanded=0;boolean officeMarker=false;Set<String> names=new HashSet<>();ZipEntry entry;byte[] buffer=new byte[8192];while((entry=input.getNextEntry())!=null){String name=entry.getName().replace('\\','/').toLowerCase(Locale.ROOT);if(++entries>5000||name.contains("../")||name.startsWith("/")||name.contains("/vba")||name.endsWith("vbaproject.bin")||name.endsWith(".exe")||name.endsWith(".dll")||name.endsWith(".js")||name.endsWith(".class")||!names.add(name))reject("The archive contains unsafe content");if(name.equals("[content_types].xml"))officeMarker=true;int read;while((read=input.read(buffer))>0){expanded+=read;if(expanded>250L*1024*1024||expanded>Math.max(10L*1024*1024,bytes.length*100L))reject("The archive expands beyond the security limit");}}if(Set.of("docx","xlsx","pptx").contains(extension)&&!officeMarker)reject("The Office document structure is invalid");}catch(ResponseStatusException exception){throw exception;}catch(Exception exception){reject("The archive is malformed or unsafe");}}
  private boolean ascii(byte[] bytes,int offset,String value){if(bytes.length<offset+value.length())return false;for(int i=0;i<value.length();i++)if((char)bytes[offset+i]!=value.charAt(i))return false;return true;}
  private void reject(String message){throw new ResponseStatusException(HttpStatus.BAD_REQUEST,message);}
  private boolean starts(byte[] bytes,int... signature){if(bytes.length<signature.length)return false;for(int i=0;i<signature.length;i++)if((bytes[i]&255)!=signature[i])return false;return true;}
}
