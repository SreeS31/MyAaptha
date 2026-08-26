package com.myaaptha.domain.circle;

import com.myaaptha.platform.media.MediaObjectStorage;
import com.myaaptha.platform.media.MediaAssetService;
import java.util.Set;
import java.util.UUID;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

@Service
public class CircleMediaStorage {
  private static final Set<String> TYPES=Set.of("image/jpeg","image/png","image/webp","image/gif","image/bmp","image/tiff","image/avif","image/heic","image/heif","image/x-icon","image/svg+xml","image/vnd.adobe.photoshop","image/x-adobe-dng","image/x-canon-cr2","image/x-nikon-nef","image/x-sony-arw","model/gltf-binary","model/gltf+json","model/obj","model/stl","model/3mf","model/vnd.usdz+zip","model/vnd.collada+xml","application/vnd.autodesk.fbx","application/ply","application/x-blender","video/mp4","video/quicktime","video/x-msvideo","video/x-matroska","video/webm","video/mpeg","video/ogg","video/3gpp","video/3gpp2","video/x-flv","audio/mpeg","audio/mp3","audio/mp4","audio/x-m4a","audio/aac","audio/wav","audio/x-wav","audio/flac","audio/webm","audio/ogg","audio/opus","audio/amr","audio/aiff","audio/midi","application/pdf","text/plain","application/msword","application/vnd.openxmlformats-officedocument.wordprocessingml.document","application/vnd.ms-excel","application/vnd.openxmlformats-officedocument.spreadsheetml.sheet","application/vnd.ms-powerpoint","application/vnd.openxmlformats-officedocument.presentationml.presentation");
  private final MediaObjectStorage storage; private final MediaAssetService assets;
  public CircleMediaStorage(MediaObjectStorage storage,MediaAssetService assets){this.storage=storage;this.assets=assets;}
  public StoredMedia store(Long ownerUserId,MultipartFile file){
    var asset=assets.store(ownerUserId,"CONVERSATION",file,TYPES,25L*1024*1024,"circles/");String key=asset.key().substring("circles/".length());return new StoredMedia(key,asset.name(),asset.type(),asset.size());
  }
  public Resource load(String key){return storage.load("circles/"+key);}
  public void delete(String key){if(key!=null)assets.delete("circles/"+key);}
  public record StoredMedia(String key,String name,String type,long size){}
}
