package com.myaaptha.domain.profile;

import com.myaaptha.platform.media.MediaObjectStorage;
import com.myaaptha.platform.media.MediaAssetService;
import java.util.Set;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

@Service
public class ProfileMediaStorage {
  private static final Set<String> TYPES=Set.of("image/jpeg","image/png","image/webp");
  private final MediaObjectStorage storage; private final MediaAssetService assets; private final String publicBaseUrl;
  public ProfileMediaStorage(MediaObjectStorage storage,MediaAssetService assets,@Value("${myaaptha.storage.public-base-url:http://localhost:8080}") String base){this.storage=storage;this.assets=assets;publicBaseUrl=base.replaceAll("/$","");}
  public String store(Long ownerUserId,MultipartFile file){
    var asset=assets.store(ownerUserId,"PROFILE",file,TYPES,5L*1024*1024,"");return publicBaseUrl+"/api/profile/media/"+asset.key();
  }
  public Resource load(String name){return storage.load(name);}
  public void delete(String url){if(url==null||!url.contains("/api/profile/media/"))return;assets.delete(url.substring(url.lastIndexOf('/')+1));}
}
