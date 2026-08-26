package com.myaaptha.domain.person;import java.time.Instant;import java.util.List;
public final class PersonDtos {private PersonDtos(){}
 public record Record(String nickname,String contactPhone,String contactEmail,String address,String city,String country,String occupation,String dateOfBirth,String marriageDate,String dateOfDeath,String importantDates,String notes){}
 public record Memory(Long id,String title,String note,String mediaUrl,String mediaName,String mediaType,Long mediaSize,Instant createdAt){}
 public record Profile(Long id,String displayName,String profilePhoto,String location,String gender,String bio,String employer,String jobTitle,String institution,String managedCategory,String dateOfBirth,String dateOfDeath,String managedBiography,boolean managedByMe,Record privateRecord,List<Memory> memories){}
}
