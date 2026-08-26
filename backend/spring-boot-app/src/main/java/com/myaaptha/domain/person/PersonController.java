package com.myaaptha.domain.person;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.myaaptha.domain.person.dto.CreatePersonRequest;
import com.myaaptha.domain.person.dto.PersonDto;

@RestController
@RequestMapping("/api/people")
public class PersonController {
  private final PersonService personService;

  public PersonController(PersonService personService) {
    this.personService = personService;
  }

  @GetMapping
  public List<PersonDto> listPeople() {
    return personService.listPeople();
  }

  @GetMapping("/{id}")
  public ResponseEntity<PersonDto> getPerson(@PathVariable Long id) {
    try {
      return ResponseEntity.ok(personService.getPerson(id));
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.notFound().build();
    }
  }

  @PostMapping
  public PersonDto createPerson(@RequestBody CreatePersonRequest request) {
    return personService.createPerson(request);
  }

  @PutMapping("/{id}")
  public ResponseEntity<PersonDto> updatePerson(@PathVariable Long id, @RequestBody CreatePersonRequest request) {
    try {
      return ResponseEntity.ok(personService.updatePerson(id, request));
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.notFound().build();
    }
  }

  @DeleteMapping("/{id}")
  public ResponseEntity<Void> deletePerson(@PathVariable Long id) {
    try {
      personService.deletePerson(id);
      return ResponseEntity.noContent().build();
    } catch (IllegalArgumentException ex) {
      return ResponseEntity.notFound().build();
    }
  }
}
