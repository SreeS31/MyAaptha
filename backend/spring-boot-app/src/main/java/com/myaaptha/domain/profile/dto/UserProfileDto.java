package com.myaaptha.domain.profile.dto;
import java.util.List;
public record UserProfileDto(String firstName,String surname,String email,String phoneNumber,String location,
 String dateOfBirth,String gender,String bio,String addressLine1,String addressLine2,String city,String state,String postalCode,String country,
 String alternatePhone,String website,String whatsapp,String linkedin,String facebook,String instagram,String xHandle,
 String highestQualification,String institution,String fieldOfStudy,String graduationYear,String employmentStatus,String employer,String jobTitle,String industry,String workLocation,String hobbies,
 String profilePhoto,List<String> photos) {}
