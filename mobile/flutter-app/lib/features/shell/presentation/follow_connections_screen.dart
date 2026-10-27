import 'package:flutter/material.dart';
import 'package:myaaptha_mobile/core/network/myaaptha_api.dart';

class FollowConnectionsScreen extends StatefulWidget {
  const FollowConnectionsScreen({super.key, required this.api});
  final MyAapthaApi api;
  @override
  State<FollowConnectionsScreen> createState() => _FollowConnectionsState();
}

class _FollowConnectionsState extends State<FollowConnectionsScreen> {
  String kind = 'following';
  int page = 0, generation = 0;
  bool loading = true, more = false;
  String? error;
  List<dynamic> people = [];
  @override
  void initState() {super.initState();load();}
  Future<void> load() async {
    final request = ++generation;
    setState(() {loading = true;error = null;});
    try {
      final data = await widget.api.followConnections(kind,page);
      if (!mounted || request != generation) return;
      setState(() {people = data['people'] as List;more = data['hasNext'] == true;});
    } catch(e) {if(mounted && request == generation) setState(() => error = e.toString());}
    finally {if(mounted && request == generation) setState(() => loading = false);}
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Following & followers')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(12),child: SegmentedButton<String>(
        segments: const [ButtonSegment(value:'following',label:Text('Following')),ButtonSegment(value:'followers',label:Text('Followers'))],
        selected: {kind},onSelectionChanged:(value){setState(() {kind=value.first;page=0;});load();})),
      const Padding(padding:EdgeInsets.symmetric(horizontal:16),child:Text('Role Model connections do not grant access to private diary entries.')),
      if(error != null) Padding(padding:const EdgeInsets.all(12),child:Text(error!)),
      Expanded(child:loading ? const Center(child:CircularProgressIndicator()) : people.isEmpty ? const Center(child:Text('No people in this list yet.')) : ListView.builder(
        itemCount:people.length,itemBuilder:(context,index){final person=people[index] as Map;final name=person['displayName'] as String? ?? 'Member';return ListTile(
          leading:CircleAvatar(child:Text(name.isEmpty?'?':name[0])),title:Text(name),
          subtitle:Text(kind=='following'?'You follow this Role Model':'Follows you'),
          trailing:kind=='following'?TextButton(onPressed:() async {try{await widget.api.unfollowRoleModel(person['userId'] as int);await load();}catch(e){if(mounted)setState(()=>error=e.toString());}},child:const Text('Unfollow')):null); })),
      Row(mainAxisAlignment:MainAxisAlignment.center,children:[TextButton(onPressed:loading||page==0?null:(){page--;load();},child:const Text('Previous')),Text('Page ${page+1}'),TextButton(onPressed:loading||!more?null:(){page++;load();},child:const Text('Next'))]),
    ]),
  );
}
