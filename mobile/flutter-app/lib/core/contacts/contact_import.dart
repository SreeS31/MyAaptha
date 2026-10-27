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


List<Map<String,dynamic>> prepareContactReview(List<Map<String,dynamic>> input,List<String> existing){
  String key(String value)=>value.trim().replaceAll(RegExp(r'\s+'),' ').toLowerCase();
  final result=<Map<String,dynamic>>[];
  for(final row in input){
    final phones=(row['phones'] as List? ?? []).cast<String>().expand((p)=>p.split(RegExp(r' ::: |[;,]'))).map((p)=>p.trim().replaceFirst(RegExp(r'^tel:',caseSensitive:false),'').replaceAll(RegExp(r'[ ()\-.]'),'')).where((p)=>RegExp(r'^\+?[0-9]{7,15}$').hasMatch(p)).toSet().take(20).toList();
    if(phones.isEmpty)continue;
    final words=key('${row['displayName']}').split(RegExp(r'[^a-z0-9]+'));
    final matches=[...existing,'INCOIS','Inter','Padmashali'].where((name){final parts=key(name).split(RegExp(r'[^a-z0-9]+')).where((p)=>p.isNotEmpty).toList();return parts.isNotEmpty&&parts.every(words.contains);});
    final names=[...(row['groups'] as List? ?? []).cast<String>().where((g)=>!RegExp(r'^\*?\s*(my contacts|all contacts)$',caseSensitive:false).hasMatch(g)), '${row['organization'] ?? ''}',...matches].where((s)=>s.trim().isNotEmpty).map((s)=>existing.where((e)=>key(e)==key(s)).firstOrNull??s.trim()).toSet().take(20).toList();
    result.add({...row,'phones':phones,'emails':(row['emails'] as List? ?? []).cast<String>().map((e)=>e.trim()).where((e)=>RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(e)).toSet().take(20).toList(),'selected':true,'circleNames':names.isEmpty?['Imported contacts']:names});
  }
  return result;
}
