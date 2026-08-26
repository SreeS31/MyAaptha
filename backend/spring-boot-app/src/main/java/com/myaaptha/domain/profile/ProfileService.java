package com.myaaptha.domain.profile;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;
import com.myaaptha.domain.profile.dto.UserProfileDto;
import com.myaaptha.domain.profile.model.UserProfileEntity;
import com.myaaptha.domain.user.UserRepository;
import com.myaaptha.domain.user.model.UserEntity;

@Service @Transactional
public class ProfileService {
  private final UserProfileRepository profiles; private final UserRepository users;
  private final ProfileMediaStorage storage;
  public ProfileService(UserProfileRepository profiles, UserRepository users,ProfileMediaStorage storage){this.profiles=profiles;this.users=users;this.storage=storage;}
  @Transactional(readOnly=true) public UserProfileDto get(Long userId){return dto(user(userId),profiles.findById(userId).orElseGet(()->blank(userId)));}
  public UserProfileDto save(Long userId,UserProfileDto d){
    UserEntity u=user(userId); u.setFirstName(clean(d.firstName()));u.setSurname(clean(d.surname()));u.setEmail(clean(d.email()));u.setLocation(clean(d.location()));users.save(u);
    UserProfileEntity p=profiles.findById(userId).orElseGet(()->blank(userId));
    p.setDateOfBirth(clean(d.dateOfBirth()));p.setGender(clean(d.gender()));p.setBio(clean(d.bio()));p.setAddressLine1(clean(d.addressLine1()));p.setAddressLine2(clean(d.addressLine2()));p.setCity(clean(d.city()));p.setState(clean(d.state()));p.setPostalCode(clean(d.postalCode()));p.setCountry(clean(d.country()));
    p.setAlternatePhone(clean(d.alternatePhone()));p.setWebsite(clean(d.website()));p.setWhatsapp(clean(d.whatsapp()));p.setLinkedin(clean(d.linkedin()));p.setFacebook(clean(d.facebook()));p.setInstagram(clean(d.instagram()));p.setXHandle(clean(d.xHandle()));
    p.setHighestQualification(clean(d.highestQualification()));p.setInstitution(clean(d.institution()));p.setFieldOfStudy(clean(d.fieldOfStudy()));p.setGraduationYear(clean(d.graduationYear()));p.setEmploymentStatus(clean(d.employmentStatus()));p.setEmployer(clean(d.employer()));p.setJobTitle(clean(d.jobTitle()));p.setIndustry(clean(d.industry()));p.setWorkLocation(clean(d.workLocation()));p.setHobbies(clean(d.hobbies()));
    p.setProfilePhoto(d.profilePhoto());p.getPhotos().clear();List<String> gallery=d.photos()==null?List.of():d.photos();if(gallery.size()>8)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Maximum 8 gallery photos");p.getPhotos().addAll(gallery);return dto(u,profiles.save(p));
  }
  public UserProfileDto uploadProfilePhoto(Long userId,org.springframework.web.multipart.MultipartFile file){UserEntity u=user(userId);UserProfileEntity p=profiles.findById(userId).orElseGet(()->blank(userId));storage.delete(p.getProfilePhoto());p.setProfilePhoto(storage.store(userId,file));return dto(u,profiles.save(p));}
  public UserProfileDto removeProfilePhoto(Long userId){UserEntity u=user(userId);UserProfileEntity p=profiles.findById(userId).orElseGet(()->blank(userId));storage.delete(p.getProfilePhoto());p.setProfilePhoto(null);return dto(u,profiles.save(p));}
  public UserProfileDto addGalleryPhoto(Long userId,org.springframework.web.multipart.MultipartFile file){UserEntity u=user(userId);UserProfileEntity p=profiles.findById(userId).orElseGet(()->blank(userId));if(p.getPhotos().size()>=8)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Maximum 8 gallery photos");p.getPhotos().add(storage.store(userId,file));return dto(u,profiles.save(p));}
  public UserProfileDto removeGalleryPhoto(Long userId,int index){UserEntity u=user(userId);UserProfileEntity p=profiles.findById(userId).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Profile not found"));if(index<0||index>=p.getPhotos().size())throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Photo not found");storage.delete(p.getPhotos().remove(index));return dto(u,profiles.save(p));}
  private UserEntity user(Long id){return users.findById(id).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"User not found"));}
  private UserProfileEntity blank(Long id){UserProfileEntity p=new UserProfileEntity();p.setUserId(id);return p;} private String clean(String s){return s==null||s.isBlank()?null:s.trim();}
  private UserProfileDto dto(UserEntity u,UserProfileEntity p){return new UserProfileDto(u.getFirstName(),u.getSurname(),u.getEmail(),u.getPhoneNumber(),u.getLocation(),p.getDateOfBirth(),p.getGender(),p.getBio(),p.getAddressLine1(),p.getAddressLine2(),p.getCity(),p.getState(),p.getPostalCode(),p.getCountry(),p.getAlternatePhone(),p.getWebsite(),p.getWhatsapp(),p.getLinkedin(),p.getFacebook(),p.getInstagram(),p.getXHandle(),p.getHighestQualification(),p.getInstitution(),p.getFieldOfStudy(),p.getGraduationYear(),p.getEmploymentStatus(),p.getEmployer(),p.getJobTitle(),p.getIndustry(),p.getWorkLocation(),p.getHobbies(),p.getProfilePhoto(),List.copyOf(p.getPhotos()));}
}
