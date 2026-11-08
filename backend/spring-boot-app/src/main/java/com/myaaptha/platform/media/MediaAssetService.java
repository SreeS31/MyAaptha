package com.myaaptha.platform.media;

import java.nio.file.Paths;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Set;
import java.util.UUID;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import javax.imageio.ImageIO;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

@Service
public class MediaAssetService {
  @org.springframework.beans.factory.annotation.Autowired private com.myaaptha.platform.state.ScheduledJobLock jobLock;
  @org.springframework.beans.factory.annotation.Autowired private UploadPolicyService policies;
  private final MediaObjectStorage storage; private final MediaAssetRepository assets; private final MediaScanner scanner; private final long quotaBytes;
  public MediaAssetService(MediaObjectStorage storage,MediaAssetRepository assets,MediaScanner scanner,@Value("${myaaptha.storage.user-quota-bytes:1073741824}") long quotaBytes){this.storage=storage;this.assets=assets;this.scanner=scanner;this.quotaBytes=quotaBytes;}
  @Transactional
  public StoredAsset store(Long owner,String category,MultipartFile file,Set<String> allowed,long maximumBytes,String keyPrefix){
    var policy=policies.lockPolicy(owner);
    maximumBytes=Math.min(maximumBytes,policy.uploadBytes());
    var expiresAt=policies.expiry(policy);
    if(file==null||file.isEmpty())throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose a file to upload");String original=file.getOriginalFilename()==null?"file":Paths.get(file.getOriginalFilename()).getFileName().toString();validateName(original);String type=resolvedType(file.getContentType(),original);if(file.getSize()>maximumBytes)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"File exceeds the "+(maximumBytes/1024/1024)+" MB limit");if(!allowed.contains(type))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"This file type is not supported");if(assets.activeBytes(owner)+file.getSize()>policy.storageBytes())throw new ResponseStatusException(HttpStatus.PAYLOAD_TOO_LARGE,"Your storage is full. Choose files to delete or upgrade your storage plan before uploading. Existing files are kept.");
    try{byte[] bytes=file.getBytes();validateSignature(bytes,type);scanner.assertClean(bytes,original,type);String extension=extension(original);String key=keyPrefix+UUID.randomUUID()+extension;cleanupOnRollback(key);storage.put(key,bytes,type,original);MediaAssetEntity asset=new MediaAssetEntity();asset.setOwnerUserId(owner);asset.setStorageKey(key);asset.setCategory(category);asset.setExpiresAt(expiresAt);asset.setOriginalName(original);asset.setContentType(type);asset.setSizeBytes(bytes.length);asset.setSha256(HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes)));if(Set.of("image/jpeg","image/png").contains(type)){byte[] thumbnail=thumbnail(bytes);if(thumbnail!=null){String thumbnailKey=keyPrefix+"thumbs/"+UUID.randomUUID()+".jpg";cleanupOnRollback(thumbnailKey);storage.put(thumbnailKey,thumbnail,"image/jpeg","thumbnail.jpg");asset.setThumbnailKey(thumbnailKey);asset.setSizeBytes(bytes.length+thumbnail.length);if(assets.activeBytes(owner)+asset.getSizeBytes()>policy.storageBytes())throw new ResponseStatusException(HttpStatus.PAYLOAD_TOO_LARGE,"Storage includes generated previews. Choose files to delete or upgrade your storage plan. Existing files are kept.");}}assets.saveAndFlush(asset);return new StoredAsset(key,original,type,bytes.length);}catch(ResponseStatusException e){throw e;}catch(Exception e){throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR,"Media upload failed");}
  }
  @Transactional public void delete(String key){if(key==null)return;var asset=assets.findByStorageKeyAndDeletedAtIsNull(key);storage.delete(key);asset.ifPresent(value->{if(value.getThumbnailKey()!=null)storage.delete(value.getThumbnailKey());value.setDeletedAt(Instant.now());assets.save(value);});}
  @Scheduled(cron="${myaaptha.storage.retention-cleanup-cron:0 * * * * *}") @Transactional public void cleanupExpired(){if(!jobLock.acquire("media-retention"))return;for(var asset:assets.findTop100ByExpiresAtBeforeAndDeletedAtIsNullOrderByExpiresAt(Instant.now()))delete(asset.getStorageKey());}
  private void cleanupOnRollback(String key){
    if(org.springframework.transaction.support.TransactionSynchronizationManager.isSynchronizationActive())
      org.springframework.transaction.support.TransactionSynchronizationManager.registerSynchronization(new org.springframework.transaction.support.TransactionSynchronization(){
        @Override public void afterCompletion(int status){if(status==STATUS_ROLLED_BACK)try{storage.delete(key);}catch(RuntimeException ignored){}}
      });
  }
  public void assertAvailable(String key){
    var asset=assets.findByStorageKey(key);
    if(asset.isPresent()&&(asset.get().getDeletedAt()!=null||(asset.get().getExpiresAt()!=null&&!asset.get().getExpiresAt().isAfter(Instant.now()))))throw new ResponseStatusException(HttpStatus.GONE,"This attachment has expired or was removed");
  }
  public long usage(Long owner){return assets.activeBytes(owner);}
  private void validateSignature(byte[] bytes,String type){boolean valid=switch(type){case "image/jpeg"->starts(bytes,0xff,0xd8,0xff);case "image/png"->starts(bytes,0x89,0x50,0x4e,0x47);case "image/gif"->ascii(bytes,0,"GIF87a")||ascii(bytes,0,"GIF89a");case "image/bmp"->ascii(bytes,0,"BM");case "image/webp"->bytes.length>12&&ascii(bytes,0,"RIFF")&&ascii(bytes,8,"WEBP");case "audio/mpeg","audio/mp3"->ascii(bytes,0,"ID3")||(bytes.length>1&&(bytes[0]&255)==255&&((bytes[1]&224)==224));case "audio/wav","audio/x-wav"->bytes.length>12&&ascii(bytes,0,"RIFF")&&ascii(bytes,8,"WAVE");case "audio/flac"->ascii(bytes,0,"fLaC");case "audio/ogg","audio/opus","video/ogg"->ascii(bytes,0,"OggS");case "video/webm","audio/webm"->starts(bytes,0x1a,0x45,0xdf,0xa3);case "video/mp4","audio/mp4","video/quicktime"->bytes.length>12&&ascii(bytes,4,"ftyp");case "model/gltf-binary"->ascii(bytes,0,"glTF");case "application/pdf"->bytes.length>5&&ascii(bytes,0,"%PDF-");default->true;};if(!valid)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"File contents do not match the selected file type");}
  private boolean ascii(byte[] bytes,int offset,String value){if(bytes.length<offset+value.length())return false;for(int i=0;i<value.length();i++)if((char)bytes[offset+i]!=value.charAt(i))return false;return true;}
  private boolean starts(byte[] bytes,int... signature){if(bytes.length<signature.length)return false;for(int i=0;i<signature.length;i++)if((bytes[i]&255)!=signature[i])return false;return true;}
  private void validateName(String name){if(name.isBlank()||name.length()>255||name.chars().anyMatch(value->value<32))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"The file name is invalid");String lower=name.toLowerCase();if(lower.matches(".*\\.(exe|dll|com|scr|msi|bat|cmd|ps1|vbs|js|jar|war|sh|php|html?|apk|ipa|dmg|iso)(\\.|$).*"))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Executable or script files are not allowed");}
  private String extension(String name){if(!name.contains("."))return "";return name.substring(name.lastIndexOf('.')).toLowerCase().replaceAll("[^a-z0-9.]","");}
  private String resolvedType(String supplied,String name){if(supplied!=null&&!supplied.isBlank()&&!"application/octet-stream".equalsIgnoreCase(supplied))return supplied.toLowerCase();String ext=extension(name);return switch(ext){case ".pdf"->"application/pdf";case ".txt"->"text/plain";case ".csv"->"text/csv";case ".vcf"->"text/vcard";case ".docx"->"application/vnd.openxmlformats-officedocument.wordprocessingml.document";case ".xlsx"->"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";case ".pptx"->"application/vnd.openxmlformats-officedocument.presentationml.presentation";case ".jpg",".jpeg",".jfif"->"image/jpeg";case ".png"->"image/png";case ".webp"->"image/webp";case ".gif"->"image/gif";case ".bmp"->"image/bmp";case ".tif",".tiff"->"image/tiff";case ".avif"->"image/avif";case ".heic"->"image/heic";case ".heif"->"image/heif";case ".ico"->"image/x-icon";case ".svg"->"image/svg+xml";case ".psd"->"image/vnd.adobe.photoshop";case ".dng"->"image/x-adobe-dng";case ".cr2"->"image/x-canon-cr2";case ".nef"->"image/x-nikon-nef";case ".arw"->"image/x-sony-arw";case ".mp3"->"audio/mpeg";case ".m4a"->"audio/mp4";case ".aac"->"audio/aac";case ".wav"->"audio/wav";case ".flac"->"audio/flac";case ".ogg",".oga"->"audio/ogg";case ".opus"->"audio/opus";case ".amr"->"audio/amr";case ".aif",".aiff"->"audio/aiff";case ".mid",".midi"->"audio/midi";case ".mp4",".m4v"->"video/mp4";case ".mov"->"video/quicktime";case ".avi"->"video/x-msvideo";case ".mkv"->"video/x-matroska";case ".webm"->"video/webm";case ".mpeg",".mpg"->"video/mpeg";case ".ogv"->"video/ogg";case ".3gp"->"video/3gpp";case ".3g2"->"video/3gpp2";case ".flv"->"video/x-flv";case ".glb"->"model/gltf-binary";case ".gltf"->"model/gltf+json";case ".obj"->"model/obj";case ".stl"->"model/stl";case ".3mf"->"model/3mf";case ".usdz"->"model/vnd.usdz+zip";case ".fbx"->"application/vnd.autodesk.fbx";case ".dae"->"model/vnd.collada+xml";case ".ply"->"application/ply";case ".blend"->"application/x-blender";default->"application/octet-stream";};}
  private byte[] thumbnail(byte[] bytes){try{try(var input=ImageIO.createImageInputStream(new ByteArrayInputStream(bytes))){var readers=ImageIO.getImageReaders(input);if(!readers.hasNext())return null;var reader=readers.next();try{reader.setInput(input);if((long)reader.getWidth(0)*reader.getHeight(0)>20000000L)return null;}finally{reader.dispose();}}BufferedImage source=ImageIO.read(new ByteArrayInputStream(bytes));if(source==null)return null;double scale=Math.min(1d,320d/Math.max(source.getWidth(),source.getHeight()));int width=Math.max(1,(int)(source.getWidth()*scale)),height=Math.max(1,(int)(source.getHeight()*scale));BufferedImage target=new BufferedImage(width,height,BufferedImage.TYPE_INT_RGB);Graphics2D graphics=target.createGraphics();graphics.setRenderingHint(RenderingHints.KEY_INTERPOLATION,RenderingHints.VALUE_INTERPOLATION_BICUBIC);graphics.drawImage(source,0,0,width,height,null);graphics.dispose();ByteArrayOutputStream output=new ByteArrayOutputStream();ImageIO.write(target,"jpg",output);return output.toByteArray();}catch(Exception ignored){return null;}}
  public record StoredAsset(String key,String name,String type,long size){}
}
