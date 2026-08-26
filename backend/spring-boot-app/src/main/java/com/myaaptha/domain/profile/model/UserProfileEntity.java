package com.myaaptha.domain.profile.model;

import java.util.ArrayList;
import java.util.List;
import jakarta.persistence.*;

@Entity
@Table(name = "user_profiles")
public class UserProfileEntity {
  @Id @Column(name = "user_id") private Long userId;
  private String dateOfBirth; private String gender;
  @Column(columnDefinition = "TEXT") private String bio;
  private String addressLine1; private String addressLine2; private String city; private String state; private String postalCode; private String country;
  private String alternatePhone; private String website; private String whatsapp; private String linkedin; private String facebook; private String instagram; private String xHandle;
  private String highestQualification; private String institution; private String fieldOfStudy; private String graduationYear;
  private String employmentStatus; private String employer; private String jobTitle; private String industry; private String workLocation;
  @Column(columnDefinition = "TEXT") private String hobbies;
  @Column(columnDefinition = "TEXT") private String profilePhoto;
  @ElementCollection @CollectionTable(name="user_profile_photos", joinColumns=@JoinColumn(name="user_id"))
  @OrderColumn(name="photo_order") @Column(name="photo_data", columnDefinition="TEXT") private List<String> photos = new ArrayList<>();

  public Long getUserId(){return userId;} public void setUserId(Long v){userId=v;}
  public String getDateOfBirth(){return dateOfBirth;} public void setDateOfBirth(String v){dateOfBirth=v;} public String getGender(){return gender;} public void setGender(String v){gender=v;} public String getBio(){return bio;} public void setBio(String v){bio=v;}
  public String getAddressLine1(){return addressLine1;} public void setAddressLine1(String v){addressLine1=v;} public String getAddressLine2(){return addressLine2;} public void setAddressLine2(String v){addressLine2=v;} public String getCity(){return city;} public void setCity(String v){city=v;} public String getState(){return state;} public void setState(String v){state=v;} public String getPostalCode(){return postalCode;} public void setPostalCode(String v){postalCode=v;} public String getCountry(){return country;} public void setCountry(String v){country=v;}
  public String getAlternatePhone(){return alternatePhone;} public void setAlternatePhone(String v){alternatePhone=v;} public String getWebsite(){return website;} public void setWebsite(String v){website=v;} public String getWhatsapp(){return whatsapp;} public void setWhatsapp(String v){whatsapp=v;} public String getLinkedin(){return linkedin;} public void setLinkedin(String v){linkedin=v;} public String getFacebook(){return facebook;} public void setFacebook(String v){facebook=v;} public String getInstagram(){return instagram;} public void setInstagram(String v){instagram=v;} public String getXHandle(){return xHandle;} public void setXHandle(String v){xHandle=v;}
  public String getHighestQualification(){return highestQualification;} public void setHighestQualification(String v){highestQualification=v;} public String getInstitution(){return institution;} public void setInstitution(String v){institution=v;} public String getFieldOfStudy(){return fieldOfStudy;} public void setFieldOfStudy(String v){fieldOfStudy=v;} public String getGraduationYear(){return graduationYear;} public void setGraduationYear(String v){graduationYear=v;}
  public String getEmploymentStatus(){return employmentStatus;} public void setEmploymentStatus(String v){employmentStatus=v;} public String getEmployer(){return employer;} public void setEmployer(String v){employer=v;} public String getJobTitle(){return jobTitle;} public void setJobTitle(String v){jobTitle=v;} public String getIndustry(){return industry;} public void setIndustry(String v){industry=v;} public String getWorkLocation(){return workLocation;} public void setWorkLocation(String v){workLocation=v;}
  public String getHobbies(){return hobbies;} public void setHobbies(String v){hobbies=v;}
  public String getProfilePhoto(){return profilePhoto;} public void setProfilePhoto(String v){profilePhoto=v;} public List<String> getPhotos(){return photos;}
}
