import 'dart:convert';
import 'dart:math';

List<String> _unique(Iterable<String> values) =>
    values.map((v) => v.trim()).where((v) => v.isNotEmpty).toSet().toList();

List<Map<String, dynamic>> parseContactCsv(String text) {
  text = text.replaceFirst('\uFEFF', '');
  final rows = <List<String>>[];
  var row = <String>[], cell = '', quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (c == '"') {
      if (quoted && i + 1 < text.length && text[i + 1] == '"') {
        cell += '"';
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (c == ',' && !quoted) {
      row.add(cell);
      cell = '';
    } else if ((c == '\n' || c == '\r') && !quoted) {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell);
      if (row.any((v) => v.trim().isNotEmpty)) rows.add(row);
      row = [];
      cell = '';
    } else {
      cell += c;
    }
  }
  if (quoted) {
    throw const FormatException(
        'The CSV has an unclosed quoted field. Export it again.');
  }
  row.add(cell);
  if (row.any((v) => v.trim().isNotEmpty)) rows.add(row);
  if (rows.length < 2) return [];
  final headers = rows.first.map((v) => v.trim().toLowerCase()).toList();
  return rows
      .skip(1)
      .map((cells) {
        String pick(List<String> names) {
          final i = headers.indexWhere(names.contains);
          return i < 0 || i >= cells.length ? '' : cells[i].trim();
        }

        List<String> matching(String pattern) => _unique([
              for (var i = 0; i < min(headers.length, cells.length); i++)
                if (RegExp(pattern).hasMatch(headers[i]) &&
                    !RegExp('type|label').hasMatch(headers[i]))
                  cells[i]
            ]);
        final phones = matching('phone|mobile|tel'),
            emails = matching('e-?mail');
        var name = pick(['name', 'full name', 'display name']);
        if (name.isEmpty) {
          name = [
            pick(['first name', 'given name']),
            pick(['middle name', 'additional name']),
            pick(['last name', 'family name'])
          ].where((s) => s.isNotEmpty).join(' ');
        }
        if (name.isEmpty) name = phones.firstOrNull ?? emails.firstOrNull ?? '';
        return <String, dynamic>{
          'displayName': name,
          'phones': phones,
          'emails': emails,
          'organization': pick([
            'organization name',
            'organization 1 - name',
            'company',
            'organization'
          ]),
          'groups': _unique(pick(['labels', 'categories', 'group membership'])
              .split(RegExp(r' ::: |[;,]')))
        };
      })
      .where((c) => (c['displayName'] as String).isNotEmpty)
      .toList();
}

List<Map<String, dynamic>> parseContactVcard(String text) {
  text = text
      .replaceAll(RegExp(r'=\r?\n'), '')
      .replaceAll(RegExp(r'\r?\n[ \t]'), '');
  final result = <Map<String, dynamic>>[];
  for (final block in text.split(RegExp('END:VCARD', caseSensitive: false))) {
    if (!RegExp('BEGIN:VCARD', caseSensitive: false).hasMatch(block)) continue;
    var name = '', structured = '', organization = '';
    final phones = <String>[], emails = <String>[], groups = <String>[];
    for (final line in block.split(RegExp(r'\r?\n'))) {
      final colon = line.indexOf(':');
      if (colon < 0) continue;
      final header = line.substring(0, colon),
          key = header.split(';').first.split('.').last.toUpperCase();
      var value = line.substring(colon + 1);
      if (header.toUpperCase().contains('ENCODING=QUOTED-PRINTABLE')) {
        final bytes = <int>[];
        for (var i = 0; i < value.length; i++) {
          if (value[i] == '=' &&
              i + 2 < value.length &&
              RegExp(r'^[0-9A-Fa-f]{2}$')
                  .hasMatch(value.substring(i + 1, i + 3))) {
            bytes.add(int.parse(value.substring(i + 1, i + 3), radix: 16));
            i += 2;
          } else {
            bytes.addAll(utf8.encode(value[i]));
          }
        }
        value = utf8.decode(bytes, allowMalformed: true);
      }
      value = value
          .replaceAll(RegExp(r'\\[nN]'), ' ')
          .replaceAllMapped(RegExp(r'\\([,;\\])'), (m) => m[1]!)
          .trim();
      if (key == 'FN') name = value;
      if (key == 'N') {
        final parts = value.split(';');
        structured = [3, 1, 2, 0, 4]
            .where((i) => i < parts.length)
            .map((i) => parts[i])
            .where((s) => s.isNotEmpty)
            .join(' ');
      }
      if (key == 'TEL') {
        phones
            .add(value.replaceFirst(RegExp('^tel:', caseSensitive: false), ''));
      }
      if (key == 'EMAIL') {
        emails.add(
            value.replaceFirst(RegExp('^mailto:', caseSensitive: false), ''));
      }
      if (key == 'ORG') organization = value.replaceAll(';', ' ');
      if (key == 'CATEGORIES') groups.addAll(value.split(','));
    }
    result.add({
      'displayName': name.isNotEmpty
          ? name
          : structured.isNotEmpty
              ? structured
              : phones.firstOrNull ?? emails.firstOrNull ?? 'Unnamed contact',
      'phones': _unique(phones),
      'emails': _unique(emails),
      'organization': organization,
      'groups': _unique(groups)
    });
  }
  return result;
}

Future<Map<String, dynamic>> importContactBatches(
    List<Map<String, dynamic>> contacts,
    Future<Map<String, dynamic>> Function(List<Map<String, dynamic>>) save,
    void Function(int) progress,
    bool Function() cancelled) async {
  var added = 0, updated = 0, unchanged = 0, processed = 0;
  final organizationMessages = <String>{};
  for (var offset = 0;
      offset < contacts.length && !cancelled();
      offset += 100) {
    final batch = contacts.sublist(offset, min(offset + 100, contacts.length));
    final result = await save(batch);
    added += (result['added'] as num?)?.toInt() ?? 0;
    updated += (result['updated'] as num?)?.toInt() ?? 0;
    unchanged += (result['unchanged'] as num?)?.toInt() ?? 0;
    final organizationMessage = result['organizationMessage']?.toString() ?? '';
    if (organizationMessage.isNotEmpty) { organizationMessages.add(organizationMessage); }
    processed += batch.length;
    progress(processed);
  }
  return {
    'added': added,
    'updated': updated,
    'unchanged': unchanged,
    'processed': processed,
    'organizationMessage': organizationMessages.join(' ')
  };
}


String _circleKey(String value)=>value.trim().replaceAll(RegExp(r'\s+'),' ').toLowerCase();
bool _meaningfulLabel(String value)=>value.trim().isNotEmpty&&!RegExp(r'^\*?\s*(my contacts|all contacts|imported contacts)$',caseSensitive:false).hasMatch(value);
String _contactIdentity(Map<String,dynamic> c)=>jsonEncode([_circleKey('${c['displayName']}'),[...(c['phones'] as List)].cast<String>()..sort(),[...(c['emails'] as List)].map((e)=>_circleKey('$e')).toList()..sort()]);
List<Map<String,dynamic>> importCircleSuggestions(List<Map<String,dynamic>> contacts,List<String> existing){
 final savedNames={for(final name in existing)_circleKey(name):name};
 final groups=<String,Map<String,dynamic>>{};
 for(final contact in contacts.where((c)=>c['selected']==true)){
  for(final raw in (contact['circleNames'] as List).cast<String>()){
   final key=_circleKey(raw);if(key.isEmpty)continue;
   final saved=savedNames[key];
   final group=groups.putIfAbsent(key,()=>{'name':saved??raw.trim(),'existing':saved!=null,'contacts':<String>{}});
   (group['contacts'] as Set<String>).add(_contactIdentity(contact));
  }
 }
 return groups.values.map((g)=>{'name':g['name'],'existing':g['existing'],'count':(g['contacts'] as Set).length,'eligible':true}).toList()
  ..sort((a,b){final saved=(b['existing']==true?1:0)-(a['existing']==true?1:0);if(saved!=0)return saved;final count=(b['count'] as int)-(a['count'] as int);return count!=0?count:'${a['name']}'.compareTo('${b['name']}');});
}
List<Map<String,dynamic>> prepareContactReview(List<Map<String,dynamic>> input,List<String> existing){
 final savedNames={for(final name in existing)_circleKey(name):name};
 String canonical(String value)=>savedNames[_circleKey(value)]??value.trim().replaceAll(RegExp(r'\s+'),' ').substring(0,min(100,value.trim().replaceAll(RegExp(r'\s+'),' ').length));
 final usable=<Map<String,dynamic>>[];
 for(final row in input){
  final phones=(row['phones'] as List? ?? []).cast<String>().expand((p)=>p.split(RegExp(r' ::: |[;,]'))).map((p)=>p.trim().replaceFirst(RegExp(r'^tel:',caseSensitive:false),'').replaceAll(RegExp(r'[ ()\-.]'),'')).where((p)=>RegExp(r'^\+?[0-9]{7,15}$').hasMatch(p)).toSet().take(20).toList();
  final emails=(row['emails'] as List? ?? []).cast<String>().map((e)=>e.trim()).where((e)=>RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(e)).toSet().take(20).toList();
  final name='${row['displayName']??''}'.trim();
  if(phones.isEmpty&&emails.isEmpty&&(name.isEmpty||name.toLowerCase()=='unnamed contact'))continue;
  usable.add({...row,'displayName':name,'organization':'${row['organization']??''}'.trim(),'phones':phones,'emails':emails});
 }
 final explicit=_unique([...existing,...usable.expand((r)=>[...(r['groups'] as List? ?? []).cast<String>(),'${r['organization']}'])].where(_meaningfulLabel).map(canonical));
 final tags=<String,Map<String,dynamic>>{};
 for(final row in usable){
  final name='${row['displayName']}';
  final candidates=[...RegExp(r'#([\p{L}\p{N}_-]{2,40})',unicode:true).allMatches(name).map((m)=>m[1]!),...RegExp(r'\(([^()]{2,40})\)').allMatches(name).map((m)=>m[1]!),if(name.contains(' - '))name.split(' - ').last];
  if(RegExp('[a-z]').hasMatch(name)){candidates.addAll(RegExp(r'\b[A-Z][A-Z0-9]{2,}\b').allMatches(name).map((m)=>m[0]!));}
  for(final raw in candidates.where((v)=>RegExp(r'\p{L}',unicode:true).hasMatch(v)&&_meaningfulLabel(v))){
   final label=canonical(raw),key=_circleKey(label);final tag=tags.putIfAbsent(key,()=>{'name':label,'contacts':<String>{}});(tag['contacts'] as Set<String>).add(_contactIdentity(row));
  }
 }
 final candidates=_unique([...explicit,...tags.values.where((t)=>(t['contacts'] as Set).length>=2).map((t)=>'${t['name']}')]);
 final candidateIndex=<String,List<Map<String,dynamic>>>{};
 for(final name in candidates){final parts=_circleKey(name).split(RegExp(r'[^\p{L}\p{N}]+',unicode:true)).where((p)=>p.isNotEmpty).toList();if(parts.isNotEmpty)candidateIndex.putIfAbsent(parts.first,()=>[]).add({'name':name,'parts':parts});}
 final result=<Map<String,dynamic>>[];
 for(final row in usable){
  final words=_circleKey('${row['displayName']}').split(RegExp(r'[^\p{L}\p{N}]+',unicode:true)).where((p)=>p.isNotEmpty).toList();
  final wordSet=words.toSet();
  final matches=wordSet.expand((word)=>candidateIndex[word]??<Map<String,dynamic>>[]).where((c)=>(c['parts'] as List<String>).every(wordSet.contains)).map((c)=>'${c['name']}');
  final names=_unique([...(row['groups'] as List? ?? []).cast<String>(),'${row['organization']}',...matches].where(_meaningfulLabel).map(canonical)).take(20).toList();
  result.add({...row,'displayName':'${row['displayName']}'.isNotEmpty?row['displayName']:(row['phones'] as List).firstOrNull??(row['emails'] as List).first,'selected':true,'circleNames':names});
 }
 return result;
}
