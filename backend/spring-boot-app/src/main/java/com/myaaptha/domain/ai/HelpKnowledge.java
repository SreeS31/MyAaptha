package com.myaaptha.domain.ai;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.util.*;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

@Component
public class HelpKnowledge {
  public record Article(String id, String title, String path, String keywords, String content) {}
  private final List<Article> articles;
  private static final Set<String> STOP = Set.of("how","what","where","when","can","could","would","should","does","this","that","the","and","for","from","with","our","your","you","are","is","it","to","of","a","an","my","me","i","do","please","tell","about","website","application","app","myaaptha","not","or");
  public HelpKnowledge(ObjectMapper json) throws IOException {
    try (var input = new ClassPathResource("help/articles.json").getInputStream()) {
      articles = List.of(json.readValue(input, Article[].class));
    }
  }
  public List<Article> all() { return articles; }
  public List<Article> search(String question) {
    Set<String> words = new HashSet<>(Arrays.asList(question.toLowerCase(Locale.ROOT).split("[^\\p{L}\\p{N}]+")));
    words.removeAll(STOP); words.remove("");
    int best=articles.stream().mapToInt(a->score(a,words)).max().orElse(0);
    int threshold=Math.max(1,(best+1)/2);
    return articles.stream().filter(a -> score(a, words) >= threshold)
        .sorted(Comparator.<Article>comparingInt(a -> score(a, words)).reversed())
        .limit(3).toList();
  }
  private int score(Article article, Set<String> words) {
    Set<String> keywords = Set.of(article.keywords().split(" "));
    return (int) words.stream().filter(keywords::contains).count();
  }
}
